package ax4;

import ax4.Token.TokenKind;
import ax4.filters.RewriteForIn;
import ax4.ParseTree;
import ax4.TypedTree;
import ax4.Token.Trivia;
import ax4.TypedTreeTools.exprPos;
import ax4.TypedTreeTools.skipParens;
import ax4.TypedTreeTools.typeEq;
import ax4.Utils;
using StringTools;

enum DotPathLastKind {
	LastKeep;
	LastPackage;
	LastType;
}

enum DotPathFirstKind {
	FirstKeep;
	FirstPackage;
	FirstType;
}

@:nullSafety
class GenHaxe extends PrinterBase {

	static var REPLACE_CONTROL_CHAR: Map<String, Int> = [
		"\\u00A0" => 160, // non breaking space
		"\\u2028" => 8232, // line seperator
		"\\u2029" => 8233, // paragraph seperator
		"\\u3000" => 12288 // ideographic space
	];

	@:nullSafety(Off) var currentModule:TModule;

	final context:Context;

	public function new(context) {
		super();
		this.context = context;
		importError();
	}

	inline function throwError(pos:Int, msg:String):Dynamic {
		context.reportError(currentModule.path, pos, msg);
		throw msg; // TODO do it nicer
	}

	public function writeModule(m:TModule) {
		currentModule = m;
		printPackage(m.pack);
		for (d in m.privateDecls) {
			printDecl(d, true);
		}
		printTrivia(m.eof.leadTrivia);
		@:nullSafety(Off) currentModule = null;
	}

	inline function normalizePackagePart(part:String):String {
		return Utils.normalizePackagePart(part, context.config.packagePartRenames);
	}

	inline function normalizeTypeName(name:String):String {
		return Utils.normalizeTypeName(name);
	}

	function printDotPathNormalized(path:DotPath, lastKind:DotPathLastKind, ?firstKind:DotPathFirstKind) {
		var effectiveFirstKind = firstKind == null ? FirstPackage : firstKind;
		var lastIndex = path.rest.length;
		var index = 0;
		inline function normalizePart(text:String, isFirst:Bool, isLast:Bool):String {
			if (!isLast) {
				return if (isFirst) {
					switch effectiveFirstKind {
						case FirstPackage: normalizePackagePart(text);
						case FirstType: normalizeTypeName(text);
						case FirstKeep: text;
					}
				} else {
					normalizePackagePart(text);
				}
			}
			return switch lastKind {
				case LastPackage: normalizePackagePart(text);
				case LastType: normalizeTypeName(text);
				case LastKeep: text;
			}
		}
		var firstText = normalizePart(path.first.text, index == 0, index == lastIndex);
		printTextWithTrivia(firstText, path.first);
		for (item in path.rest) {
			printDot(item.sep);
			index++;
			var text = normalizePart(item.element.text, false, index == lastIndex);
			printTextWithTrivia(text, item.element);
		}
	}

	function printPackage(p:TPackageDecl) {
		if (p.syntax.name != null) {
			printTextWithTrivia("package", p.syntax.keyword);
			printDotPathNormalized(p.syntax.name, LastPackage);
			buf.add(";");
		} else {
			printTokenTrivia(p.syntax.keyword);
		}

		printTokenTrivia(p.syntax.openBrace);

		for (i in p.imports) {
			printImport(i);
		}

		for (n in p.namespaceUses) {
			printUseNamespace(n.n);
			printTokenTrivia(n.semicolon);
		}

		printDecl(p.decl, false);
		printTokenTrivia(p.syntax.closeBrace);
	}

	function printImport(i:TImport) {
		if (i.syntax.condCompBegin != null) printCondCompBegin(i.syntax.condCompBegin);

		var skip = switch i.kind {
			// skip namespaces and specific flash imports that are rewritten by compat helpers
			case TIDecl({kind: TDNamespace(_) | TDClassOrInterface({parentModule: {parentPack: {name: "flash.utils"}}, name: "Dictionary" | "Proxy"})}):
				var trivia = i.syntax.keyword.leadTrivia.concat(i.syntax.semicolon.trailTrivia);
				if (!TokenTools.containsOnlyWhitespaceOrNewline(trivia)) {
					printTrivia(trivia);
				}
				true;
			case _:
				false;
		}

		if (!skip) {
			printTextWithTrivia("import", i.syntax.keyword);

			var dotPath = i.syntax.path;

			function printPackagePath(p:TPackage) {
				printTrivia(dotPath.first.leadTrivia);
				var parts = p.name.split(".");
				for (part in parts) {
					if (part == "") continue;
					// lowercase package first letter for Haxe
					buf.add(normalizePackagePart(part));
					buf.add(".");
				}
			}

			function printDotPathTrailTrivia() {
				printTrivia(if (dotPath.rest.length == 0) dotPath.first.trailTrivia else dotPath.rest[dotPath.rest.length - 1].element.trailTrivia);
			}

			switch i.kind {
				case TIDecl(d):
					switch d.kind {
						case TDClassOrInterface(c):
							printPackagePath(c.parentModule.parentPack);
							buf.add(normalizeTypeName(c.name));
						case TDVar(v):
							printPackagePath(v.parentModule.parentPack);
							buf.add(v.name);
						case TDFunction(f):
							printPackagePath(f.parentModule.parentPack);
							buf.add(f.name);
						case TDNamespace(_):
							throw "assert";
					}
					printDotPathTrailTrivia();
				case TIAliased(d, as, name):
					// this is awkward: the decl is pointing to original flash decl in flash package,
					// but the syntax path is something we constructed to import from Haxe
					var lastKind = switch d.kind {
						case TDClassOrInterface(_): LastType;
						case _: LastKeep;
					}
					var firstKind = switch d.kind {
						case TDVar(_) | TDFunction(_): FirstType;
						case _: FirstPackage;
					}
					printDotPathNormalized(i.syntax.path, lastKind, firstKind);
					printTextWithTrivia("as", as);
					printTextWithTrivia(name.text, name);
				case TIAll(pack, _, asterisk):
					printPackagePath(pack);
					printTextWithTrivia("*", asterisk);
					printDotPathTrailTrivia();
			}


			printSemicolon(i.syntax.semicolon);
		}

		if (i.syntax.condCompEnd != null) printCompCondEnd(i.syntax.condCompEnd);
	}

	function printDecl(d:TDecl, isPrivate:Bool) {
		switch (d.kind) {
			case TDClassOrInterface(c = {kind: TClass(info)}): printClassDecl(c, info, isPrivate);
			case TDClassOrInterface(i = {kind: TInterface(info)}): printInterfaceDecl(i, info, isPrivate);
			case TDVar(v): printModuleVarDecl(v);
			case TDFunction(f): printFunctionDecl(f);
			case TDNamespace(n): printNamespace(n);
		}
	}

	function printNamespace(ns:NamespaceDecl) {
		printDeclModifiers(ns.modifiers);
		printTextWithTrivia("namespace", ns.keyword);
		printTextWithTrivia(ns.name.text, ns.name);
		printSemicolon(ns.semicolon);
	}

	function printFunctionDecl(f:TFunctionDecl) {
		printMetadata(f.metadata);
		printDeclModifiers(f.modifiers);
		printTextWithTrivia("function", f.syntax.keyword);
		printTextWithTrivia(f.name, f.syntax.name);
		printSignature(f.fun.sig, NoVoid);
		printExpr(f.fun.expr);
	}

	function printModuleVarDecl(v:TModuleVarDecl) {
		printMetadata(v.metadata);
		printDeclModifiers(v.modifiers);
		printVarField(v);
	}

	function printInterfaceDecl(i:TClassOrInterfaceDecl, info:TInterfaceDeclInfo, isPrivate:Bool) {
		printMetadata(i.metadata);
		printDeclModifiers(i.modifiers);
		printTextWithTrivia(if (isPrivate) "private interface" else "interface", i.syntax.keyword);
		printTextWithTrivia(normalizeTypeName(i.name), i.syntax.name);
		if (info.extend != null) {
			printTextWithTrivia("extends", info.extend.keyword);
			printDotPathNormalized(info.extend.interfaces[0].iface.syntax, LastType);
			for (i in 1...info.extend.interfaces.length) {
				var prevComma = info.extend.interfaces[i - 1].comma;
				if (prevComma != null) printTextWithTrivia(" extends ", prevComma); // don't lose comments around comma, if there are any
				else buf.add(" extends ");
				var i = info.extend.interfaces[i];
				printDotPathNormalized(i.iface.syntax, LastType);
			}
		}
		printOpenBrace(i.syntax.openBrace);

		for (m in i.members) {
			switch (m) {
				case TMField(field):
					switch field.kind {
						case TFFun(f):
							printMetadata(field.metadata);
							printTextWithTrivia("function", f.syntax.keyword);
							printTextWithTrivia(f.name, f.syntax.name);
							printSignature(f.fun.sig, Print);
							printSemicolon(f.semicolon.sure());

						case TFGetter(_) | TFSetter(_):
							printHaxeProperty(field);

						case TFVar(_):
							throw "assert";
					}
				case TMCondCompBegin(b): printCondCompBegin(b);
				case TMCondCompEnd(b): printCompCondEnd(b);
				case TMStaticInit(_) | TMUseNamespace(_):
					throw "assert";
			}
		}

		printCloseBrace(i.syntax.closeBrace);
	}

