package ax4.filters;

import ax4.TypedTree;
import ax4.Token;
import ax4.TypedTreeTools.*;

/**
 * Renames AS3 identifiers that are reserved keywords in Haxe.
 * AS3 treats some words (e.g. `override`) as contextual keywords, so they are
 * valid parameter/variable/field names; Haxe does not allow that.
 */
class EscapeHaxeKeywords extends AbstractFilter {
	final classFieldRenames:Map<TClassOrInterfaceDecl, Map<String, String>> = new Map();
	final moduleDeclRenames:Map<TDecl, {oldName:String, newName:String}> = new Map();
	var currentUsedNames:Null<Map<String, Bool>>;

	override function run(tree:TypedTree) {
		this.tree = tree;
		for (pack in tree.packages) {
			for (mod in pack) {
				if (mod.isExtern) continue;
				detectModule(mod);
			}
		}
		super.run(tree);
	}

	function detectModule(mod:TModule) {
		var decls = [mod.pack.decl].concat(mod.privateDecls);
		var usedDeclNames = new Map<String, Bool>();
		for (decl in decls) {
			usedDeclNames[decl.name] = true;
		}
		for (decl in decls) {
			switch decl.kind {
				case TDVar(_) | TDFunction(_):
					if (isHaxeKeyword(decl.name) && !moduleDeclRenames.exists(decl)) {
						moduleDeclRenames[decl] = {
							oldName: decl.name,
							newName: makeUniqueName(decl.name, usedDeclNames)
						};
					}
				case TDClassOrInterface(c):
					detectClassFields(c);
				case TDNamespace(_):
			}
		}
	}

	function detectClassFields(c:TClassOrInterfaceDecl) {
		var used = collectClassFieldNames(c);
		var renames:Map<String, String> = null;
		for (member in c.members) {
			switch member {
				case TMField(field):
					var name = getFieldName(field);
					if (!isHaxeKeyword(name)) continue;
					if (renames == null) {
						renames = new Map();
						classFieldRenames[c] = renames;
					}
					if (!renames.exists(name)) {
						renames[name] = makeUniqueName(name, used);
					}
				case _:
			}
		}
	}

	override function processModule(mod:TModule) {
		renameModuleDecl(mod.pack.decl);
		for (decl in mod.privateDecls) {
			renameModuleDecl(decl);
		}
		super.processModule(mod);
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		renameClassFields(c);
		super.processClass(c);
	}

	override function processFunction(fun:TFunction) {
		var previousUsed = currentUsedNames;
		currentUsedNames = collectNamesInFunction(fun);
		for (arg in fun.sig.args) {
			if (isHaxeKeyword(arg.name)) {
				renameArg(arg, makeUniqueName(arg.name, currentUsedNames));
			}
		}
		fun.sig = processSignature(fun.sig);
		if (fun.expr != null) fun.expr = processExpr(fun.expr);
		currentUsedNames = previousUsed;
	}

	override function processExpr(e:TExpr):TExpr {
		switch e.kind {
			case TELocalFunction(f):
				if (f.name != null && isHaxeKeyword(f.name.name) && currentUsedNames != null) {
					var newName = makeUniqueName(f.name.name, currentUsedNames);
					f.name.name = newName;
					f.name.syntax = renameToken(f.name.syntax, newName);
				}
				processFunction(f.fun);
				return e;
			case _:
		}

		e = mapExpr(processExpr, e);
		var used = currentUsedNames;
		return switch e.kind {
			case TEVars(_, vars):
				if (used == null) {
					used = new Map();
					for (v in vars) used[v.v.name] = true;
				}
				for (v in vars) {
					if (isHaxeKeyword(v.v.name)) {
						var newName = makeUniqueName(v.v.name, used);
						v.v.name = newName;
						v.syntax.name = renameToken(v.syntax.name, newName);
					}
				}
				e;

			case TETry(t):
				if (used == null) {
					used = new Map();
					for (c in t.catches) used[c.v.name] = true;
				}
				for (c in t.catches) {
					if (isHaxeKeyword(c.v.name)) {
						var newName = makeUniqueName(c.v.name, used);
						c.v.name = newName;
						c.syntax.name = renameToken(c.syntax.name, newName);
					}
				}
				e;

			case TEHaxeFor(f):
				if (isHaxeKeyword(f.vit.name)) {
					if (used == null) used = [f.vit.name => true];
					f.vit.name = makeUniqueName(f.vit.name, used);
				}
				e;

			case TEField(obj, fieldName, fieldToken):
				var renamed = resolveFieldRename(obj, fieldName);
				if (renamed == null) {
					e;
				} else {
					e.with(kind = TEField(obj, renamed, fieldToken.with(TkIdent, renamed)));
				}

			case TEDeclRef(path, decl):
				var rename = moduleDeclRenames[decl];
				if (rename == null) {
					e;
				} else {
					renameDotPathLast(path, rename.oldName, rename.newName);
					e.with(kind = TEDeclRef(path, decl));
				}

			case _:
				e;
		}
	}

	function renameModuleDecl(decl:TDecl) {
		var rename = moduleDeclRenames[decl];
		if (rename == null) return;
		decl.name = rename.newName;
		switch decl.kind {
			case TDVar(v):
				v.name = rename.newName;
				v.syntax.name = renameToken(v.syntax.name, rename.newName);
			case TDFunction(f):
				f.name = rename.newName;
				f.syntax.name = renameToken(f.syntax.name, rename.newName);
			case _:
		}
	}

