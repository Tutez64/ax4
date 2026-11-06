package ax4.filters;

/**
	`undefined` as the value of an untyped (`*`) return, variable or assignment becomes
	`ASCompat.UNDEFINED`, AS3's undefined outside flash and JS, where it was null: code that tells
	undefined from null, such as `typeof x == "undefined"`, took a missing value for a present one.

	Comparisons with undefined keep null, which an untyped comparison already treats as undefined,
	and so do default arguments, which must be constants, and typed places, where AS3 turns
	undefined into null, 0, NaN or false.
**/
class RewriteUndefinedValues extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEReturn(keyword, value) if (value != null && isUntypedUndefined(value)):
				e.with(kind = TEReturn(keyword, mkUndefined(value)));

			case TEVars(_, vars):
				for (decl in vars) {
					if (decl.init != null && decl.v.type == TTAny && isUndefinedLiteral(decl.init.expr)) {
						decl.init.expr = mkUndefined(decl.init.expr);
					}
				}
				e;

			case TEBinop(a, op = OpAssign(_), b) if (a.type == TTAny && isUndefinedLiteral(b)):
				e.with(kind = TEBinop(a, op, mkUndefined(b)));

			case _:
				e;
		}
	}

	static function isUntypedUndefined(e:TExpr):Bool {
		return e.expectedType == TTAny && isUndefinedLiteral(e);
	}

	static function isUndefinedLiteral(e:TExpr):Bool {
		return switch e.kind {
			case TELiteral(TLUndefined(_)): true;
			case _: false;
		}
	}

	static function mkUndefined(literal:TExpr):TExpr {
		var token = switch literal.kind {
			case TELiteral(TLUndefined(t)): t;
			case _: throw "assert";
		}
		var name = "ASCompat.UNDEFINED";
		return mk(TEBuiltin(new Token(token.pos, TkIdent, name, token.leadTrivia, token.trailTrivia), name), TTAny, literal.expectedType);
	}
}