	function printClassDecl(c:TClassOrInterfaceDecl, info:TClassDeclInfo, isPrivate:Bool) {
		printMetadata(c.metadata);
		printDeclModifiers(c.modifiers);
		printTextWithTrivia(if (isPrivate) "private class" else  "class", c.syntax.keyword);
		printTextWithTrivia(normalizeTypeName(c.name), c.syntax.name);
		if (info.extend != null) {
			printTextWithTrivia("extends", info.extend.syntax.keyword);
			if (isArrayBaseClass(info.extend)) {
				printTrivia(ParseTree.getDotPathLeadingTrivia(info.extend.syntax.path));
				buf.add("ASArrayBase");
				printTrivia(ParseTree.getDotPathTrailingTrivia(info.extend.syntax.path));
			} else if (isByteArrayBaseClass(info.extend)) {
				printTrivia(ParseTree.getDotPathLeadingTrivia(info.extend.syntax.path));
				buf.add("ASByteArrayBase");
				printTrivia(ParseTree.getDotPathTrailingTrivia(info.extend.syntax.path));
			} else {
				printDotPathNormalized(info.extend.syntax.path, LastType);
			}
		}
		if (info.implement != null) {
			printTextWithTrivia("implements", info.implement.keyword);
			printDotPathNormalized(info.implement.interfaces[0].iface.syntax, LastType);
			for (i in 1...info.implement.interfaces.length) {
				var prevComma = info.implement.interfaces[i - 1].comma;
				if (prevComma != null) printTextWithTrivia(" implements ", prevComma); // don't lose comments around comma, if there are any
				else buf.add(" implements ");
				var i = info.implement.interfaces[i];
				printDotPathNormalized(i.iface.syntax, LastType);
			}
		}
		printOpenBrace(c.syntax.openBrace);

		var classIndent = triviaIndent(c.syntax.closeBrace.leadTrivia);
		var memberIndent = getClassMemberIndent(c, classIndent);
		var indentUnit = if (memberIndent.length > classIndent.length && memberIndent.startsWith(classIndent))
			memberIndent.substr(classIndent.length)
		else
			"\t";
		if (indentUnit == "") indentUnit = "\t";
		var innerIndent = memberIndent + indentUnit;
		var staticInitNameCounts = new Map<String, Int>();
		var pendingStaticInitGroup:Array<{expr:TExpr}> = [];
		var pendingStaticInitBase = "";
		var hasPendingStaticInit = false;

		function flushStaticInitGroup() {
			if (hasPendingStaticInit && pendingStaticInitGroup.length > 0) {
				var name = nextStaticInitName(pendingStaticInitBase, staticInitNameCounts);
				printStaticInitGroup(pendingStaticInitGroup, name, memberIndent, innerIndent);
				pendingStaticInitGroup = [];
				pendingStaticInitBase = "";
				hasPendingStaticInit = false;
			}
		}

		for (m in c.members) {
			switch (m) {
				case TMCondCompBegin(b):
					flushStaticInitGroup();
					printCondCompBegin(b);

				case TMCondCompEnd(b):
					flushStaticInitGroup();
					printCompCondEnd(b);

				case TMField(f):
					flushStaticInitGroup();
					printClassField(c.name, f);

				case TMUseNamespace(n, semicolon):
					flushStaticInitGroup();
					printUseNamespace(n);
					printTextWithTrivia("", semicolon);

				case TMStaticInit(i):
					var base = staticInitBaseName(i.expr);
					if (hasPendingStaticInit && pendingStaticInitBase == base) {
						pendingStaticInitGroup.push(i);
					} else {
						flushStaticInitGroup();
						pendingStaticInitGroup = [i];
						pendingStaticInitBase = base;
						hasPendingStaticInit = true;
					}
			}
		}
		flushStaticInitGroup();

		printCloseBrace(c.syntax.closeBrace);
	}

	static function isArrayBaseClass(extend:TClassExtend):Bool {
		var superClass = extend.superClass;
		if (superClass != null) {
			if (superClass.name == "Array") return true;
		}
		return ParseTree.dotPathToString(extend.syntax.path) == "Array";
	}

	static function isByteArrayBaseClass(extend:TClassExtend):Bool {
		var superClass = extend.superClass;
		if (superClass != null && superClass.name == "ByteArray") {
			var packName = superClass.parentModule.parentPack.name;
			if (packName == "" || packName == "flash.utils" || packName == "openfl.utils") {
				return true;
			}
		}
		var path = ParseTree.dotPathToString(extend.syntax.path);
		if (path == "ByteArray" || path == "flash.utils.ByteArray" || path == "openfl.utils.ByteArray") {
			return true;
		}
		var last = if (extend.syntax.path.rest.length == 0)
			extend.syntax.path.first.text
		else
			extend.syntax.path.rest[extend.syntax.path.rest.length - 1].element.text;
		return last == "ByteArray";
	}

	function printStaticInitGroup(group:Array<{expr:TExpr}>, name:String, memberIndent:String, innerIndent:String) {
		var leadTrivia = takeStaticInitLeadTrivia(group[0].expr);
		printTrivia(leadTrivia);
		buf.add("static final ");
		buf.add(name);
		buf.add(" = {\n");

		var prevEndedWithNewline = false;
		var isFirstExpr = true;
		var isFirstItem = true;

		function printStaticInitExpr(expr:TExpr, leadOverride:Null<Array<Trivia>>) {
			switch expr.kind {
				case TEBlock(block):
					var blockTrailTrivia = TypedTreeTools.removeTrailingTrivia(expr);
					printTrivia(block.syntax.openBrace.trailTrivia);
					block.syntax.openBrace.trailTrivia = [];
					var isFirstInBlock = true;
					for (e in block.exprs) {
						var exprLead = TypedTreeTools.removeLeadingTrivia(e.expr);
						var combinedLead = if (leadOverride != null && isFirstInBlock) leadOverride.concat(exprLead) else exprLead;
						var needsLeadingNewline = !isFirstExpr && !prevEndedWithNewline;
						printTrivia(normalizeStaticInitLead(combinedLead, needsLeadingNewline, innerIndent));
						printExpr(e.expr);
						var exprTrail = TypedTreeTools.removeTrailingTrivia(e.expr);
						printTrivia(exprTrail);
						if (e.semicolon != null) {
							var semicolonTrail = e.semicolon.trailTrivia;
							e.semicolon.trailTrivia = stripTrailingIndentAfterNewline(semicolonTrail);
							printSemicolon(e.semicolon);
							e.semicolon.trailTrivia = semicolonTrail;
							prevEndedWithNewline = triviaEndsWithNewline(semicolonTrail);
						} else if (needsSemicolon(e.expr)) {
							buf.add(";");
							prevEndedWithNewline = false;
						} else {
							prevEndedWithNewline = triviaEndsWithNewline(exprTrail);
						}
						isFirstExpr = false;
						isFirstInBlock = false;
					}
					if (block.exprs.length == 0 && leadOverride != null) {
						var needsLeadingNewline = !isFirstExpr && !prevEndedWithNewline;
						printTrivia(normalizeStaticInitLead(leadOverride, needsLeadingNewline, innerIndent));
						prevEndedWithNewline = triviaEndsWithNewline(leadOverride);
						isFirstExpr = false;
					}
					var closeLead = block.syntax.closeBrace.leadTrivia;
					printTrivia(closeLead);
					block.syntax.closeBrace.leadTrivia = [];
					printTrivia(blockTrailTrivia);
					if (!prevEndedWithNewline && (triviaEndsWithNewline(closeLead) || triviaEndsWithNewline(blockTrailTrivia))) {
						prevEndedWithNewline = true;
					}
				case _:
					var exprLead = TypedTreeTools.removeLeadingTrivia(expr);
					var combinedLead = if (leadOverride != null) leadOverride.concat(exprLead) else exprLead;
					var needsLeadingNewline = !isFirstExpr && !prevEndedWithNewline;
					printTrivia(normalizeStaticInitLead(combinedLead, needsLeadingNewline, innerIndent));
					printExpr(expr);
					var exprTrail = TypedTreeTools.removeTrailingTrivia(expr);
					printTrivia(exprTrail);
					if (needsSemicolon(expr)) {
						buf.add(";");
						prevEndedWithNewline = false;
					} else {
						prevEndedWithNewline = triviaEndsWithNewline(exprTrail);
					}
					isFirstExpr = false;
			}
		}

		for (i in group) {
			var leadOverride = if (isFirstItem) null else takeStaticInitLeadTrivia(i.expr);
			printStaticInitExpr(i.expr, leadOverride);
			isFirstItem = false;
		}

		if (!prevEndedWithNewline) {
			buf.add("\n");
		}
		buf.add(innerIndent);
		buf.add("null;\n");
		buf.add(memberIndent);
		buf.add("};\n");
	}

