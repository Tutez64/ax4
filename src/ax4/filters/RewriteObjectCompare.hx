package ax4.filters;

import ax4.ParseTree.Binop;

class RewriteObjectCompare extends AbstractFilter {
	static final tCompare = TTFun([TTAny, TTAny], TTInt);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, op = OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_), b):
				if (shouldRewrite(a.type, b.type)) {
					rewriteCompare(a, op, b, e);
				} else {
					e;
				}
			case _:
				e;
		}
	}

	static function shouldRewrite(a:TType, b:TType):Bool {
		if (isNumeric(a) || isNumeric(b)) return false;
		if (a == TTString || b == TTString) return false;
		if (isAnyLike(a) || isAnyLike(b)) return false;
		return true;
	}

	function rewriteCompare(a:TExpr, op:Binop, b:TExpr, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);

		var eCompare = mkBuiltin("Reflect.compare", tCompare, lead);
		var call = mkCall(eCompare, [a, b], TTInt);
		var zero = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
		var expr = mk(TEBinop(call, cloneBinop(op), zero), TTBoolean, TTBoolean);

		processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), expr);
		return expr;
	}

	static function cloneBinop(op:Binop):Binop {
		return switch op {
			case OpGt(t): OpGt(t.clone());
			case OpGte(t): OpGte(t.clone());
			case OpLt(t): OpLt(t.clone());
			case OpLte(t): OpLte(t.clone());
			case _: op;
		}
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}

	static inline function isNumeric(t:TType):Bool {
		return t.match(TTInt | TTUint | TTNumber);
	}
}
