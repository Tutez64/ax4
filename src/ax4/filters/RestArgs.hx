package ax4.filters;

import ax4.ParseTree.TypeHint;

class RestArgs extends AbstractFilter {
	override function processFunction(fun:TFunction) {
		if (fun.expr != null) fun.expr = processExpr(fun.expr);

		if (fun.sig.args.length > 0) {
			var lastArg = fun.sig.args[fun.sig.args.length - 1];
			switch lastArg.kind {
				case TArgNormal(_):
					// nothing to do
				case TArgRest(dots, _, typeHint):
					#if (haxe_ver < 4.20)
					if (typeHint == null) {
						typeHint = {
							colon: new Token(0, TkColon, ":", [], []),
							type: TPath({first: new Token(0, TkIdent, "Array", [], []), rest: []})
						};
					}
					lastArg.kind = TArgNormal(typeHint, {
						equalsToken: new Token(0, TkEquals, "=", [whitespace], [whitespace]),
						expr: mkNullExpr(TTArray(TTAny))
					});
					var dotsTrivia = dots.leadTrivia.concat(dots.trailTrivia);
					lastArg.syntax.name.leadTrivia = dotsTrivia.concat(lastArg.syntax.name.leadTrivia);

					var argLocal = mk(TELocal(mkIdent(lastArg.name), lastArg.v), lastArg.type, lastArg.type);

					// TODO: indentation
					var eArrayInit = mk(TEIf({
						syntax: {
							keyword: addTrailingWhitespace(mkIdent("if")),
							openParen: mkOpenParen(),
							closeParen: addTrailingWhitespace(mkCloseParen())
						},
						econd: mk(TEBinop(
							argLocal,
							OpEquals(mkEqualsEqualsToken()),
							mkNullExpr()
						), TTBoolean, TTBoolean),
						ethen: mk(TEBinop(
							argLocal,
							OpAssign(new Token(0, TkEquals, "=", [whitespace], [whitespace])),
							mk(TEArrayDecl({
								syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
								elements: []
							}), tUntypedArray, tUntypedArray)
						), argLocal.type, argLocal.type),
						eelse: null
					}), TTVoid, TTVoid);

					if (fun.expr != null) { // null if interface
						fun.expr = concatExprs(eArrayInit, fun.expr);
					}
					#else
					if (fun.expr != null && lastArg.v != null) {
						var originalName = lastArg.name;
						var paramVar = lastArg.v;
						var newParamName = makeUniqueParamName(originalName, fun.sig.args);
						if (newParamName != originalName) {
							renameArg(lastArg, newParamName);
						}
						var arrayVar:TVar = {name: originalName, type: tUntypedArray};
						fun.expr = replaceLocalVar(fun.expr, paramVar, arrayVar);
						fun.expr = injectRestArrayDecl(fun.expr, arrayVar, originalName, paramVar);
					}
					#end
			}
		}
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		switch e.kind {
			case TELocalFunction(f):
				processFunction(f.fun);
				if (shouldWrapAnonymousRestClosure(f)) {
					normalizeRestArgForVarArgs(f.fun.sig.args[f.fun.sig.args.length - 1]);
					if (f.fun.sig.args.length > 1) {
						readFixedArgsFromArray(f.fun);
					}
					var lead = removeLeadingTrivia(e);
					var trail = removeTrailingTrivia(e);
						var eMakeVarArgs = mkBuiltin("Reflect.makeVarArgs", TTFunction, lead, []);
					return mk(TECall(eMakeVarArgs, {
						openParen: mkOpenParen(),
						args: [{expr: e, comma: null}],
						closeParen: mkCloseParen(trail)
					}), TTFunction, e.expectedType);
				}

			// Haxe < 4.20 needs explicit packing of rest args into an array.
			#if (haxe_ver < 4.20)
			case TENew(_, TNType({type: TTInst(cls)}), args) if (args != null && args.args.length > 0):
				switch getConstructor(cls) {
					case {type: TTFun(argTypes, _, TRestAs3)}:
						args.args = transformArgs(args.args, argTypes.length);

					case _:
				}
			#end

			// Haxe < 4.20: transform call sites to pass rest args as a single array.
			#if (haxe_ver < 4.20)
			case TECall(eobj = {type: TTFun(argTypes, _, TRestAs3)}, args) if (args.args.length > argTypes.length):
				if (!keepRestCall(eobj)) {
					args.args = transformArgs(args.args, argTypes.length);
				}
			#end

			case _:
		}

		return e;
	}

