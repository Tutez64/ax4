package ax4.filters;

class NumberApi extends AbstractFilter {
	static final tToFunc = TTFun([TTNumber], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eNumber = {type: TTNumber})}, methodName = "toExponential" | "toFixed" | "toPrecision", _)}, args):
				var args = switch [methodName, args.args] {
					case ["toExponential" | "toFixed", []]:
						args.with(args = [{expr: eNumber, comma: null}]);
					case [_, [digitsArg]]:
						args.with(args = [{expr: eNumber, comma: commaWithSpace}, digitsArg]);
					case _:
						throwError(exprPos(e), "Unsupported number of arguments for Number." + methodName);
				};
				var eMethod = mkBuiltin("ASCompat." + methodName, tToFunc, removeLeadingTrivia(eNumber));
				e.with(kind = TECall(eMethod, args));

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTAny | TTObject(_)})}, methodName = "toExponential" | "toFixed" | "toPrecision", _)}, args):
				// an untyped value may be a Number, which has no methods outside flash and JS
				var nameToken = new Token(0, TkStringDouble, haxe.Json.stringify(methodName), [], []);
				var eName = mk(TELiteral(TLString(nameToken)), TTString, TTString);
				var callArgs = [{expr: eValue, comma: commaWithSpace}, {expr: eName, comma: null}];
				for (arg in args.args) {
					callArgs[callArgs.length - 1].comma = commaWithSpace;
					callArgs.push({expr: arg.expr, comma: null});
				}
				var eMethod = mkBuiltin("ASCompat.callNumberMethod", TTFunction, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eMethod, args.with(args = callArgs)), type = TTString);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "int")})}, "MAX_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MAX_INT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "int")})}, "MIN_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MIN_INT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "Number")})}, "MAX_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MAX_FLOAT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "Number")})}, "MIN_VALUE", fieldToken):
				return mkBuiltin("ASCompat.MIN_FLOAT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "Number")})}, "POSITIVE_INFINITY", fieldToken):
				return mkBuiltin("ASCompat.MAX_FLOAT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case TEField({kind: TOExplicit(_, {kind: TEBuiltin(builtinToken, "Number")})}, "NEGATIVE_INFINITY", fieldToken):
				return mkBuiltin("ASCompat.MIN_FLOAT", TTInt, builtinToken.leadTrivia, fieldToken.trailTrivia);

			case _:
				e;
		};
	}
}