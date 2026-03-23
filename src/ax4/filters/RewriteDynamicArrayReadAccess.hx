package ax4.filters;

class RewriteDynamicArrayReadAccess extends AbstractFilter {
	static final tDynGetIndex = TTFun([TTAny, TTAny], TTAny);

	override function processExpr(e:TExpr):TExpr {
		return rewriteExpr(e, false);
	}

	function rewriteExpr(e:TExpr, inWriteContext:Bool):TExpr {
		return switch e.kind {
			case TEBinop(a, op = OpAssign(_) | OpAssignOp(_), b):
				e.with(kind = TEBinop(rewriteExpr(a, true), op, rewriteExpr(b, false)));

			case TEPreUnop(op = PreIncr(_) | PreDecr(_), value):
				e.with(kind = TEPreUnop(op, rewriteExpr(value, true)));

			case TEPostUnop(value, op = PostIncr(_) | PostDecr(_)):
				e.with(kind = TEPostUnop(rewriteExpr(value, true), op));

			case TEArrayAccess(a):
				var eobj = rewriteExpr(a.eobj, inWriteContext);
				var eindex = rewriteExpr(a.eindex, false);
				if (!inWriteContext && a.eobj.kind.match(TEArrayAccess(_)) && shouldRewriteDynamicRead(eobj, eindex)) {
					rewriteDynamicRead(e, eobj, eindex);
				} else {
					e.with(kind = TEArrayAccess(a.with(eobj = eobj, eindex = eindex)));
				}

			case _:
				mapExpr(expr -> rewriteExpr(expr, false), e);
		}
	}

	static function shouldRewriteDynamicRead(eobj:TExpr, eindex:TExpr):Bool {
		var isDynamicObject = switch eobj.type {
			case TTAny | TTObject(TTAny) | TTBuiltin:
				true;
			case _:
				false;
		};
		if (!isDynamicObject) {
			return false;
		}
		return isProbablyNumericIndexExpr(eindex);
	}

	static function isProbablyNumericIndexExpr(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TELiteral(TLInt(_) | TLNumber(_)):
				true;

			case TEBinop(_, op, _):
				switch op {
					case OpAdd(_) | OpSub(_) | OpMul(_) | OpDiv(_) | OpMod(_) | OpBitAnd(_) | OpBitOr(_) | OpBitXor(_) | OpShl(_) | OpShr(_) | OpUshr(_):
						true;
					case _:
						false;
				}

			case TEPreUnop(PreNeg(_) | PreBitNeg(_) | PreIncr(_) | PreDecr(_), _):
				true;

			case TEPostUnop(_, PostIncr(_) | PostDecr(_)):
				true;

			case TECall({kind: TEBuiltin(_, name)}, _) if (name == "ASCompat.toInt" || name == "ASCompat.toNumber" || name == "Std.int"):
				true;

			case _:
				switch e.type {
					case TTInt | TTUint | TTNumber:
						true;
					case _:
						false;
				}
		}
	}

	function rewriteDynamicRead(original:TExpr, eobj:TExpr, eindex:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		var eDynGetIndex = mkBuiltin("ASCompat.dynGetIndex", tDynGetIndex, lead, []);
		return mkCall(eDynGetIndex, [eobj, eindex], TTAny, trail).with(expectedType = original.expectedType);
	}
}