	function renameClassFields(c:TClassOrInterfaceDecl) {
		var renames = classFieldRenames[c];
		if (renames == null) return;
		for (member in c.members) {
			switch member {
				case TMField(field):
					var oldName = getFieldName(field);
					var newName = renames[oldName];
					if (newName != null) renameClassField(field, newName);
				case _:
			}
		}
	}

	function renameClassField(field:TClassField, newName:String) {
		switch field.kind {
			case TFVar(v):
				v.name = newName;
				v.syntax.name = renameToken(v.syntax.name, newName);
			case TFFun(f):
				f.name = newName;
				f.syntax.name = renameToken(f.syntax.name, newName);
			case TFGetter(a) | TFSetter(a):
				a.name = newName;
				a.syntax.name = renameToken(a.syntax.name, newName);
				if (a.haxeProperty != null) {
					a.haxeProperty.name = newName;
				}
		}
	}

	function resolveFieldRename(obj:TFieldObject, fieldName:String):Null<String> {
		return switch obj.type {
			case TTInst(c) | TTStatic(c):
				findFieldRenameInHierarchy(c, fieldName);
			case _:
				null;
		}
	}

	function findFieldRenameInHierarchy(c:TClassOrInterfaceDecl, fieldName:String):Null<String> {
		var current = c;
		while (current != null) {
			var classRenames = classFieldRenames[current];
			if (classRenames != null && classRenames.exists(fieldName)) {
				return classRenames[fieldName];
			}
			switch current.kind {
				case TClass(info) if (info.extend != null):
					current = info.extend.superClass;
				case _:
					current = null;
			}
		}
		return null;
	}

	static function renameArg(arg:TFunctionArg, newName:String) {
		arg.name = newName;
		if (arg.v != null) {
			arg.v.name = newName;
		}
		arg.syntax.name = renameToken(arg.syntax.name, newName);
	}

	static function collectNamesInFunction(fun:TFunction):Map<String, Bool> {
		var used = new Map<String, Bool>();
		for (arg in fun.sig.args) {
			used[arg.name] = true;
		}
		if (fun.expr != null) {
			collectNamesInExpr(fun.expr, used);
		}
		return used;
	}

	static function collectNamesInExpr(e:TExpr, used:Map<String, Bool>) {
		switch e.kind {
			case TEVars(_, vars):
				for (v in vars) used[v.v.name] = true;
			case TETry(t):
				for (c in t.catches) used[c.v.name] = true;
			case TEHaxeFor(f):
				used[f.vit.name] = true;
			case TELocalFunction(f):
				if (f.name != null) used[f.name.name] = true;
			case _:
		}
		iterExpr(e -> collectNamesInExpr(e, used), e);
	}

	static function collectClassFieldNames(c:TClassOrInterfaceDecl):Map<String, Bool> {
		var names = new Map<String, Bool>();
		for (member in c.members) {
			switch member {
				case TMField(field):
					names[getFieldName(field)] = true;
				case _:
			}
		}
		return names;
	}

	static function getFieldName(field:TClassField):String {
		return switch field.kind {
			case TFVar(v): v.name;
			case TFFun(f): f.name;
			case TFGetter(a) | TFSetter(a): a.name;
		}
	}

	static function makeUniqueName(baseName:String, usedNames:Map<String, Bool>):String {
		var candidate = baseName + "_";
		while (usedNames.exists(candidate) || isHaxeKeyword(candidate)) {
			candidate += "_";
		}
		usedNames[candidate] = true;
		return candidate;
	}

	static function renameDotPathLast(path:DotPath, oldName:String, newName:String) {
		if (path.rest.length == 0) {
			if (path.first.text == oldName) {
				path.first = path.first.with(TkIdent, newName);
			}
			return;
		}
		var last = path.rest[path.rest.length - 1];
		if (last.element.text == oldName) {
			last.element = last.element.with(TkIdent, newName);
		}
	}

	static inline function renameToken(t:Token, name:String):Token {
		return new Token(t.pos, TkIdent, name, t.leadTrivia, [new Trivia(TrBlockComment, "/*haxe keyword*/")].concat(t.trailTrivia));
	}

	public static inline function isHaxeKeyword(name:String):Bool {
		return haxeKeywords.exists(name);
	}

	/** Haxe reserved words that cannot be used as identifiers (plus `is`, reserved since Haxe 4.2). */
	static final haxeKeywords = [
		"abstract" => true,
		"break" => true,
		"case" => true,
		"cast" => true,
		"catch" => true,
		"class" => true,
		"continue" => true,
		"default" => true,
		"do" => true,
		"dynamic" => true,
		"else" => true,
		"enum" => true,
		"extends" => true,
		"extern" => true,
		"false" => true,
		"final" => true,
		"for" => true,
		"function" => true,
		"if" => true,
		"implements" => true,
		"import" => true,
		"in" => true,
		"inline" => true,
		"interface" => true,
		"is" => true,
		"macro" => true,
		"new" => true,
		"null" => true,
		"operator" => true,
		"overload" => true,
		"override" => true,
		"package" => true,
		"private" => true,
		"public" => true,
		"return" => true,
		"static" => true,
		"switch" => true,
		"this" => true,
		"throw" => true,
		"true" => true,
		"try" => true,
		"typedef" => true,
		"untyped" => true,
		"using" => true,
		"var" => true,
		"while" => true
	];
}
