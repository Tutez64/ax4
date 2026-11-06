package ax4.filters;

/**
	AS3's `||` and `&&` give one of their operands, Haxe's take Bools: `a || b` becomes
	`if (a) a else b` and `a && b` becomes `if (a) b else a` when `a` can be read twice, else
	`ASCompat.orValue(a, b)` and `ASCompat.andValue(a, b)`, which read `a` once and `b` only when it
	is the result, as AS3 does.
**/
class RewriteNonBoolOr extends AbstractFilter {
	final coerceToBool:CoerceToBool;

	public function new(context, coerceToBool) {
		super(context);
		this.coerceToBool = coerceToBool;
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, op = OpOr(_) | OpAnd(_), b) if (a.type != TTBoolean || b.type != TTBoolean):
				var isOr = op.match(OpOr(_));
				if (canBeRepeated(a)) {
					var lead = removeLeadingTrivia(a);
					var trail = removeTrailingTrivia(a);
					var eRead = a;
					mk(TEIf({
						syntax: {
							keyword: mkIdent("if", lead, [whitespace]),
							openParen: mkOpenParen(),
							closeParen: mkCloseParen(trail)
						},
						econd: coerceToBool.coerce(a),
						ethen: if (isOr) eRead else b,
						eelse: {
							keyword: mkIdent("else", [whitespace], [whitespace]),
							expr: if (isOr) b else eRead,
							semiliconBefore: false
						}
					}), e.type, e.expectedType);
				} else {
					var lead = removeLeadingTrivia(a);
					var tail = removeTrailingTrivia(b);

					var eChooseMethod = mkBuiltin(if (isOr) "ASCompat.orValue" else "ASCompat.andValue", TTFunction, lead, []);

					mk(TECall(eChooseMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(tail),
						args: [
							{expr: a, comma: commaWithSpace},
							{expr: b, comma: null}
						],
					}), e.type, e.expectedType);
				}

			case _:
				e;
		}
	}
}