	function getClassMemberIndent(c:TClassOrInterfaceDecl, classIndent:String):String {
		for (m in c.members) {
			switch (m) {
				case TMField(f):
					return triviaIndent(TypedTreeTools.getFieldLeadingToken(f).leadTrivia);
				case TMUseNamespace(n, _):
					return triviaIndent(n.useKeyword.leadTrivia);
				case TMStaticInit(i):
					return triviaIndent(getStaticInitMemberLead(i.expr));
				case TMCondCompBegin(b):
					return triviaIndent(b.openBrace.leadTrivia);
				case TMCondCompEnd(_):
			}
		}
		return classIndent + "\t";
	}

	function getStaticInitMemberLead(expr:TExpr):Array<Trivia> {
		return switch expr.kind {
			case TEBlock(block):
				if (block.syntax.openBrace.pos >= 0) block.syntax.openBrace.leadTrivia
				else if (block.exprs.length > 0) TypedTreeTools.processLeadingToken(t -> t.leadTrivia, block.exprs[0].expr)
				else block.syntax.openBrace.leadTrivia;
			case _:
				TypedTreeTools.processLeadingToken(t -> t.leadTrivia, expr);
		}
	}

	function takeStaticInitLeadTrivia(expr:TExpr):Array<Trivia> {
		return switch expr.kind {
			case TEBlock(block):
				if (block.syntax.openBrace.pos >= 0) TypedTreeTools.removeLeadingTrivia(expr)
				else if (block.exprs.length > 0) TypedTreeTools.removeLeadingTrivia(block.exprs[0].expr)
				else TypedTreeTools.removeLeadingTrivia(expr);
			case _:
				TypedTreeTools.removeLeadingTrivia(expr);
		}
	}

	function staticInitBaseName(expr:TExpr):String {
		var base = "___init";
		var hint = staticInitNameHint(expr);
		if (hint != null && hint != "") {
			var sanitized = sanitizeStaticInitName(hint);
			if (sanitized != "") base = base + "_" + sanitized;
		}
		return base;
	}

	function nextStaticInitName(base:String, counts:Map<String, Int>):String {
		var count = counts.get(base);
		if (count == null) {
			counts.set(base, 1);
			return base;
		}
		var nextIndex = count + 1;
		counts.set(base, nextIndex);
		return base + "_" + nextIndex;
	}

	function staticInitNameHint(expr:TExpr):Null<String> {
		return switch expr.kind {
			case TEParens(_, inner, _):
				staticInitNameHint(inner);
			case TEBlock(block):
				if (block.exprs.length == 1) staticInitNameHint(block.exprs[0].expr) else null;
			case TEBinop(a, OpAssign(_) | OpAssignOp(_), _):
				staticInitNameFromLhs(a);
			case TEVars(_, vars):
				if (vars.length > 0) vars[0].v.name else null;
			case _:
				null;
		}
	}

	function staticInitNameFromLhs(expr:TExpr):Null<String> {
		return switch expr.kind {
			case TEParens(_, inner, _):
				staticInitNameFromLhs(inner);
			case TELocal(_, v):
				v.name;
			case TEField(_, fieldName, _):
				fieldName;
			case TEDeclRef(path, _):
				var parts = ParseTree.dotPathToArray(path);
				if (parts.length > 0) parts[parts.length - 1] else null;
			case TEArrayAccess(a):
				staticInitNameFromLhs(a.eobj);
			case TECall(eobj, _):
				staticInitNameFromLhs(eobj);
			case TEBuiltin(_, name):
				name;
			case TEHaxeRetype(e):
				staticInitNameFromLhs(e);
			case _:
				null;
		}
	}

	function sanitizeStaticInitName(name:String):String {
		var buf = new StringBuf();
		for (i in 0...name.length) {
			var code = name.charCodeAt(i);
			if (code == null) continue;
			var isAlpha = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
			var isDigit = code >= 48 && code <= 57;
			if (isAlpha || isDigit || code == 95) buf.addChar(code);
			else buf.addChar(95);
		}
		var result = buf.toString();
		if (result == "") return "";
		var first = result.charCodeAt(0);
		if (first != null && first >= 48 && first <= 57) return "_" + result;
		return result;
	}

	function triviaIndent(trivia:Array<Trivia>):String {
		var result = "";
		var hadOnlyWhitespace = true;
		for (item in trivia) {
			switch item.kind {
				case TrBlockComment | TrLineComment:
					result = "";
					hadOnlyWhitespace = false;
				case TrNewline:
					result = "";
					hadOnlyWhitespace = true;
				case TrWhitespace:
					result += item.text;
			}
		}
		return if (hadOnlyWhitespace) result else "";
	}

	function normalizeStaticInitLead(trivia:Array<Trivia>, needsNewline:Bool, innerIndent:String):Array<Trivia> {
		var i = 0;
		while (i < trivia.length && (trivia[i].kind == TrWhitespace || trivia[i].kind == TrNewline)) {
			i++;
		}
		var trimmed = trivia.slice(i);
		var prefix:Array<Trivia> = [];
		if (needsNewline) {
			prefix.push(new Trivia(TrNewline, "\n"));
		}
		if (innerIndent != "") {
			prefix.push(new Trivia(TrWhitespace, innerIndent));
		}
		return prefix.concat(trimmed);
	}

	function stripTrailingIndentAfterNewline(trivia:Array<Trivia>):Array<Trivia> {
		var result = trivia.copy();
		var i = result.length - 1;
		while (i >= 0 && result[i].kind == TrWhitespace) {
			result.pop();
			i--;
		}
		return result;
	}

	function triviaEndsWithNewline(trivia:Array<Trivia>):Bool {
		var i = trivia.length - 1;
		while (i >= 0) {
			switch trivia[i].kind {
				case TrWhitespace:
					i--;
				case TrNewline:
					return true;
				case _:
					return false;
			}
		}
		return false;
	}

	function printCondCompBegin(e:TCondCompBegin) {
		printTokenTrivia(e.v.syntax.ns);
		printTokenTrivia(e.v.syntax.sep);
		printTextWithTrivia("#if " + e.v.ns + "_" + e.v.name, e.v.syntax.name);
		printTokenTrivia(e.openBrace);
	}

	function printCompCondEnd(e:TCondCompEnd) {
		printTextWithTrivia("#end ", e.closeBrace);
	}

	function printDeclModifiers(modifiers:Array<DeclModifier>) {
		for (m in modifiers) {
			switch (m) {
				case DMPublic(t): printTokenTrivia(t);
				case DMInternal(t): printTextWithTrivia("/*internal*/", t);
				case DMFinal(t): printTextWithTrivia("final", t);
				case DMDynamic(t): printTextWithTrivia("/*dynamic*/", t);
			}
		}
	}

	function printHaxeProperty(f:TClassField) {
		switch f.kind {
			case TFGetter(a) | TFSetter(a) if (a.haxeProperty != null):
				var p = a.haxeProperty;
				printTrivia(p.syntax.leadTrivia);
				printMetadata(p.metadata);

				var addMeta =
					switch context.config {
						case {settings: {flashProperties: none}}:
							false;
						case {settings: {flashProperties: externInterface}}:
							p.isFlashProperty;
						case _:
							true;
					};

				if (addMeta) buf.add("@:flash.property ");
				buf.add("@:isVar ");
				if (p.isPublic) buf.add("public ");
				if (p.isStatic) buf.add("static ");
				buf.add("var ");
				buf.add(p.name);
				buf.add(if (p.get) "(get," else "(never,");
				buf.add(if (p.set) "set):" else "never):");
				printTType(p.type);
				buf.add(";\n");
			case _:
		}
	}

