package ax4.filters;

import ax4.Token.nullToken;
import ax4.TokenTools.mkIdent;
import ax4.TokenTools.mkDot;
import ax4.ParseTree.dotPathToArray;
import ax4.ParseTree.dotPathToString;

// TODO: handle unimported globals from toplevel package (expr filter?)
class ExternModuleLevelImports extends AbstractFilter {
	final globals = new Map<String, {dotPath:String, kind:TDeclKind}>();
	var pendingGlobals:Null<Map<String, {dotPath:String, decl:TDecl}>> = null;

	static final asToken = mkIdent("as", [whitespace], [whitespace]);

	override function processModule(mod:TModule) {
		pendingGlobals = new Map();
		super.processModule(mod);
		addPendingImports(mod);
		pendingGlobals = null;
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		switch e.kind {
			case TEDeclRef(_, {kind: TDFunction(f)}):
				var dotPath = f.parentModule.parentPack.name + "." + f.parentModule.name;
				if (!isIgnoredImport(dotPath) && dotPath == "flash.utils.getQualifiedClassName") {
					var fieldName = dotPath.split(".").join("_");
					if (pendingGlobals != null && !pendingGlobals.exists(fieldName)) {
						pendingGlobals[fieldName] = {dotPath: dotPath, decl: {name: f.name, kind: TDFunction(f)}};
					}
				}
			case _:
		}
		return e;
	}

	override function processImport(i:TImport):Bool {
		switch i.kind {
			case TIDecl(decl):
				switch decl.kind {
					case TDClassOrInterface(_): // ok
						return true;

					case TDNamespace(_): // ignored
						return false;

					case TDVar(_) | TDFunction(_): // need to be replaced
						var path = dotPathToArray(i.syntax.path);

						var dotPath = path.join(".");
						if (isIgnoredImport(dotPath)) {
							return false;
						}

						if (dotPath == "flash.net.registerClassAlias") {
							i.syntax.path = {
								first: mkIdent("ASCompat"),
								rest: [{sep: mkDot(), element: mkIdent("registerClassAlias")}]
							};
						} else {
							var fieldName = path.join("_"); // TODO: possible name clashes;

							globals[fieldName] = {dotPath: dotPath, kind: decl.kind};

							i.syntax.path = {
								first: mkIdent("Globals"),
								rest: [{sep: mkDot(), element: mkIdent(fieldName)}]
							};
						}
						i.kind = TIAliased(decl, asToken, mkIdent(decl.name));
						return true;

				}

			case TIAll(_) | TIAliased(_):
				return true;
		}
	}

	static function isIgnoredImport(path:String) return switch path {
		case "flash.utils.getDefinitionByName" // rewritten by UtilFunctions (TODO maybe the list should be in UtilFunctions)
		   | "flash.utils.getQualifiedClassName"
		   | "avmplus.getQualifiedClassName"
		   | "flash.profiler.showRedrawRegions"
		   | "flash.utils.flash_proxy"
		   | "flash.utils.getTimer"
		   | "flash.utils.describeType"
		   | "flash.utils.setTimeout"
		   | "flash.utils.clearTimeout"
		   | "flash.utils.setInterval"
		   | "flash.utils.clearInterval"
		   | "flash.net.navigateToURL"
		   : true;
		case _: false;
	}

	static final trTab = new Trivia(TrWhitespace, "\t");
	static final trTabTab = new Trivia(TrWhitespace, "\t\t");
	static final mPublic = FMPublic(mkIdent("public", [trTab], [whitespace]));
	static final mStatic = FMStatic(mkIdent("static", [], [whitespace]));
	static final mStatic2 = FMStatic(mkIdent("static", [trTab], [whitespace]));
	static final tReturn = mkIdent("return", [trTabTab], [whitespace]);
	static final tFunction = mkIdent("function", [], [whitespace]);
	static final tAssign = new Token(0, TkEquals, "=", [whitespace], [whitespace]);

	static final funSigSyntax = {
		openParen: mkOpenParen(),
		closeParen: mkCloseParen()
	};

