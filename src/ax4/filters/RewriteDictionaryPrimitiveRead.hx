package ax4.filters;

/**
	Reads a Dictionary whose key is statically a String, int or uint through `ASDictionary.getString`
	or `ASDictionary.getInt`, which on C++ neither box the key nor test its type at runtime.
	Writes, `delete` and increments keep the array access.
**/
class RewriteDictionaryPrimitiveRead extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBinop(a, op = OpAssign(_) | OpAssignOp(_), b):
				e.with(kind = TEBinop(processTarget(a), op, processExpr(b)));
			case TEPreUnop(op = PreIncr(_) | PreDecr(_), a):
				e.with(kind = TEPreUnop(op, processTarget(a)));
			case TEPostUnop(a, op):
				e.with(kind = TEPostUnop(processTarget(a), op));
			case TEDelete(keyword, a):
				e.with(kind = TEDelete(keyword, processTarget(a)));
			case TEArrayAccess(a):
				var eobj = processExpr(a.eobj);
				var eindex = processExpr(a.eindex);
				var method = switch [eobj.type, eindex.type] {
					case [TTDictionary(_), TTString]: "ASDictionary.getString";
					case [TTDictionary(_), TTInt | TTUint]: "ASDictionary.getInt";
					case _: null;
				}
				if (method == null) {
					e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));
				} else {
					var lead = removeLeadingTrivia(e);
					var trail = removeTrailingTrivia(e);
					e.with(kind = TECall(mkBuiltin(method, TTFunction, lead, []), {
						openParen: mkOpenParen(),
						args: [
							{expr: eobj.with(expectedType = eobj.type), comma: commaWithSpace},
							{expr: eindex.with(expectedType = eindex.type), comma: null}
						],
						closeParen: mkCloseParen(trail)
					}));
				}
			case _:
				mapExpr(processExpr, e);
		}
	}

	/** The target of a write: stays an array access, only its parts are read. **/
	function processTarget(e:TExpr):TExpr {
		return switch e.kind {
			case TEArrayAccess(a):
				e.with(kind = TEArrayAccess(a.with(eobj = processExpr(a.eobj), eindex = processExpr(a.eindex))));
			case TEParens(openParen, inner, closeParen):
				e.with(kind = TEParens(openParen, processTarget(inner), closeParen));
			case _:
				processExpr(e);
		}
	}
}
