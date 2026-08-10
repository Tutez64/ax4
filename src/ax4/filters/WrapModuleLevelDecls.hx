package ax4.filters;

import ax4.ParseTree;

typedef WrappedModuleDecl = {
	var cls:TClassOrInterfaceDecl;
	var fieldName:String;
};

// TODO: add static import to this package's `import.hx`
// TODO: rewrite imports to a static field import
// TODO: also collect private module declarations in a class and change access to them
class WrapModuleLevelDecls extends AbstractFilter {
	final wrappedDecls:Map<TDecl, WrappedModuleDecl> = new Map();

	override function run(tree:TypedTree) {
		this.tree = tree;
		for (pack in tree.packages) {
			// Snapshot: renameModule mutates the package's module map.
			var mods = [for (mod in pack) mod];
			for (mod in mods) {
				if (mod.isExtern) continue;
				currentPath = mod.path;
				wrapModule(mod);
				currentPath = null;
			}
		}
		super.run(tree);
	}

	override function processModule(mod:TModule) {
		processDecl(mod.pack.decl);
		for (decl in mod.privateDecls) {
			processDecl(decl);
		}
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEDeclRef(path, decl):
				var info = wrappedDecls[decl];
				if (info == null) {
					e;
				} else {
					rewriteToStaticField(e, path, info);
				}
			case _:
				e;
		}
	}

	function wrapModule(mod:TModule) {
		var oldDecl = mod.pack.decl;
		var mainDeclField = convertDeclToStaticField(oldDecl);
		if (mainDeclField == null) {
			return;
		}

		var moduleName = makeHaxeModuleName(mod.name);
		mod.parentPack.renameModule(mod, moduleName);

		// Haxe cannot resolve ClassName.ClassName when a static field shares the class name
		// (even with a fully qualified path). Rename the field to avoid the ambiguity.
		var fieldName = getFieldName(mainDeclField);
		if (fieldName == moduleName) {
			fieldName = fieldName + "_";
			renameField(mainDeclField, fieldName);
		}

		var cls:TClassOrInterfaceDecl = {
			syntax: {
				keyword: mkIdent("class", [], [whitespace]),
				name: mkIdent(moduleName, [], [whitespace]),
				openBrace: addTrailingNewline(mkOpenBrace()),
				closeBrace: addTrailingNewline(mkCloseBrace())
			},
			kind: TClass({extend: null, implement: null}),
			metadata: [],
			modifiers: [DMFinal(mkIdent("final", [], [whitespace]))],
			parentModule: mod,
			name: moduleName,
			members: [TMField(mainDeclField)]
		};

		mod.pack.decl = {
			name: moduleName,
			kind: TDClassOrInterface(cls)
		};

		wrappedDecls[oldDecl] = {
			cls: cls,
			fieldName: fieldName
		};
	}

	function rewriteToStaticField(e:TExpr, path:DotPath, info:WrappedModuleDecl):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		path.first.leadTrivia = lead;

		var tClass = TTStatic(info.cls);
		var eClass = mk(TEDeclRef(path, {name: info.cls.name, kind: TDClassOrInterface(info.cls)}), tClass, tClass);
		var fieldToken = mkIdent(info.fieldName, [], trail);
		return mk(
			TEField({kind: TOExplicit(mkDot(), eClass), type: tClass}, info.fieldName, fieldToken),
			e.type,
			e.expectedType
		);
	}

	static function makeHaxeModuleName(s:String):String {
		var firstChar = s.charAt(0);
		return
			if (firstChar == "_")
				"Underscore" + s.substring(1)
			else
				firstChar.toUpperCase() + s.substring(1);
	}

	static function getFieldName(field:TClassField):String {
		return switch field.kind {
			case TFVar(v): v.name;
			case TFFun(f): f.name;
			case TFGetter(a) | TFSetter(a): a.name;
		};
	}

	static function renameField(field:TClassField, newName:String) {
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
		}
	}

	static inline function renameToken(t:Token, name:String):Token {
		return new Token(t.pos, TkIdent, name, t.leadTrivia, [new Trivia(TrBlockComment, "/*class name collision*/")].concat(t.trailTrivia));
	}

	function convertDeclToStaticField(decl:TDecl):Null<TClassField> {
		switch decl.kind {
			case TDVar(v):
				return {
					metadata: v.metadata,
					namespace: null,
					modifiers: convertDeclModifiers(v.syntax.name.pos, v.modifiers),
					kind: TFVar({
						kind: v.kind,
						syntax: v.syntax,
						name: v.name,
						type: v.type,
						init: v.init,
						isInline: v.isInline,
						semicolon: v.semicolon
					})
				};

			case TDFunction(f):
				return {
					metadata: f.metadata,
					namespace: null,
					modifiers: convertDeclModifiers(f.syntax.keyword.pos, f.modifiers),
					kind: TFFun({
						syntax: f.syntax,
						name: f.name,
						fun: f.fun,
						type: getFunctionTypeFromSignature(f.fun.sig),
						isInline: false,
						semicolon: null
					})
				};

			case TDClassOrInterface(_) | TDNamespace(_):
				return null;
		}
	}

	function convertDeclModifiers(pos:Int, mods:Array<DeclModifier>):Array<ClassFieldModifier> {
		var result = [];
		switch mods {
			case [DMPublic(t)]: result.push(FMPublic(t));
			case [DMInternal(t)]: result.push(FMInternal(t));
			case _: reportError(pos, "Unknown module-level function/var modifiers");
		}
		result.push(FMStatic(mkIdent("static", [], [whitespace])));
		return result;
	}
}