	static function mkGlobalAccess(name:String):TExpr {
		var eGlobal = mkBuiltin("untyped __global__", TTBuiltin);
		return mk(TEArrayAccess({
			syntax: {
				openBracket: mkOpenBracket(),
				closeBracket: mkCloseBracket()
			},
			eobj: eGlobal,
			eindex: mk(TELiteral(TLString(mkString(name))), TTString, TTString)
		}), TTBuiltin, TTBuiltin);
	}

	static function addIndent(e:TExpr) {
		processLeadingToken(t -> t.leadTrivia.push(trTabTab), e);
	}

	public function addGlobalsModule(tree:TypedTree) {
		var members:Array<TClassMember> = [];

		for (fieldName => entry in globals) {
			var eGlobalAccess = mkGlobalAccess(entry.dotPath);
			switch entry.kind {
				case TDFunction(f):
					var callArgs:Array<{expr:TExpr, comma:Null<Token>}> = [];
					var sigArgs:Array<TFunctionArg> = [];

					for (i in 0...f.fun.sig.args.length) {
						var arg = f.fun.sig.args[i];
						var nameToken = mkIdent(arg.name);
						var comma = if (i < f.fun.sig.args.length - 1) mkComma() else null;
						var v:TVar = {name: arg.name, type: arg.type};

						callArgs.push({
							expr: mk(TELocal(nameToken, v), arg.type, arg.type),
							comma: comma,
						});

						sigArgs.push({
							syntax: {name: nameToken},
							name: arg.name,
							type: arg.type,
							v: v,
							kind: switch arg.kind {
								case TArgNormal(typeHint, init):
									// TODO: support optional args
									TArgNormal(null, null);
								case TArgRest(_):
									// TODO: generate something nice (macro or something)
									trace("WARNING: Not generating correct Global function for " + entry.dotPath);
									TArgNormal(null, null);
							},
							comma: comma
						});
					}

					var returnType = f.fun.sig.ret.type;
					var expr = mk(TECall(eGlobalAccess, {
						openParen: mkOpenParen(),
						args: callArgs,
						closeParen: mkCloseParen()
					}), returnType, returnType);
					if (returnType != TTVoid) {
						expr = mk(TEReturn(tReturn, expr), TTVoid, TTVoid);
					} else {
						addIndent(expr);
					}

					members.push(TMField({
						metadata: [],
						namespace: null,
						modifiers: [mPublic, mStatic],
						kind: TFFun({
							syntax: {
								keyword: tFunction,
								name: mkIdent(fieldName)
							},
							name: fieldName,
							fun: {
								sig: {
									syntax: funSigSyntax,
									args: sigArgs,
									ret: {
										syntax: null,
										type: f.fun.sig.ret.type
									}
								},
								expr: mk(TEBlock({
									syntax: {
										openBrace: new Token(0, TkBraceOpen, "{", [whitespace], [newline]),
										closeBrace: new Token(0, TkBraceClose, "}", [trTab], [newline])
									},
									exprs: [{
										expr: expr,
										semicolon: addTrailingNewline(mkSemicolon())
									}]
								}), TTVoid, TTVoid)
							},
							type: TypedTreeTools.getFunctionTypeFromSignature(f.fun.sig),
							isInline: false,
							semicolon: null
						})
					}));

				case TDVar(v):
					members.push(TMField({
						metadata: [],
						namespace: null,
						modifiers: [mStatic2],
						kind: TFGetter({
							syntax: {
								functionKeyword: tFunction,
								accessorKeyword: nullToken,
								name: mkIdent(fieldName)
							},
							name: fieldName,
							fun: {
								sig: {
									syntax: funSigSyntax,
									args: [],
									ret: {
										syntax: null,
										type: v.type
									}
								},
								expr: mk(TEBlock({
									syntax: {
										openBrace: new Token(0, TkBraceOpen, "{", [whitespace], [newline]),
										closeBrace: new Token(0, TkBraceClose, "}", [trTab], [newline])
									},
									exprs: [{
										expr: mk(TEReturn(tReturn, eGlobalAccess), TTVoid, TTVoid),
										semicolon: addTrailingNewline(mkSemicolon())
									}]
								}), TTVoid, TTVoid)
							},
							propertyType: v.type,
							haxeProperty: {
								syntax: {leadTrivia: [trTab]},
								isPublic: true,
								isStatic: true,
								metadata: [],
								isFlashProperty: false,
								name: fieldName,
								get: true,
								set: v.kind.match(VVar(_)),
								type: v.type
							},
							isInline: false,
							semicolon: null
						})
					}));

					if (v.kind.match(VVar(_))) {
						var tvar:TVar = {name: "value", type: v.type};
						var tArgName = mkIdent("value");
						var arg:TFunctionArg = {
							syntax: {name: tArgName},
							name: "value",
							type: v.type,
							v: tvar,
							kind: TArgNormal(null, null),
							comma: null
						};
						var eArg = mk(TELocal(tArgName, tvar), v.type, v.type);
						var eAssign = mk(TEBinop(eGlobalAccess, OpAssign(tAssign), eArg), v.type, v.type);
						members.push(TMField({
							metadata: [],
							namespace: null,
							modifiers: [mStatic2],
							kind: TFSetter({
								syntax: {
									functionKeyword: tFunction,
									accessorKeyword: nullToken,
									name: mkIdent(fieldName)
								},
								name: fieldName,
								fun: {
									sig: {
										syntax: funSigSyntax,
										args: [arg],
										ret: {
											syntax: null,
											type: v.type
										}
									},
									expr: mk(TEBlock({
										syntax: {
											openBrace: new Token(0, TkBraceOpen, "{", [whitespace], [newline]),
											closeBrace: new Token(0, TkBraceClose, "}", [trTab], [newline])
										},
										exprs: [{
											expr: mk(TEReturn(tReturn, eAssign), TTVoid, TTVoid),
											semicolon: addTrailingNewline(mkSemicolon())
										}]
									}), TTVoid, TTVoid)
								},
								propertyType: v.type,
								haxeProperty: null,
								isInline: false,
								semicolon: null
							})
						}));
					}

				case _:
					throw "assert";
			}
		}

		if (members.length > 0) {
			var pack = tree.getPackage("");
			var mod:TModule = {
				isExtern: false,
				path: "<generated>",
				parentPack: pack,
				pack: {
					syntax: {
						keyword: nullToken,
						name: null,
						openBrace: nullToken,
						closeBrace: nullToken
					},
					imports: [],
					namespaceUses: [],
					name: "",
					decl: null
				},
				name: "Globals",
				privateDecls: [],
				eof: nullToken
			};
			mod.pack.decl = {
				name: "Globals",
				kind: TDClassOrInterface({
					syntax: {
						keyword: mkIdent("class", [], [whitespace]),
						name: mkIdent("Globals", [], [whitespace]),
						openBrace: addTrailingNewline(mkOpenBrace()),
						closeBrace: addTrailingNewline(mkCloseBrace())
					},
					kind: TClass({extend: null, implement: null}),
					metadata: [],
					modifiers: [],
					parentModule: mod,
					name: "Globals",
					members: members
				})
			};
			pack.addModule(mod);
		}
	}

