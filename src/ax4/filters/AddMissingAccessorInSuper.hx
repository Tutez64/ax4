package ax4.filters;

import ax4.Token.nullToken;

private typedef AccessInfo = {
	var get:Bool;
	var set:Bool;
	var type:TType;
	var field:TClassField;
}

private typedef AccessNeed = {
	var needGet:Bool;
	var needSet:Bool;
	var type:TType;
}

class AddMissingAccessorInSuper extends AbstractFilter {
	override function run(tree:TypedTree) {
		this.tree = tree;
		var accessMap = collectClassAccessors();
		var additions = computeAdditions(accessMap);
		applyAdditions(additions, accessMap);
		super.run(tree);
	}

	function collectClassAccessors():Map<TClassOrInterfaceDecl, Map<String, AccessInfo>> {
		var result:Map<TClassOrInterfaceDecl, Map<String, AccessInfo>> = new Map();
		for (pack in tree.packages) {
			for (mod in pack) {
				if (mod.isExtern) continue;
				collectDecl(mod.pack.decl, result);
				for (decl in mod.privateDecls) {
					collectDecl(decl, result);
				}
			}
		}
		return result;
	}

	function collectDecl(decl:TDecl, result:Map<TClassOrInterfaceDecl, Map<String, AccessInfo>>) {
		switch decl.kind {
			case TDClassOrInterface(c):
				switch c.kind {
					case TClass(_):
						var map:Map<String, AccessInfo> = new Map();
						for (member in c.members) {
							switch member {
								case TMField(f):
									switch f.kind {
										case TFGetter(a):
											var info = map[a.name];
											if (info == null) {
												map[a.name] = {get: true, set: false, type: a.fun.sig.ret.type, field: f};
											} else {
												info.get = true;
											}
										case TFSetter(a):
											var info = map[a.name];
											var propType = a.fun.sig.args.length > 0 ? a.fun.sig.args[0].type : a.propertyType;
											if (info == null) {
												map[a.name] = {get: false, set: true, type: propType, field: f};
											} else {
												info.set = true;
											}
										case _:
									}
								case _:
							}
						}
						result[c] = map;
					case _:
				}
			case _:
		}
	}

	function computeAdditions(accessMap:Map<TClassOrInterfaceDecl, Map<String, AccessInfo>>):Map<TClassOrInterfaceDecl, Map<String, AccessNeed>> {
		var additions:Map<TClassOrInterfaceDecl, Map<String, AccessNeed>> = new Map();
		for (cls in accessMap.keys()) {
			var infoMap = accessMap[cls];
			if (infoMap == null) continue;
			for (name in infoMap.keys()) {
				var info = infoMap[name];
				if (!info.get && !info.set) continue;
				var superClass = getSuperClass(cls);
				while (superClass != null) {
					var superInfoMap = accessMap[superClass];
					if (superInfoMap != null) {
						var superInfo = superInfoMap[name];
						if (superInfo != null) {
							var needGet = info.get && !superInfo.get;
							var needSet = info.set && !superInfo.set;
							if (needGet || needSet) {
								var perClass = additions[superClass];
								if (perClass == null) {
									perClass = new Map();
									additions[superClass] = perClass;
								}
								var existing = perClass[name];
								if (existing == null) {
									perClass[name] = {needGet: needGet, needSet: needSet, type: superInfo.type};
								} else {
									existing.needGet = existing.needGet || needGet;
									existing.needSet = existing.needSet || needSet;
								}
							}
							break;
						}
					}
					superClass = getSuperClass(superClass);
				}
			}
		}
		return additions;
	}

	function applyAdditions(additions:Map<TClassOrInterfaceDecl, Map<String, AccessNeed>>, accessMap:Map<TClassOrInterfaceDecl, Map<String, AccessInfo>>) {
		for (cls in additions.keys()) {
			var addMap = additions[cls];
			if (addMap == null) continue;
			var accessInfoMap = accessMap[cls];
			for (name in addMap.keys()) {
				var need = addMap[name];
				if (need == null) continue;
				var accessInfo = accessInfoMap != null ? accessInfoMap[name] : null;
				if (accessInfo == null) continue;

				updatePropertyAccess(accessInfo.field, need);

				if (need.needGet) {
					var getterField = buildGetter(name, need.type, accessInfo.field);
					cls.members.push(TMField(getterField));
				}
				if (need.needSet) {
					var setterField = buildSetter(name, need.type, accessInfo.field);
					cls.members.push(TMField(setterField));
				}
			}
		}
	}

