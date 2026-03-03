package ax4.filters;

class RewriteArguments extends AbstractFilter {
	var argStack:Array<{args:Array<TFunctionArg>, argVar:Null<TVar>}> = [];

	override function processFunction(fun:TFunction) {
		argStack.push({args: fun.sig.args, argVar: null});
		if (fun.expr != null) {
			fun.expr = processExpr(fun.expr);
			var scope = argStack[argStack.length - 1];
			if (scope.argVar != null) {
				fun.expr = injectArgumentsDecl(fun.expr, scope.argVar, scope.args);
			}
		}
		argStack.pop();
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBuiltin(token, "arguments"):
				if (argStack.length == 0) {
					e;
				} else {
					var scope = argStack[argStack.length - 1];
					if (scope.argVar == null) {
						scope.argVar = {name: "arguments", type: tUntypedArray};
					}
					var nameToken = mkIdent("arguments");
					nameToken.leadTrivia = token.leadTrivia;
					nameToken.trailTrivia = token.trailTrivia;
					mk(TELocal(nameToken, scope.argVar), tUntypedArray, tUntypedArray);
				}
			case _:
				e;
		};
	}

	function injectArgumentsDecl(expr:TExpr, argVar:TVar, args:Array<TFunctionArg>):TExpr {
		return switch expr.kind {
			case TEBlock(block):
				var initExpr = buildArgumentsInit(args);
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
					syntax: {name: mkIdent("arguments"), type: null},
					v: argVar,
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

	function buildArgumentsInit(args:Array<TFunctionArg>):TExpr {
		var fixedArgs:Array<TExpr> = [];
		var restArg:Null<TExpr> = null;

		for (arg in args) {
			switch arg.kind {
				case TArgRest(_):
					restArg = mk(TELocal(mkIdent(arg.name), arg.v), TTArray(TTAny), TTArray(TTAny));
				case TArgNormal(_, _):
					fixedArgs.push(mk(TELocal(mkIdent(arg.name), arg.v), arg.type, arg.type));
			}
		}

		var elements = [for (i in 0...fixedArgs.length) {
			expr: fixedArgs[i],
			comma: if (i == fixedArgs.length - 1) null else commaWithSpace
		}];

		var arrayExpr = mk(TEArrayDecl({
			syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
			elements: elements
		}), tUntypedArray, tUntypedArray);

		if (restArg == null) {
			return arrayExpr;
		}

		var concatMethod = mk(TEField({kind: TOExplicit(mkDot(), arrayExpr), type: arrayExpr.type}, "concat", mkIdent("concat")), TTFunction, TTFunction);
		return mk(TECall(concatMethod, {
			openParen: mkOpenParen(),
			args: [{expr: restArg, comma: null}],
			closeParen: mkCloseParen()
		}), tUntypedArray, tUntypedArray);
	}

	function extractIndent(trivia:Array<Trivia>):Array<Trivia> {
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

	function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}
}
