package ax4.filters;

class NumberToInt extends AbstractFilter {
	public static final tStdInt = TTFun([TTNumber], TTInt);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch [e.type, e.expectedType] {
			case [TTNumber, TTInt]:
				var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
				mkCall(stdInt, [e.with(expectedType = TTNumber)], TTInt, removeTrailingTrivia(e));

			case [TTNumber, TTUint]:
				var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
				var call = mkCall(stdInt, [e.with(expectedType = TTNumber)], TTInt, removeTrailingTrivia(e));
				mk(TEHaxeRetype(call), TTUint, TTUint);
			case _:
				e;
		}
	}
}
