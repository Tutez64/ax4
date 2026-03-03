package ax4.filters;

import ax4.GenHaxe.canSkipTypeHint;
import ax4.ParseTree;

class FixImports extends AbstractFilter {
	var usedClasses:Null<Map<TClassOrInterfaceDecl, Bool>>;
	var neededImportNames:Null<Map<String, Bool>>;

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		switch e.kind {
			case TEBuiltin(_, name) if (name == "QName" || name == "ByteArray" || name == "ArgumentError"):
				if (neededImportNames != null) {
					neededImportNames[name] = true;
				}
			case TEVars(_, vars):
				for (v in vars) {
					if (v.init == null || !canSkipTypeHint(v.v.type, v.init.expr)) {
						markTypeUsed(v.v.type);
					}
				}
			case TEDeclRef(_, {kind: TDClassOrInterface(c)}):
				markClassUsed(c);
			case TENew(_, TNType(t), _):
				markTypeUsed(t.type);
				if (t.syntax != null) {
					maybeMarkTypeName(t.syntax);
				}
			case TECast(c):
				markTypeUsed(c.type);
			case TEVector(_, t):
				markTypeUsed(t);
			case TEHaxeRetype(_):
				markTypeUsed(e.type);
			case _:
		}
		return e;
	}

	override function processModule(mod:TModule) {
		usedClasses = new Map();
		neededImportNames = new Map();
		processDecl(mod.pack.decl);
		for (decl in mod.privateDecls) {
			processDecl(decl);
		}
		processImports(mod);
		addMissingImports(mod);
		usedClasses = null;
		neededImportNames = null;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		super.processClass(c);
		switch c.kind {
			case TInterface(info):
				if (info.extend != null) {
					for (i in info.extend.interfaces) {
						markClassUsed(i.iface.decl);
					}
				}
			case TClass(info):
				if (info.extend != null) {
					markClassUsed(info.extend.superClass);
				}
				if (info.implement != null) {
					for (i in info.implement.interfaces) {
						markClassUsed(i.iface.decl);
					}
				}
		}
	}

	override function processVarField(v:TVarField) {
		markTypeUsed(v.type);
		super.processVarField(v);
	}

	override function processSignature(sig:TFunctionSignature):TFunctionSignature {
		for (arg in sig.args) {
			markTypeUsed(arg.type);
		}
		markTypeUsed(sig.ret.type);
		return super.processSignature(sig);
	}

	override function processImport(i:TImport):Bool {
		return switch i.kind {
			case TIDecl({kind: TDClassOrInterface(cls)}):
				usedClasses.exists(cls);
			case _:
				true;
		}
	}

	inline function markClassUsed(cls:TClassOrInterfaceDecl) {
		usedClasses[cls] = true;
	}

	function markTypeUsed(t:TType) {
		switch t {
			case TTArray(t) | TTObject(t) | TTVector(t):
				markTypeUsed(t);
			case TTDictionary(k, v):
				markTypeUsed(k);
				markTypeUsed(v);
			case TTFun(args, ret, _):
				for (arg in args) {
					markTypeUsed(arg);
				}
				markTypeUsed(ret);
			case TTInst(cls) | TTStatic(cls):
				markClassUsed(cls);
			case TTVoid | TTAny | TTBoolean | TTNumber | TTInt | TTUint | TTString | TTFunction | TTClass | TTXML | TTXMLList | TTRegExp | TTBuiltin:
				// these are always imported
		}
	}

	function addMissingImports(mod:TModule) {
		var needed:Array<TClassOrInterfaceDecl> = [];
		for (cls in usedClasses.keys()) {
			if (cls.name == "QName" || cls.name == "ByteArray") {
				var resolved = resolveFlashUtilsClass(cls.name);
				if (resolved != null && !hasImport(mod, resolved)) {
					needed.push(resolved);
				}
			}
		}
		if (neededImportNames != null) {
			for (name in neededImportNames.keys()) {
				var cls = switch name {
					case "QName" | "ByteArray": resolveFlashUtilsClass(name);
					case "ArgumentError": resolveFlashErrorsClass(name);
					case _: null;
				};
				if (cls != null && !hasImport(mod, cls)) {
					needed.push(cls);
				}
			}
		}
		if (needed.length == 0) return;

		var trivia = getImportTrivia(mod);
		for (cls in needed) {
			mod.pack.imports.push(mkClassImport(cls, trivia.lead, trivia.trail));
		}
	}

	function maybeMarkTypeName(syntax:SyntaxType) {
		switch syntax {
			case TPath(path):
				var name = ParseTree.dotPathToString(path);
				if (name == "ArgumentError") {
					neededImportNames[name] = true;
				}
			case _:
		}
	}

	function hasImport(mod:TModule, cls:TClassOrInterfaceDecl):Bool {
		for (i in mod.pack.imports) {
			switch i.kind {
				case TIDecl({kind: TDClassOrInterface(c)}):
					if (c == cls) return true;
				case TIAliased({kind: TDClassOrInterface(c)}, _, _):
					if (c == cls) return true;
				case TIAll(pack, _, _):
					if (pack == cls.parentModule.parentPack) return true;
				case _:
			}
		}
		return false;
	}

	inline function isFlashUtilsClass(cls:TClassOrInterfaceDecl, name:String):Bool {
		return cls.name == name && cls.parentModule.parentPack.name == "flash.utils";
	}

	function resolveFlashUtilsClass(name:String):Null<TClassOrInterfaceDecl> {
		var decl = try tree.getDecl("flash.utils", name) catch (_:Dynamic) null;
		if (decl != null) {
			return switch decl.kind {
				case TDClassOrInterface(c): c;
				case _: null;
			};
		}
		return {
			syntax: null,
			kind: null,
			metadata: [],
			modifiers: [],
			parentModule: {
				isExtern: false,
				path: "flash.utils." + name,
				parentPack: new TPackage("flash.utils"),
				pack: null,
				name: "flash.utils." + name,
				privateDecls: [],
				eof: null
			},
			name: name,
			members: []
		};
	}

	function resolveFlashErrorsClass(name:String):Null<TClassOrInterfaceDecl> {
		var decl = try tree.getDecl("flash.errors", name) catch (_:Dynamic) null;
		if (decl != null) {
			return switch decl.kind {
				case TDClassOrInterface(c): c;
				case _: null;
			};
		}
		return {
			syntax: null,
			kind: null,
			metadata: [],
			modifiers: [],
			parentModule: {
				isExtern: false,
				path: "flash.errors." + name,
				parentPack: new TPackage("flash.errors"),
				pack: null,
				name: "flash.errors." + name,
				privateDecls: [],
				eof: null
			},
			name: name,
			members: []
		};
	}

	function getImportTrivia(mod:TModule):{lead:Array<Trivia>, trail:Array<Trivia>} {
		if (mod.pack.imports.length > 0) {
			var last = mod.pack.imports[mod.pack.imports.length - 1];
			return {
				lead: cloneTrivia(last.syntax.keyword.leadTrivia),
				trail: cloneTrivia(last.syntax.semicolon.trailTrivia)
			};
		}
		return {lead: [newline, whitespace], trail: [newline]};
	}

	function mkClassImport(cls:TClassOrInterfaceDecl, lead:Array<Trivia>, trail:Array<Trivia>):TImport {
		var path = dotPathFromString(cls.parentModule.parentPack.name + "." + cls.name, []);
		return {
			syntax: {
				condCompBegin: null,
				keyword: mkIdent("import", cloneTrivia(lead), [whitespace]),
				path: path,
				semicolon: addTrailingTrivia(mkSemicolon(), trail),
				condCompEnd: null
			},
			kind: TIDecl({name: cls.name, kind: TDClassOrInterface(cls)})
		};
	}

	function dotPathFromString(path:String, lead:Array<Trivia>):DotPath {
		var parts = path.split(".");
		var first = mkIdent(parts[0], lead, []);
		var rest = [];
		for (i in 1...parts.length) {
			rest.push({sep: mkDot(), element: mkIdent(parts[i])});
		}
		return {first: first, rest: rest};
	}

	function addTrailingTrivia(token:Token, trivia:Array<Trivia>):Token {
		for (t in trivia) token.trailTrivia.push(t);
		return token;
	}

	function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}
}