	function printClassField(className:String, f:TClassField) {
		printHaxeProperty(f);

		printMetadata(f.metadata);

		if (f.namespace != null) {
			printTextWithTrivia("/*namespace " + f.namespace.text + "*/", f.namespace);
		}

		for (m in f.modifiers) {
			switch (m) {
				case FMPublic(t):
					printTextWithTrivia("public", t);
				case FMPrivate(t) | FMProtected(t):
					// `private` is default in Haxe, so we can skip the modifier
					t.trimTrailingWhitespace();
					printTokenTrivia(t);
				// case FMPrivate(t): printTextWithTrivia("private", t);
				// case FMProtected(t): printTextWithTrivia("/*protected*/private", t);
				case FMInternal(t): throwError(t.pos, "Unprocessed internal modifier");
				case FMOverride(t): printTextWithTrivia("override", t);
				case FMStatic(t): printTextWithTrivia("static", t);
				case FMFinal(t): printTextWithTrivia("final", t);
			}
		}

		switch (f.kind) {
			case TFVar(v):
				printVarField(v);
			case TFFun(f):
				var kwd = if (f.isInline) "inline function" else "function";
				printTextWithTrivia(kwd, f.syntax.keyword);
				var isCtor = f.name == className;
				printTextWithTrivia(if (isCtor) "new" else f.name, f.syntax.name);
				printSignature(f.fun.sig, if (isCtor) Skip else NoVoid);

				var trailTrivia = TypedTreeTools.removeTrailingTrivia(f.fun.expr);
				printExpr(f.fun.expr);
				if (needsSemicolon(f.fun.expr)) buf.add(";");
				printTrivia(trailTrivia);

			case TFGetter(f):
				var kwd = "";
				if (f.haxeProperty != null && f.haxeProperty.isPublic) kwd += "public ";
				if (f.isInline) kwd += "inline ";
				kwd += "function";
				printTextWithTrivia(kwd, f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("get_" + f.name, f.syntax.name);
				printSignature(f.fun.sig, NoVoid);
				printExpr(f.fun.expr);
			case TFSetter(f):
				var kwd = "";
				if (f.haxeProperty != null && f.haxeProperty.isPublic) kwd += "public ";
				if (f.isInline) kwd += "inline ";
				kwd += "function";
				printTextWithTrivia(kwd, f.syntax.functionKeyword);
				printTokenTrivia(f.syntax.accessorKeyword);
				printTextWithTrivia("set_" + f.name, f.syntax.name);
				printSignature(f.fun.sig, NoVoid);
				printExpr(f.fun.expr);
		}
	}

	function printVarField(v:TVarField) {
		if (v.isInline) buf.add("inline ");
		printVarKind(v.kind, v.init == null /* `final` must be immediately initialized */);
		printTextWithTrivia(v.name, v.syntax.name);

		var skipTypeHint = context.config.keepTypes != true && v.isInline && v.init != null && canSkipTypeHint(v.type, v.init.expr);
		if (!skipTypeHint) {
			// TODO: don't lose the typehint's trivia
			printTypeHint({type: v.type, syntax: v.syntax.type});
		}

		if (v.init != null) printVarInit(v.init, skipTypeHint, v.type);
		printSemicolon(v.semicolon);
	}

	function printMetadata(metas:Array<TMetadata>) {
		for (m in metas) {
			switch m {
				case MetaFlash(m):
					printTokenTrivia(m.openBracket);
					buf.add("@:meta(");
					printTextWithTrivia(m.name.text, m.name);
					if (m.args == null) {
						buf.add("()");
					} else {
						var p = new Printer();
						p.printCallArgs(m.args);
						buf.add(p.toString());
					}
					buf.add(")");
					printTokenTrivia(m.closeBracket);
				case MetaHaxe(token, args):
					printTextWithTrivia(token.text, token);
					if (args != null) {
						new Printer(buf).printCallArgs(args);
					}
			}
		}
	}

	function printSignature(sig:TFunctionSignature, returnTypeRule:ReturnTypeRule) {
		printOpenParen(sig.syntax.openParen);
		for (arg in sig.args) {
			switch (arg.kind) {
				case TArgNormal(hint, init):
					printTextWithTrivia(arg.name, arg.syntax.name);
					printTypeHint({type: arg.type, syntax: hint});
					if (init != null) printVarInit(init, false, arg.type);

				case TArgRest(dots, _, hint):
					#if (haxe_ver >= 4.20)
					printTextWithTrivia('...' + arg.name, arg.syntax.name);
					printTypeHint({type: restElementType(arg.type), syntax: hint});
					#else
					throwError(dots.pos, "Unprocessed rest arguments");
					#end
			}
			if (arg.comma != null) printComma(arg.comma);
		}
		printCloseParen(sig.syntax.closeParen);
		switch returnTypeRule {
			case Skip:
			case NoVoid if (sig.ret.type == TTVoid):
				if (sig.ret.syntax != null) {
					printTrivia(ParseTree.getSyntaxTypeTrailingTrivia(sig.ret.syntax.type));
				}
			case _:
				printTypeHint(sig.ret);
		}
	}

	static function restElementType(t:TType):TType {
		return switch t {
			case TTArray(elem): elem;
			case _: t;
		}
	}

	function printTType(t:TType) {
		switch t {
			case TTVoid: buf.add("Void");
			case TTAny: buf.add("ASAny");
			case TTBoolean: buf.add("Bool");
			case TTNumber: buf.add("Float");
			case TTInt: buf.add("Int");
			case TTUint: buf.add("UInt");
			case TTString: buf.add("String");
			case TTArray(t): buf.add("Array<"); printTType(t); buf.add(">");
			case TTFunction: buf.add("ASFunction");
			case TTClass: buf.add("Dynamic"); // workaround temporaire, à remettre en Class<Dynamic>
			case TTObject(TTAny): buf.add("ASObject");
			case TTObject(t): buf.add("haxe.DynamicAccess<"); printTType(t); buf.add(">");
			case TTXML: buf.add("compat.XML");
			case TTXMLList: buf.add("compat.XMLList");
			case TTRegExp: buf.add("compat.RegExp");
			case TTVector(t):
				importVector();
				buf.add("Vector<"); printTType(t); buf.add(">");
			case TTDictionary(k, v): buf.add("ASDictionary<"); printTType(k); buf.add(","); printTType(v); buf.add(">");
			case TTBuiltin: buf.add("TODO");
			case TTFun(args, ret, rest):
				// TODO: handle nested function types
				if (args.length == 1) {
					printTType(args[0]);
				} else {
					buf.add("(");
					for (i in 0...args.length) {
						printTType(args[i]);
						if (i < args.length - 1)
							buf.add(", ");
					}
					buf.add(")");
				}
				buf.add("->");
				printTType(ret);

			case TTInst(cls):
				buf.add(getClassLocalPath(cls));

			case TTStatic(cls):
				buf.add("Class<" + getClassLocalPath(cls) + ">");
		}
	}

	inline function getClassLocalPath(cls:TClassOrInterfaceDecl):String {
		if (isModulePrivateClass(cls)) {
			return normalizeTypeName(cls.name);
		}
		return if (currentModule.isImported(cls)) normalizeTypeName(cls.name) else makeFQN(cls);
	}

	function isModulePrivateClass(cls:TClassOrInterfaceDecl):Bool {
		if (cls.parentModule != currentModule) return false;
		switch currentModule.pack.decl.kind {
			case TDClassOrInterface(c) if (c == cls):
				return false;
			case _:
		}
		for (decl in currentModule.privateDecls) {
			switch decl.kind {
				case TDClassOrInterface(c) if (c == cls):
					return true;
				case _:
			}
		}
		return false;
	}

	function makeFQN(cls:TClassOrInterfaceDecl) {
		var packName = cls.parentModule == null ? "" : Utils.normalizePackageName(cls.parentModule.parentPack.name, context.config.packagePartRenames);
		var typeName = Utils.normalizeTypeName(cls.name);
		return if (packName == "") typeName else packName + "." + typeName;
	}

	function printTypeRef(t:TTypeRef, printTypeParams:Bool, pos:Int) {
		printTrivia(ParseTree.getSyntaxTypeLeadingTrivia(t.syntax));

		switch t.type {
			case TTVoid | TTAny | TTBoolean | TTNumber | TTInt | TTUint | TTString | TTFunction | TTClass | TTBuiltin | TTFun(_) | TTStatic(_):
				throwError(pos, "Unsupported type ref: " + t.type); // can't construct those with `new`

			case TTXML | TTXMLList | TTRegExp | TTInst(_) | TTObject(TTAny):
				printTType(t.type);

			case TTArray(t):
				buf.add("Array");
				if (printTypeParams) {
					buf.add("<");
					printTType(t);
					buf.add(">");
				}

			case TTVector(t):
				importVector();
				buf.add("Vector");
				if (printTypeParams) {
					buf.add("<");
					printTType(t);
					buf.add(">");
				}

			case TTDictionary(k, v):
				buf.add("ASDictionary");
				if (printTypeParams) {
					buf.add("<");
					printTType(k);
					buf.add(",");
					printTType(v);
					buf.add(">");
				}

			case TTObject(t):
				buf.add("haxe.DynamicAccess");
				if (printTypeParams) {
					buf.add("<");
					printTType(t);
					buf.add(">");
				}
		}

		printTrivia(ParseTree.getSyntaxTypeTrailingTrivia(t.syntax));
	}

	function printTypeHint(hint:TTypeHint) {
		if (hint.syntax != null) {
			printColon(hint.syntax.colon);
			printTrivia(ParseTree.getSyntaxTypeLeadingTrivia(hint.syntax.type));
		} else {
			buf.add(":");
		}
		if (hint.syntax != null && hint.type == TTAny && isDynamicSyntax(hint.syntax.type)) {
			buf.add("Dynamic");
		} else {
			printTType(hint.type);
		}
		if (hint.syntax != null) {
			printTrivia(ParseTree.getSyntaxTypeTrailingTrivia(hint.syntax.type));
		}
	}

	static function isDynamicSyntax(t:SyntaxType):Bool {
		return switch t {
			case TPath(path): ParseTree.dotPathToString(path) == "Dynamic";
			case _: false;
		}
	}

	function printExpr(e:TExpr) {
		var needsCast =
			switch [e.type, e.expectedType] {
				case [TTFunction, TTFun(_)]: true; // Function from AS3 code unified with proper function type

				case [TTClass, TTStatic(_)]: true; // untyped Class unified with Class<ConcreteOne>

				case [TTFun([argType], _, _), TTFun([TTAny], _)] if (argType != TTAny): true; // add/remove event listener
				case [TTFun([], _), TTFun([_], _)]: true; // allow zero-arg handlers where one-arg is expected

				case [TTArray(TTAny), TTArray(TTAny)]: false; // untyped arrays
				case [TTArray(elemType), TTArray(TTAny)]: true; // typed array to untyped array
				case [TTArray(TTAny), TTArray(elemType)]: !e.kind.match(TEArrayDecl(_)); // untyped array to typed array (array decls are fine tho)

				case [TTDictionary(TTAny, TTAny), TTDictionary(TTAny, TTAny)]: false; // untyped dicts
				case [TTDictionary(k, v), TTDictionary(TTAny, TTAny)]: true; // typed dicts into untyped dict
				case [TTDictionary(TTAny, TTAny), TTDictionary(k, v)]: true; // untyped dicts into typed dict

				case _: false;
			};

		var trailTrivia:Null<Array<Trivia>> = null;
		if (needsCast) {
			printTrivia(TypedTreeTools.removeLeadingTrivia(e));
			trailTrivia = TypedTreeTools.removeTrailingTrivia(e);
			buf.add("(cast ");
		}

		switch e.kind {
			case TEParens(openParen, e, closeParen): printOpenParen(openParen); printExpr(e); printCloseParen(closeParen);
			case TECast(c): printCast(c);
			case TELocalFunction(f): printLocalFunction(f);
			case TELiteral(l): printLiteral(l);
			case TELocal(syntax, v): printTextWithTrivia(syntax.text, syntax);
			case TEField(object, fieldName, fieldToken): printFieldAccess(object, fieldName, fieldToken);
			case TEBuiltin(syntax, name): printBuiltin(syntax, name);
			case TEDeclRef(_, {kind: TDClassOrInterface({parentModule: {parentPack: {name: "flash.utils"}}, name: "Dictionary"})}):
				// TODO: this is hacky as hell, ugh
				printTrivia(TypedTreeTools.removeLeadingTrivia(e));
				buf.add("ASDictionary.type");
				printTrivia(TypedTreeTools.removeTrailingTrivia(e));

			case TEDeclRef(dotPath, c):
				var lastKind = switch c.kind {
					case TDClassOrInterface(_): LastType;
					case _: LastKeep;
				};
				printDotPathNormalized(dotPath, lastKind);
			case TECall(eobj, args): printExpr(eobj); printCallArgs(args);
			case TEArrayDecl(d): printArrayDecl(d);
			case TEVectorDecl(v): throw "assert";
			case TEReturn(keyword, e): printTextWithTrivia("return", keyword); if (e != null) printExpr(e);
			case TETypeof(keyword, e):
				var keywordTrail = keyword.removeTrailingTrivia();
				if (TokenTools.containsOnlyWhitespace(keywordTrail)) keywordTrail = [];
				var exprLead = TypedTreeTools.removeLeadingTrivia(e);
				if (TokenTools.containsOnlyWhitespace(exprLead)) exprLead = [];
				var exprTrail = TypedTreeTools.removeTrailingTrivia(e);
				printTextWithTrivia("ASCompat.typeof", keyword);
				buf.add("(");
				printTrivia(keywordTrail);
				printTrivia(exprLead);
				printExpr(e);
				buf.add(")");
				printTrivia(exprTrail);
			case TEThrow(keyword, e): printTextWithTrivia("throw", keyword); printExpr(e);
			case TEDelete(keyword, e): throw "assert";
			case TEBreak(keyword): printTextWithTrivia("break", keyword);
			case TEContinue(keyword): printTextWithTrivia("continue", keyword);
			case TEVars(kind, vars): printVars(kind, vars);
			case TEObjectDecl(o): printObjectDecl(o);
			case TEArrayAccess(a): printArrayAccess(a);
			case TEBlock(block): printBlock(block);
			case TETry(t): printTry(t);
			case TEVector(syntax, type):
				printTextWithTrivia("ASCompat.vectorClass((_:", syntax.name);
				printTokenTrivia(syntax.dot);
				printTokenTrivia(syntax.t.lt);
				printTrivia(ParseTree.getSyntaxTypeLeadingTrivia(syntax.t.type));
				printTType(type);
				printTrivia(ParseTree.getSyntaxTypeTrailingTrivia(syntax.t.type));
				printTextWithTrivia("))", syntax.t.gt);

			case TETernary(t): printTernary(t);
			case TEIf(i): printIf(i);
			case TEWhile(w): printWhile(w);
			case TEDoWhile(w): printDoWhile(w);
			case TEHaxeFor(f): printFor(f);
			case TEFor(_) | TEForIn(_) | TEForEach(_): throwError(exprPos(e), "unprocessed `for` expression");
			case TEBinop(a, OpComma(t), b): printCommaOperator(a, t, b);
			case TEBinop(a, op, b): printBinop(a, op, b);
			case TEPreUnop(op, e): printPreUnop(op, e);
			case TEPostUnop(e, op): printPostUnop(e, op);
			case TESwitch(s): printSwitch(s);
			case TENew(keyword, obj, args): printNew(keyword, obj, args, true);
			case TECondCompValue(v): printCondCompVar(v);
			case TECondCompBlock(v, expr): printCondCompBlock(v, expr);
			case TEAs(_): throwError(exprPos(e), "unprocessed `as` expression");
			case TEXmlChild(_) | TEXmlAttr(_) | TEXmlAttrExpr(_) | TEXmlDescend(_): throwError(exprPos(e), "unprocessed E4X");
			case TEUseNamespace(ns): printUseNamespace(ns);
			case TEHaxeIntIter(start, end):
				printExpr(start);
				buf.add("...");
				printExpr(end);
			case TEHaxeRetype(einner):
				printTrivia(TypedTreeTools.removeLeadingTrivia(einner));
				buf.add("(");
				var trail = TypedTreeTools.removeTrailingTrivia(einner);
				printExpr(einner);
				buf.add(" : ");
				printTType(e.type);
				buf.add(")");
				printTrivia(trail);
		}

		if (needsCast) {
			buf.add(")");
			if (trailTrivia != null) printTrivia(trailTrivia);
		}
	}

	function printBuiltin(token:Token, name:String) {
		// TODO: this is hacky (builtins in general are hacky...)
		name = switch name {
			case
				"Std.isOfType" | "cast" | "Std.int" | "Std.string" | "String"
				| "flash.Lib.getTimer" | "flash.Lib.getURL"
				| "Reflect.deleteField" | "Type.createInstance"| "Type.resolveClass" | "Type.getClassName" | "Type.getClass"
				| "haxe.Json" | "Reflect.compare" | "Reflect.isFunction" | "Math.POSITIVE_INFINITY" | "Math.NEGATIVE_INFINITY"
				| "StringTools.replace" | "StringTools.hex" | "Reflect.callMethod" | "Reflect.makeVarArgs" | "ASDictionary.asDictionary" | "_":
					name;
			case "Number": "Float";
			case "int": "Int";
			case "uint": "UInt";
			case "Boolean": "Bool";
			case "Object": "ASObject.typeReference()";
			case "Function": "ASFunction";
			case "XML": "compat.XML.typeReference()";
			case "XMLList": "compat.XMLList.typeReference()";
			case "Class": "Class";
			case "Vector":
				importVector();
				"Vector";
			case "Array": "Array";
			case "RegExp": "compat.RegExp";
			case "parseInt": "ASCompat.parseInt";
			case "parseFloat": "Std.parseFloat";
			case "NaN": "Math.NaN";
			case "isNaN": "Math.isNaN";
			case "isFinite": "Math.isFinite";
			case "escape": "ASCompat.escape";
			case "unescape": "ASCompat.unescape";
			case "arguments": "/*TODO*/arguments";
			case "trace": "trace";
			case "untyped __global__": "untyped __global__";
			case (_.startsWith("Vector.") => true):
				importVector();
				name;
			case (_.startsWith("ASCompat.") => true)
			   | (_.startsWith("ASCompatMacro.") => true)
			   | (_ == RewriteForIn.checkNullIterateeBuiltin => true)
			   : name;
			case _:
				throwError(token.pos, "unknown builtin: " + name);
		}
		printTextWithTrivia(name, token);
	}

	function printCast(c:TCast) {
		printTrivia(ParseTree.getDotPathLeadingTrivia(c.syntax.path));
		buf.add("cast");
		printOpenParen(c.syntax.openParen);
		printExpr(c.expr);
		buf.add(", ");
		printTType(c.type);
		printTrivia(ParseTree.getDotPathTrailingTrivia(c.syntax.path));
		printCloseParen(c.syntax.closeParen);
	}

	function printLocalFunction(f:TLocalFunction) {
		printTextWithTrivia("function", f.syntax.keyword);
		if (f.name != null) printTextWithTrivia(f.name.name, f.name.syntax);
		printSignature(f.fun.sig, NoVoid);
		printExpr(f.fun.expr);
	}

	function printSwitch(s:TSwitch) {
		printTextWithTrivia("switch", s.syntax.keyword);
		printOpenParen(s.syntax.openParen);
		printExpr(s.subj);
		printCloseParen(s.syntax.closeParen);
		printOpenBrace(s.syntax.openBrace);
		var hasNonConstantPattern = false;
		for (c in s.cases) {
			printTextWithTrivia("case", c.syntax.keyword);
			var first = true;
			for (e in c.values) {
				printTrivia(TypedTreeTools.removeLeadingTrivia(e));
				if (first) {
					first = false;
				} else {
					buf.add("   | ");
				}
				if (isConstantCaseExpr(e)) {
					printExpr(e);
				} else {
					var trailTrivia = TypedTreeTools.removeTrailingTrivia(e);
					var needsIntCast = s.subj.type == TTInt && e.type == TTUint;
					var needsUIntCast = s.subj.type == TTUint && e.type == TTInt;
					buf.add("(_ == ");
					if (needsIntCast) {
						buf.add("ASCompat.toInt(");
						printExpr(e);
						buf.add(")");
					} else if (needsUIntCast) {
						buf.add("(");
						printExpr(e);
						buf.add(" : UInt)");
					} else {
						printExpr(e);
					}
					buf.add(" => true)");
					printTrivia(trailTrivia);
					hasNonConstantPattern = true;
				}
			}
			printColon(c.syntax.colon);
			for (e in c.body) {
				printBlockExpr(e);
			}
		}
		if (s.def != null) {
			printTextWithTrivia("default", s.def.syntax.keyword);
			printColon(s.def.syntax.colon);
			for (e in s.def.body) {
				printBlockExpr(e);
			}
		} else if (hasNonConstantPattern) {
			// we gotta generate an empty `default` branch if we generated extractors before
			buf.add("\ndefault:\n");
		}
		printCloseBrace(s.syntax.closeBrace);
	}

	function isConstantCaseExpr(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, e, _):
				// recurse into parenthesis
				isConstantCaseExpr(e);

			case TEField(obj, fieldName, _):
				switch obj.type {
					case TTStatic(cls):
						// known static const fields are fine, others are not
						var f = cls.findFieldInHierarchy(fieldName, true);
						(f != null) && f.field.kind.match(TFVar({kind: VConst(_)}));
					case _:
						false;
				}

			// this should not really happen, I _think_, but if it ever will, we'll see
			case TEBuiltin(syntax, name):
				throwError(syntax.pos, "Builtin " + name + " used as a switch case value");

			// reference to a class/interface should be fine
			case TEDeclRef(_):
				true;

			// basic literals are fine
			case TELiteral(TLBool(_) | TLNull(_) | TLUndefined(_) | TLInt(_) | TLNumber(_) | TLString(_)):
				true;

			// other literals, local vars and basically anything else is NOT a suitable pattern
			case TELiteral(TLThis(_) | TLSuper(_) | TLRegExp(_))
			   | TELocal(_)

			   // no way these can even appear here so we could as well throw an assertion failure here
			   | TEReturn(_) | TETypeof(_) | TEThrow(_) | TEDelete(_) | TEBreak(_) | TEContinue(_)
			   | TEWhile(_) | TEDoWhile(_) | TEFor(_) | TEForIn(_) | TEForEach(_) | TEHaxeFor(_)
			   | TELocalFunction(_) | TEVars(_) | TEBlock(_) | TESwitch(_) | TECondCompValue(_) | TECondCompBlock(_) | TETry(_) | TEUseNamespace(_)

			   // these might appear
			   | TECall(_) | TECast(_) | TEArrayDecl(_) | TEVectorDecl(_) | TEObjectDecl(_)
			   | TEArrayAccess(_) | TEVector(_) | TETernary(_) | TEIf(_)
			   | TEBinop(_) | TEPreUnop(_) | TEPostUnop(_) | TEAs(_) | TENew(_)
			   | TEXmlChild(_) | TEXmlAttr(_) | TEXmlAttrExpr(_) | TEXmlDescend(_)
			   | TEHaxeRetype(_) | TEHaxeIntIter(_)
			   : false;
		}
	}

	function printCondCompBlock(v:TCondCompVar, expr:TExpr) {
		switch expr.kind {
			case TEBlock(block):
				printTokenTrivia(v.syntax.ns);
				printTokenTrivia(v.syntax.sep);
				printTextWithTrivia("#if " + v.ns + "_" + v.name, v.syntax.name);
				printOpenBrace(block.syntax.openBrace);
				for (e in block.exprs) printBlockExpr(e);
				printTextWithTrivia("} #end", block.syntax.closeBrace);
			case _:
				throw "assert";
		}
	}

	function printCondCompVar(v:TCondCompVar) {
		printTokenTrivia(v.syntax.ns);
		printTokenTrivia(v.syntax.sep);
		buf.add(v.ns + "_" + v.name);
		printTokenTrivia(v.syntax.name);
	}

	function printUseNamespace(ns:UseNamespace) {
		printTextWithTrivia("/*use*/", ns.useKeyword);
		printTextWithTrivia("/*namespace*/", ns.namespaceKeyword);
		printTextWithTrivia("/*" + ns.name.text + "*/", ns.name);
	}

	function printTry(t:TTry) {
		printTextWithTrivia("try", t.keyword);
		printExpr(t.expr);
		for (c in t.catches) {
			printTextWithTrivia("catch", c.syntax.keyword);
			printOpenParen(c.syntax.openParen);
			printTextWithTrivia(c.v.name, c.syntax.name);
			printTypeHint({type: c.v.type, syntax: c.syntax.type});
			printCloseParen(c.syntax.closeParen);
			printExpr(c.expr);
		}
	}

	function printWhile(w:TWhile) {
		printTextWithTrivia("while", w.syntax.keyword);
		printOpenParen(w.syntax.openParen);
		printExpr(w.cond);
		printCloseParen(w.syntax.closeParen);
		printExpr(w.body);
	}

	function printDoWhile(w:TDoWhile) {
		printTextWithTrivia("do", w.syntax.doKeyword);
		printExpr(w.body);
		printTextWithTrivia("while", w.syntax.whileKeyword);
		printOpenParen(w.syntax.openParen);
		printExpr(w.cond);
		printCloseParen(w.syntax.closeParen);
	}

	function printFor(f:THaxeFor) {
		printTextWithTrivia("for", f.syntax.forKeyword);
		printOpenParen(f.syntax.openParen);
		printTextWithTrivia(f.vit.name, f.syntax.itName);
		printTextWithTrivia("in", f.syntax.inKeyword);
		printExpr(f.iter);
		printCloseParen(f.syntax.closeParen);
		printExpr(f.body);
	}

	function printNew(keyword:Token, newObject:TNewObject, args:Null<TCallArgs>, includeTypeParams:Bool) {
		printTextWithTrivia("new", keyword);
		switch newObject {
			case TNType(t): printTypeRef(t, includeTypeParams, keyword.pos);
			case TNExpr(e): throwError(exprPos(e), "unprocessed expr for `new`");
		}
		if (args != null) printCallArgs(args) else buf.add("()");
	}

	function printArrayDecl(d:TArrayDecl) {
		printOpenBracket(d.syntax.openBracket);
		for (e in d.elements) {
			printExpr(e.expr);
			if (e.comma != null) printComma(e.comma);
		}
		printCloseBracket(d.syntax.closeBracket);
	}

	function printCallArgs(args:TCallArgs) {
		printOpenParen(args.openParen);
		for (a in args.args) {
			printExpr(a.expr);
			if (a.comma != null) printComma(a.comma);
		}
		printCloseParen(args.closeParen);
	}

	function printTernary(t:TTernary) {
		printExpr(t.econd);
		printTextWithTrivia("?", t.syntax.question);
		printExpr(t.ethen);
		printColon(t.syntax.colon);
		printExpr(t.eelse);
	}

	function printIf(i:TIf) {
		printTextWithTrivia("if", i.syntax.keyword);
		printOpenParen(i.syntax.openParen);
		printExpr(i.econd);
		printCloseParen(i.syntax.closeParen);
		printExpr(i.ethen);
		if (i.eelse != null) {
			if (i.eelse.semiliconBefore) buf.add(";\n");
			printTextWithTrivia("else", i.eelse.keyword);
			printExpr(i.eelse.expr);
		}
	}

	function printPreUnop(op:PreUnop, e:TExpr) {
		switch (op) {
			case PreNot(t): printTextWithTrivia("!", t);
			case PreNeg(t): printTextWithTrivia("-", t);
			case PreIncr(t): printTextWithTrivia("++", t);
			case PreDecr(t): printTextWithTrivia("--", t);
			case PreBitNeg(t):
				var lead = TypedTreeTools.removeLeadingTrivia(e);
				var combined = t.trailTrivia.concat(lead);
				var firstNonWsIndex = -1;
				for (i in 0...combined.length) {
					switch combined[i].kind {
						case TrWhitespace | TrNewline:
						case _:
							firstNonWsIndex = i;
							break;
					}
					if (firstNonWsIndex != -1) break;
				}
				var needsGuard = firstNonWsIndex == 0 && (combined[0].kind == TrBlockComment || combined[0].kind == TrLineComment);
				printTrivia(t.leadTrivia);
				buf.add("~");
				if (needsGuard) {
					buf.add(" ");
				}
				printTrivia(t.trailTrivia);
				printTrivia(lead);
				printExpr(e);
				return;
		}
		printExpr(e);
	}

	function printPostUnop(e:TExpr, op:PostUnop) {
		printExpr(e);
		switch (op) {
			case PostIncr(t): printTextWithTrivia("++", t);
			case PostDecr(t): printTextWithTrivia("--", t);
		}
	}

	function printCommaOperator(a:TExpr, comma:Token, b:TExpr) {
		// TODO: flatten nested commas (maybe this should be a filter...)
		printTrivia(TypedTreeTools.removeLeadingTrivia(a));
		buf.add("{");
		printExpr(a);
		printSemicolon(comma);
		printExpr(b);
		buf.add(";}");
		printTrivia(TypedTreeTools.removeTrailingTrivia(b));
	}

	function printBinop(a:TExpr, op:Binop, b:TExpr) {
		printExpr(a);
		switch (op) {
			case OpAdd(t): printTextWithTrivia("+", t);
			case OpSub(t): printTextWithTrivia("-", t);
			case OpDiv(t): printTextWithTrivia("/", t);
			case OpMul(t): printTextWithTrivia("*", t);
			case OpMod(t): printTextWithTrivia("%", t);
			case OpAssign(t): printTextWithTrivia("=", t);
			case OpAssignOp(AOpAdd(t)): printTextWithTrivia("+=", t);
			case OpAssignOp(AOpSub(t)): printTextWithTrivia("-=", t);
			case OpAssignOp(AOpMul(t)): printTextWithTrivia("*=", t);
			case OpAssignOp(AOpDiv(t)): printTextWithTrivia("/=", t);
			case OpAssignOp(AOpMod(t)): printTextWithTrivia("%=", t);
			case OpAssignOp(AOpAnd(t)): printTextWithTrivia("&&=", t);
			case OpAssignOp(AOpOr(t)): printTextWithTrivia("||=", t);
			case OpAssignOp(AOpBitAnd(t)): printTextWithTrivia("&=", t);
			case OpAssignOp(AOpBitOr(t)): printTextWithTrivia("|=", t);
			case OpAssignOp(AOpBitXor(t)): printTextWithTrivia("^=", t);
			case OpAssignOp(AOpShl(t)): printTextWithTrivia("<<=", t);
			case OpAssignOp(AOpShr(t)): printTextWithTrivia(">>=", t);
			case OpAssignOp(AOpUshr(t)): printTextWithTrivia(">>>=", t);
			case OpEquals(t): printTextWithTrivia("==", t);
			case OpNotEquals(t): printTextWithTrivia("!=", t);
			case OpStrictEquals(t): printTextWithTrivia("==", t);
			case OpNotStrictEquals(t): printTextWithTrivia("!=", t);
			case OpGt(t): printTextWithTrivia(">", t);
			case OpGte(t): printTextWithTrivia(">=", t);
			case OpLt(t): printTextWithTrivia("<", t);
			case OpLte(t): printTextWithTrivia("<=", t);
			case OpIn(t): throwError(t.pos, "unprocessed `in` operator");
			case OpAnd(t): printTextWithTrivia("&&", t);
			case OpOr(t): printTextWithTrivia("||", t);
			case OpShl(t): printTextWithTrivia("<<", t);
			case OpShr(t): printTextWithTrivia(">>", t);
			case OpUshr(t): printTextWithTrivia(">>>", t);
			case OpBitAnd(t): printTextWithTrivia("&", t);
			case OpBitOr(t): printTextWithTrivia("|", t);
			case OpBitXor(t): printTextWithTrivia("^", t);
			case OpComma(t): printTextWithTrivia(",", t);
			case OpIs(t): throwError(t.pos, "unprocessed `is` operator");
		}
		printExpr(b);
	}

	function printArrayAccess(a:TArrayAccess) {
		printExpr(a.eobj);
		printOpenBracket(a.syntax.openBracket);
		printExpr(a.eindex);
		printCloseBracket(a.syntax.closeBracket);
	}

	function printVarKind(kind:VarDeclKind, forceVar:Bool) {
		switch (kind) {
			case VVar(t): printTextWithTrivia("var", t);
			case VConst(t): printTextWithTrivia(if (forceVar) "var" else "final", t);
		}
	}

	function printVars(kind:VarDeclKind, vars:Array<TVarDecl>) {
		printVarKind(kind, false);
		for (v in vars) {
			printTextWithTrivia(v.v.name, v.syntax.name);

			// TODO: don't lose the typehint's trivia
			var skipTypeHint = context.config.keepTypes != true && v.init != null && canSkipTypeHint(v.v.type, v.init.expr);
			if (!skipTypeHint) {
				printTypeHint({type: v.v.type, syntax: v.syntax.type});
			}

			if (v.init != null) printVarInit(v.init, skipTypeHint, v.v.type);
			if (v.comma != null) printComma(v.comma);
		}
	}

	public static function canSkipTypeHint(expectedType:TType, expr:TExpr):Bool {
		// we can skip explicit type hint for vars where the type is exactly the same
		// and let the type inference do the job. this makes code easier to read and refactor
		if (expectedType.match(TTAny | TTObject(TTAny)))
			return false;

		switch skipParens(expr).kind {
			case TELiteral(TLNull(_)) | TEArrayDecl(_) | TEObjectDecl(_):
				return false;
			case TELiteral(TLInt(_)) if (expectedType.match(TTNumber | TTUint)):
				return false;
			case TELiteral(TLNumber(_)):
				return false;
			case TECall({kind: TEBuiltin(_, "Vector.convert")}, _):
				// this one depends on the expected type
				return false;
			case TECall({kind: TEBuiltin(_, "ASCompat.reinterpretAs" | "ASCompat.dynamicAs")}, _) if (expectedType.match(TTArray(_))):
				// this one will return an unbound Array element type
				return false;
			case TECall({kind: TEBuiltin(_, "Type.resolveClass")}, _) if (expectedType.match(TTStatic(_))):
				// resolveClass returns an unbound T for Class<T> so don't lose the actual class type
				return false;
			case _:
				return typeEq(expectedType, expr.type);
		}
	}

	function printVarInit(init:TVarInit, includeTypeParams:Bool, expectedType:TType) {
		printTextWithTrivia("=", init.equalsToken);
		switch init.expr.kind {
			case TENew(keyword, newObject = TNType(t), args) if (!includeTypeParams && Type.enumEq(t.type, expectedType)):
				printNew(keyword, newObject, args, false);
			case _:
				printExpr(init.expr);
		}
	}

	function printObjectDecl(o:TObjectDecl) {
		printOpenBrace(o.syntax.openBrace);
		for (f in o.fields) {
			var fieldText = switch f.syntax.nameKind {
				case FNIdent: f.name;
				case FNStringSingle: "'" + f.name + "'";
				case FNStringDouble | FNInteger: '"' + f.name + '"';
			};
			printTextWithTrivia(fieldText, f.syntax.name);
			printColon(f.syntax.colon);
			printExpr(f.expr);
			if (f.syntax.comma != null) printComma(f.syntax.comma);
		}
		printCloseBrace(o.syntax.closeBrace);
	}

	function printFieldAccess(obj:TFieldObject, name:String, token:Token) {
		switch (obj.kind) {
			case TOExplicit(dot, e):
				printExpr(e);

				printTrivia(dot.leadTrivia);
				printTrivia(dot.trailTrivia); // haxe doesn't support some.<whitespace>fieldName, so we move whitespace before the dot (hopefully there won't be any line comments)
				printTrivia(token.leadTrivia);
				buf.add(".");

			case TOImplicitThis(_) | TOImplicitClass(_):
				printTrivia(token.leadTrivia);
		}
		buf.add(name);
		printTrivia(token.trailTrivia);
	}

	function printLiteral(l:TLiteral) {
		switch (l) {
			case TLSuper(syntax): printTextWithTrivia("super", syntax);
			case TLThis(syntax): printTextWithTrivia("this", syntax);
			case TLBool(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNull(syntax): printTextWithTrivia("null", syntax);
			case TLUndefined(syntax): printTextWithTrivia("/*undefined*/null", syntax);
			case TLInt(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLNumber(syntax): printTextWithTrivia(syntax.text, syntax);
			case TLString(syntax): printTextWithTrivia(replaceControlChars(syntax.text, syntax.kind), syntax);
			case TLRegExp(syntax): throw "assert";
		}
	}

	function printBlock(block:TBlock) {
		printOpenBrace(block.syntax.openBrace);
		for (e in block.exprs) {
			printBlockExpr(e);
		}
		printCloseBrace(block.syntax.closeBrace);
	}

	function printBlockExpr(e:TBlockExpr) {
		printExpr(e.expr);
		if (e.semicolon != null) {
			if (e.expr.kind.match(TEUseNamespace(_) | TEBinop(_, OpComma(_), _))) {
				printTrivia(e.semicolon.leadTrivia);
				printTrivia(e.semicolon.trailTrivia);
			} else {
				printSemicolon(e.semicolon);
			}
		} else if (needsSemicolon(e.expr)) {
			buf.add(";");
		}
	}

	static function needsSemicolon(e:TExpr) {
		return switch e.kind {
			case TEBlock(_) | TECondCompBlock(_) | TETry(_) | TESwitch(_) | TEUseNamespace(_) | TEBinop(_, OpComma(_), _):
				false;
			case TEIf(i):
				needsSemicolon(if (i.eelse != null) i.eelse.expr else i.ethen);
			case TEHaxeFor({body: b}), TEFor({body: b}) | TEForIn({body: b}) | TEForEach({body: b}) | TEWhile({body: b}) | TEDoWhile({body: b}):
				needsSemicolon(b);
			case TELocalFunction(f):
				needsSemicolon(f.fun.expr);
			case _:
				true;
		}
	}

	inline function printTokenTrivia(t:Token) {
		printTrivia(t.leadTrivia);
		printTrivia(t.trailTrivia);
	}

	inline function importVector() {
		context.addToplevelImport("flash.Vector", Import);
	}

	inline function importError() {
		context.addToplevelImport("flash.errors.Error", Import);
	}

	static function replaceControlChars(s: String, kind: TokenKind): String {
		s = replaceUnsupportedStringEscapes(s);
		var inner = s.substr(1, s.length - 2);
		var r: Null<Int> = REPLACE_CONTROL_CHAR[inner];
		if (r != null) {
			return 'String.fromCharCode($r)';
		}

		var replacements = findControlCharReplacements(inner);
		if (replacements.length == 0) {
			return s;
		}

		return switch kind {
		case TkStringDouble:
			buildConcatString(inner, replacements);
		case TkStringSingle:
			buildInterpolatedString(inner, replacements);
		case _: s;
		}
	}

	static function replaceUnsupportedStringEscapes(s: String): String {
		if (s.length < 2) {
			return s;
		}
		var quote = s.charAt(0);
		var inner = s.substr(1, s.length - 2);
		var buf = new StringBuf();
		var changed = false;
		var i = 0;
		while (i < inner.length) {
			var ch = inner.charAt(i);
			if (ch == "\\") {
				if (i + 1 >= inner.length) {
					buf.add("\\");
					i++;
					continue;
				}
				var next = inner.charAt(i + 1);
				switch (next) {
					case "b":
						buf.add("\\x08");
						changed = true;
						i += 2;
					case "f":
						buf.add("\\x0C");
						changed = true;
						i += 2;
					case _:
						buf.add("\\");
						buf.add(next);
						i += 2;
				}
			} else {
				buf.add(ch);
				i++;
			}
		}
		if (!changed) {
			return s;
		}
		return quote + buf.toString() + quote;
	}

	static function findControlCharReplacements(inner:String):Array<{start:Int, len:Int, code:Int}> {
		var out:Array<{start:Int, len:Int, code:Int}> = [];
		var i = 0;
		while (i < inner.length) {
			var ch = inner.charAt(i);
			if (ch == "\\") {
				if (i + 1 >= inner.length) {
					i++;
					continue;
				}
				var next = inner.charAt(i + 1);
				if (next == "u" && i + 5 < inner.length) {
					var seq = inner.substr(i, 6);
					var code = REPLACE_CONTROL_CHAR[seq];
					if (code != null) {
						out.push({start: i, len: 6, code: code});
						i += 6;
						continue;
					}
					i += 6;
					continue;
				}
				// Skip escaped character so we don't match control sequences inside \\b, \\uXXXX, etc.
				i += 2;
			} else {
				i++;
			}
		}
		return out;
	}

	static function buildConcatString(inner:String, replacements:Array<{start:Int, len:Int, code:Int}>):String {
		var buf = new StringBuf();
		var segmentStart = 0;
		for (r in replacements) {
			buf.add('"');
			buf.add(inner.substr(segmentStart, r.start - segmentStart));
			buf.add('" + String.fromCharCode(');
			buf.add(Std.string(r.code));
			buf.add(') + "');
			segmentStart = r.start + r.len;
		}
		buf.add(inner.substr(segmentStart));
		buf.add('"');
		return buf.toString();
	}

	static function buildInterpolatedString(inner:String, replacements:Array<{start:Int, len:Int, code:Int}>):String {
		var buf = new StringBuf();
		var segmentStart = 0;
		buf.add("'");
		for (r in replacements) {
			buf.add(inner.substr(segmentStart, r.start - segmentStart));
			buf.add("${String.fromCharCode(");
			buf.add(Std.string(r.code));
			buf.add(")}");
			segmentStart = r.start + r.len;
		}
		buf.add(inner.substr(segmentStart));
		buf.add("'");
		return buf.toString();
	}

	static function replaces(s: String, m: Map<String, String>): String {
		for (k in m.keys()) s = @:nullSafety(Off) s.replace(k, m[k]);
		return s;
	}
}

private enum ReturnTypeRule {
	Print;
	NoVoid;
	Skip;
}