	function addPendingImports(mod:TModule) {
		if (pendingGlobals == null || pendingGlobals.iterator().hasNext() == false) return;
		var trivia = getImportTrivia(mod);
		for (fieldName => entry in pendingGlobals) {
			if (hasGlobalImport(mod, fieldName, entry.decl.name)) {
				continue;
			}
			globals[fieldName] = {dotPath: entry.dotPath, kind: entry.decl.kind};
			mod.pack.imports.push(mkAliasedImport(entry.decl, fieldName, trivia.lead, trivia.trail));
		}
	}

	function hasGlobalImport(mod:TModule, fieldName:String, declName:String):Bool {
		for (i in mod.pack.imports) {
			switch i.kind {
				case TIAliased(_, _, name):
					if (name.text == declName && dotPathToString(i.syntax.path) == "Globals." + fieldName) {
						return true;
					}
				case _:
			}
		}
		return false;
	}

	function mkAliasedImport(decl:TDecl, fieldName:String, lead:Array<Trivia>, trail:Array<Trivia>):TImport {
		return {
			syntax: {
				condCompBegin: null,
				keyword: mkIdent("import", cloneTrivia(lead), [whitespace]),
				path: dotPathFromString("Globals." + fieldName, []),
				semicolon: addTrailingTrivia(mkSemicolon(), trail),
				condCompEnd: null
			},
			kind: TIAliased(decl, asToken, mkIdent(decl.name))
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