	static function shouldWrapAnonymousRestClosure(f:TLocalFunction):Bool {
		if (f.name != null || f.fun.sig.args.length == 0) {
			return false;
		}
		return switch f.fun.sig.args[f.fun.sig.args.length - 1].kind {
			case TArgRest(_):
				true;
			case _:
				false;
		}
	}

	/**
		Reflect.makeVarArgs passes all the arguments as one Array, so a closure with arguments before
		its rest takes that Array and reads them from it:
		`function(__args:Array<ASAny>) { var ch:String = __args[0]; var _rest = __args.slice(1); ... }`.
	**/
	static function readFixedArgsFromArray(fun:TFunction) {
		var args = fun.sig.args;
		// the declarations take the indentation of the body's first statement
		var indent = switch fun.expr.kind {
			case TEBlock(b) if (b.exprs.length > 0): extractIndent(processLeadingToken(t -> t.leadTrivia, b.exprs[0].expr));
			case _: [];
		}
		var argsVar:TVar = {name: makeUniqueParamName("_args", args), type: tUntypedArray};
		var decls:Array<TBlockExpr> = [];
		for (i in 0...args.length) {
			var arg = args[i];
			var argsLocal = mk(TELocal(mkIdent(argsVar.name), argsVar), argsVar.type, argsVar.type);
			var index = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, Std.string(i), [], []))), TTInt, TTInt);
			var typeHint:Null<TypeHint> = null;
			var defaultValue:Null<TExpr> = null;
			switch arg.kind {
				case TArgNormal(hint, init):
					typeHint = hint;
					if (init != null) defaultValue = init.expr;
				case TArgRest(_):
			}
			var value = if (i == args.length - 1) {
				var eSlice = mk(TEField({kind: TOExplicit(mkDot(), argsLocal), type: argsVar.type}, "slice", mkIdent("slice")), TTFun([TTInt], tUntypedArray), TTFun([TTInt], tUntypedArray));
				mkCall(eSlice, [index], tUntypedArray);
			} else {
				var access = mk(TEArrayAccess({syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()}, eobj: argsLocal, eindex: index}), TTAny, arg.type);
				if (defaultValue == null) {
					access;
				} else {
					// a missing optional argument takes its default value
					var lengthField = mk(TEField({kind: TOExplicit(mkDot(), argsLocal), type: argsVar.type}, "length", mkIdent("length")), TTInt, TTInt);
					var cond = mk(TEBinop(lengthField, OpGt(mkTokenWithSpaces(TkGt, ">")), index), TTBoolean, TTBoolean);
					mk(TETernary({syntax: {question: mkTokenWithSpaces(TkQuestion, "?"), colon: mkTokenWithSpaces(TkColon, ":")}, econd: cond, ethen: access, eelse: defaultValue}), arg.type, arg.type);
				}
			}
			var decl:TVarDecl = {
				syntax: {name: mkIdent(arg.name), type: typeHint},
				v: arg.v,
				init: {equalsToken: mkTokenWithSpaces(TkEquals, "="), expr: value.with(expectedType = arg.type)},
				comma: null
			};
			decls.push({expr: mk(TEVars(VVar(mkIdent("var", cloneTrivia(indent), [whitespace])), [decl]), TTVoid, TTVoid), semicolon: new Token(0, TkSemicolon, ";", [], [newline])});
		}
		fun.sig.args = [{
			syntax: {name: mkIdent(argsVar.name)},
			name: argsVar.name,
			type: argsVar.type,
			v: argsVar,
			kind: TArgNormal(ensureArrayTypeHint(null), null),
			comma: null
		}];
		fun.expr = switch fun.expr.kind {
			case TEBlock(b): fun.expr.with(kind = TEBlock({syntax: b.syntax, exprs: decls.concat(b.exprs)}));
			case _: concatExprs(mk(TEBlock({syntax: {openBrace: mkOpenBrace(), closeBrace: mkCloseBrace()}, exprs: decls}), TTVoid, TTVoid), fun.expr);
		}
	}

	static function normalizeRestArgForVarArgs(arg:TFunctionArg) {
		switch arg.kind {
			case TArgRest(dots, _, typeHint):
				typeHint = ensureArrayTypeHint(typeHint);
				arg.kind = TArgNormal(typeHint, null);
				var dotsTrivia = dots.leadTrivia.concat(dots.trailTrivia);
				arg.syntax.name.leadTrivia = dotsTrivia.concat(arg.syntax.name.leadTrivia);
			case _:
		}
	}

	static function ensureArrayTypeHint(typeHint:Null<TypeHint>):TypeHint {
		if (typeHint != null) {
			return typeHint;
		}
		return {
			colon: new Token(0, TkColon, ":", [], []),
			type: TPath({first: new Token(0, TkIdent, "Array", [], []), rest: []})
		};
	}

	static function renameArg(arg:TFunctionArg, newName:String) {
		arg.name = newName;
		if (arg.v != null) {
			arg.v.name = newName;
		}
		var newToken = mkIdent(newName);
		newToken.leadTrivia = arg.syntax.name.leadTrivia;
		newToken.trailTrivia = arg.syntax.name.trailTrivia;
		arg.syntax.name = newToken;
	}

	static function makeUniqueParamName(base:String, args:Array<TFunctionArg>):String {
		var used = new Map<String, Bool>();
		for (arg in args) {
			used.set(arg.name, true);
		}
		var name = "_" + base;
		while (used.exists(name)) {
			name = "_" + name;
		}
		return name;
	}

	static function replaceLocalVar(expr:TExpr, from:TVar, to:TVar):TExpr {
		var mapped = mapExpr(e -> replaceLocalVar(e, from, to), expr);
		return switch mapped.kind {
			case TELocal(token, v) if (v == from):
				var newToken = mkIdent(to.name);
				newToken.leadTrivia = token.leadTrivia;
				newToken.trailTrivia = token.trailTrivia;
				mapped.with(kind = TELocal(newToken, to), type = to.type);
			case _:
				mapped;
		}
	}

	static function injectRestArrayDecl(expr:TExpr, arrayVar:TVar, arrayName:String, paramVar:TVar):TExpr {
		return switch expr.kind {
			case TEBlock(block):
				var initExpr = buildRestArrayInit(paramVar);
				var lead =
					if (block.exprs.length > 0)
						removeLeadingTrivia(block.exprs[0].expr)
					else
						[newline, whitespace];
				if (block.exprs.length > 0) {
					var indent = extractIndent(lead);
					processLeadingToken(t -> t.leadTrivia = cloneTrivia(indent).concat(t.leadTrivia), block.exprs[0].expr);
				}
				var varToken = mkIdent("var", lead, [whitespace]);
				var decl:TVarDecl = {
					syntax: {name: mkIdent(arrayName), type: null},
					v: arrayVar,
					init: {
						equalsToken: mkTokenWithSpaces(TkEquals, "="),
						expr: initExpr
					},
					comma: null
				};
				var declExpr = mk(TEVars(VVar(varToken), [decl]), TTVoid, TTVoid);
				var newExprs = [{expr: declExpr, semicolon: addTrailingNewline(mkSemicolon())}].concat(block.exprs);
				expr.with(kind = TEBlock(block.with(exprs = newExprs)));
			case _:
				expr;
		}
	}

	static function buildRestArrayInit(paramVar:TVar):TExpr {
		var paramLocal = mk(TELocal(mkIdent(paramVar.name), paramVar), paramVar.type, paramVar.type);
		var eRestToArray = mkBuiltin("ASCompat.restToArray", TTFunction);
		return mk(TECall(eRestToArray, {
			openParen: mkOpenParen(),
			args: [{expr: paramLocal, comma: null}],
			closeParen: mkCloseParen()
		}), tUntypedArray, tUntypedArray);
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

	static function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}

	static function keepRestCall(callable:TExpr):Bool {
		return switch callable.kind {
			// TODO: this should be configurable, I guess
			case TEDeclRef(_, {kind: TDFunction({name: "printf", parentModule: {parentPack: {name: ""}}})}):
				true;
			case _:
				false;
		}
	}

	static function transformArgs(args:Array<{expr:TExpr, comma:Null<Token>}>, nonRest:Int) {
		var normalArgs = args.slice(0, nonRest);
		var restArgs = args.slice(nonRest);

		if (restArgs.length > 0) {
			var lead = removeLeadingTrivia(restArgs[0].expr);
			var trail = removeTrailingTrivia(restArgs[restArgs.length - 1].expr);

			normalArgs.push({
				expr: mk(TEArrayDecl({
					syntax: {
						openBracket: new Token(0, TkBracketOpen, "[", lead, []),
						closeBracket: new Token(0, TkBracketClose, "]", [], trail),
					},
					elements: restArgs
				}), tUntypedArray, tUntypedArray),
				comma: null
			});
		}

		return normalArgs;
	}
}