	function updatePropertyAccess(field:TClassField, need:AccessNeed) {
		switch field.kind {
			case TFGetter(a):
				if (a.haxeProperty != null) {
					if (need.needSet) a.haxeProperty.set = true;
				}
			case TFSetter(a):
				if (a.haxeProperty != null) {
					if (need.needGet) a.haxeProperty.get = true;
				}
			case _:
		}
	}

	function buildGetter(name:String, type:TType, refField:TClassField):TClassField {
		var indent = extractIndent(getFieldLeadingToken(refField).leadTrivia);
		var funToken = mkIdent("function", indent, [whitespace]);
		var nameToken = mkIdent(name);
		var returnToken = mkIdent("return", indent.concat([new Trivia(TrWhitespace, "\t")]), [whitespace]);
		var retExpr = mk(TEReturn(returnToken, defaultExpr(type)), TTVoid, TTVoid);
		var body = mk(TEBlock({
			syntax: {openBrace: addTrailingNewline(mkOpenBrace()), closeBrace: mkCloseBrace()},
			exprs: [{expr: retExpr, semicolon: addTrailingNewline(mkSemicolon())}]
		}), TTVoid, TTVoid);

		var sig:TFunctionSignature = {
			syntax: {openParen: mkOpenParen(), closeParen: mkCloseParen()},
			args: [],
			ret: {syntax: null, type: type}
		};

		return {
			metadata: [],
			namespace: null,
			modifiers: refField.modifiers.copy(),
			kind: TFGetter({
				syntax: {functionKeyword: funToken, accessorKeyword: nullToken, name: nameToken},
				name: name,
				fun: {sig: sig, expr: body},
				propertyType: type,
				haxeProperty: null,
				isInline: false,
				semicolon: null
			})
		};
	}

	function buildSetter(name:String, type:TType, refField:TClassField):TClassField {
		var indent = extractIndent(getFieldLeadingToken(refField).leadTrivia);
		var funToken = mkIdent("function", indent, [whitespace]);
		var nameToken = mkIdent(name);
		var argVar:TVar = {name: "value", type: type};
		var argToken = mkIdent("value");
		var arg:TFunctionArg = {
			syntax: {name: argToken},
			name: "value",
			type: type,
			v: argVar,
			kind: TArgNormal(null, null),
			comma: null
		};
		var returnToken = mkIdent("return", indent.concat([new Trivia(TrWhitespace, "\t")]), [whitespace]);
		var argExpr = mk(TELocal(argToken, argVar), type, type);
		var retExpr = mk(TEReturn(returnToken, argExpr), TTVoid, TTVoid);
		var body = mk(TEBlock({
			syntax: {openBrace: addTrailingNewline(mkOpenBrace()), closeBrace: mkCloseBrace()},
			exprs: [{expr: retExpr, semicolon: addTrailingNewline(mkSemicolon())}]
		}), TTVoid, TTVoid);

		var sig:TFunctionSignature = {
			syntax: {openParen: mkOpenParen(), closeParen: mkCloseParen()},
			args: [arg],
			ret: {syntax: null, type: type}
		};

		return {
			metadata: [],
			namespace: null,
			modifiers: refField.modifiers.copy(),
			kind: TFSetter({
				syntax: {functionKeyword: funToken, accessorKeyword: nullToken, name: nameToken},
				name: name,
				fun: {sig: sig, expr: body},
				propertyType: type,
				haxeProperty: null,
				isInline: false,
				semicolon: null
			})
		};
	}

	function defaultExpr(type:TType):TExpr {
		return switch type {
			case TTInt:
				mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
			case TTUint:
				mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTUint, TTUint);
			case TTNumber:
				mk(TELiteral(TLNumber(new Token(0, TkFloat, "0", [], []))), TTNumber, TTNumber);
			case TTBoolean:
				mk(TELiteral(TLBool(new Token(0, TkIdent, "false", [], []))), TTBoolean, TTBoolean);
			case TTString:
				mk(TELiteral(TLString(new Token(0, TkStringDouble, "\"\"", [], []))), TTString, TTString);
			case _:
				mkNullExpr(type);
		}
	}

	static function extractIndent(trivia:Array<Trivia>):Array<Trivia> {
		var result:Array<Trivia> = [];
		for (item in trivia) {
			switch item.kind {
				case TrWhitespace:
					result.push(item);
				case TrNewline:
					result = [];
				case _:
			}
		}
		return result;
	}

	static function getSuperClass(c:TClassOrInterfaceDecl):Null<TClassOrInterfaceDecl> {
		return switch c.kind {
			case TClass(info):
				info.extend != null ? info.extend.superClass : null;
			case _:
				null;
		}
	}
}
