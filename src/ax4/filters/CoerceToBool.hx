package ax4.filters;
/**
	Replace non-boolean values that are used where boolean is expected with a coercion call.
	E.g. `if (object)` to `if (object != null)`
**/
class CoerceToBool extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		// Handle !array -> array == null
		switch e.kind {
			case TEPreUnop(PreNot(notToken), inner) if (isArrayLike(inner.type)):
				// Transform !array into array == null
				var trail = removeTrailingTrivia(inner);
				var equalsToken = mkTokenWithSpaces(TkEqualsEquals, "==");
				equalsToken.leadTrivia = notToken.leadTrivia.concat(notToken.trailTrivia).concat(equalsToken.leadTrivia);
				return mk(TEBinop(inner.with(expectedType = inner.type), OpEquals(equalsToken), mkNullExpr(inner.type, [], trail)), TTBoolean, TTBoolean);
			case _:
		}

		// Handle conditions in control structures - check if this expression is a condition
		e = processConditionExpr(e);

		if (e.expectedType == TTBoolean && e.type != TTBoolean) {
			// Don't coerce if this is already a null comparison
			if (isNullComparison(e)) {
				return e;
			}
			return coerce(e);
		} else {
			return e;
		}
	}

	/**
	 * Check if an expression is used as a condition in control structures
	 * and coerce it to bool if needed
	 */
	function processConditionExpr(e:TExpr):TExpr {
		return switch e.kind {
			// if (condition)
			case TEIf(i):
				var newCond = coerceIfReference(i.econd);
				if (newCond != i.econd) {
					i.econd = newCond;
				}
				e;

			// while (condition)
			case TEWhile(w):
				var newCond = coerceIfReference(w.cond);
				if (newCond != w.cond) {
					w.cond = newCond;
				}
				e;

			// do { ... } while (condition)
			case TEDoWhile(w):
				var newCond = coerceIfReference(w.cond);
				if (newCond != w.cond) {
					w.cond = newCond;
				}
				e;

			// for (...; condition; ...)
			case TEFor(f):
				if (f.econd != null) {
					var newCond = coerceIfReference(f.econd);
					if (newCond != f.econd) {
						f.econd = newCond;
					}
				}
				e;

			// switch (expression) - not a condition, but the switch value
			// We don't coerce the switch value, only cases

			case _:
				e;
		}
	}

	/**
	 * Coerce an expression to bool if it's a reference type
	 */
	function coerceIfReference(e:TExpr):TExpr {
		if (e.type != TTBoolean && isReferenceType(e.type)) {
			if (!isNullComparison(e)) {
				return coerce(e.with(expectedType = TTBoolean));
			}
		}
		return e;
	}

	/**
	 * Check if a type is a reference type that should be compared to null
	 */
	function isReferenceType(t:TType):Bool {
		return switch t {
			case TTFunction | TTFun(_) | TTClass | TTInst(_) | TTStatic(_) | TTArray(_) | TTVector(_) | TTRegExp | TTXML | TTXMLList | TTDictionary(_, _): true;
			case _: false;
		}
	}

	static function isNullComparison(e:TExpr):Bool {
		return switch e.kind {
			case TEBinop(_, OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_), {kind: TELiteral(TLNull(_))}):
				true;
			case TEBinop({kind: TELiteral(TLNull(_))}, OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_), _):
				true;
			case _:
				false;
		}
	}

	public function processNegation(e:TExpr):TExpr {
		// Handle !array (truthiness check) -> array == null
		if (isArrayLike(e.type)) {
			var trail = removeTrailingTrivia(e);
			return mk(TEBinop(e.with(expectedType = e.type), OpEquals(mkTokenWithSpaces(TkEqualsEquals, "==")), mkNullExpr(e.type, [], trail)), TTBoolean, TTBoolean);
		}
		return null;
	}

	static function isArrayLike(t:TType):Bool {
		return switch t {
			case TTArray(_) | TTVector(_): true;
			case _: false;
		}
	}

	static final tStringAsBool = TTFun([TTString], TTBoolean);
	static final tFloatAsBool = TTFun([TTNumber], TTBoolean);
	static final tIntAsBool = TTFun([TTInt], TTBoolean);
	static final tToBool = TTFun([TTAny], TTBoolean);

	public function coerce(e:TExpr):TExpr {
		switch e.kind {
			case TEBinop(a, op = OpAnd(_) | OpOr(_), b):
				// ensure both sides are coerced to bool when the overall expression is used as bool
				var a2 = if (a.type == TTBoolean) a else coerce(a.with(expectedType = TTBoolean));
				var b2 = if (b.type == TTBoolean) b else coerce(b.with(expectedType = TTBoolean));
				return e.with(kind = TEBinop(a2, op, b2), type = TTBoolean);
			case _:
		}

		return switch (e.type) {
			case TTBoolean:
				e; // shouldn't happen really

			case TTFunction | TTFun(_) | TTClass | TTInst(_) | TTStatic(_) | TTArray(_) | TTVector(_) | TTRegExp | TTXML | TTXMLList | TTDictionary(_, _):
				var trail = removeTrailingTrivia(e);
				mk(TEBinop(e.with(expectedType = e.type), OpNotEquals(mkNotEqualsToken()), mkNullExpr(e.type, [], trail)), TTBoolean, TTBoolean);

			case TTInt | TTUint:
				if (isNullable(e)) {
					var lead = removeLeadingTrivia(e);
					var tail = removeTrailingTrivia(e);
					var eIntAsBoolMethod = mkBuiltin("ASCompat.intAsBool", tIntAsBool, lead, []);
					mk(TECall(eIntAsBoolMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(tail),
						args: [{expr: e.with(expectedType = e.type), comma: null}],
					}), TTBoolean, TTBoolean);
				} else {
					var trail = removeTrailingTrivia(e);
					var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), e.type, e.type);
					mk(TEBinop(e.with(expectedType = e.type), OpNotEquals(mkNotEqualsToken()), zeroExpr), TTBoolean, TTBoolean);
				}

			// case TTString if (canBeRepeated(e)):
			// 	var trail = removeTrailingTrivia(e);
			// 	var nullExpr = mkNullExpr(TTString);
			// 	var emptyExpr = mk(TELiteral(TLString(new Token(0, TkStringDouble, '""', [], trail))), TTString, TTString);
			// 	var nullCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), nullExpr), TTBoolean, TTBoolean);
			// 	var emptyCheck = mk(TEBinop(e, OpNotEquals(mkNotEqualsToken()), emptyExpr), TTBoolean, TTBoolean);
			// 	mk(TEBinop(nullCheck, OpAnd(mkAndAndToken()), emptyCheck), TTBoolean, TTBoolean);

			case TTString:
				var lead = removeLeadingTrivia(e);
				var tail = removeTrailingTrivia(e);
				var eStringAsBoolMethod = mkBuiltin("ASCompat.stringAsBool", tStringAsBool, lead, []);
				mk(TECall(eStringAsBoolMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(tail),
					args: [{expr: e.with(expectedType = e.type), comma: null}],
				}), TTBoolean, TTBoolean);

			case TTNumber:
				var lead = removeLeadingTrivia(e);
				var tail = removeTrailingTrivia(e);
				var eFloatAsBoolMethod = mkBuiltin("ASCompat.floatAsBool", tFloatAsBool, lead, []);
				mk(TECall(eFloatAsBoolMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(tail),
					args: [{expr: e.with(expectedType = e.type), comma: null}],
				}), TTBoolean, TTBoolean);

			case TTAny | TTObject(_):
				var lead = removeLeadingTrivia(e);
				var tail = removeTrailingTrivia(e);
				var eToBoolMethod = mkBuiltin("ASCompat.toBool", tToBool, lead, []);
				mk(TECall(eToBoolMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(tail),
					args: [{expr: e.with(expectedType = e.type), comma: null}],
				}), TTBoolean, TTBoolean);

			case TTVoid:
				throwError(exprPos(e), "void used as Bool?");

			case TTBuiltin:
				throwError(exprPos(e), "TODO: bool coecion");
		}
	}

	static function isNullable(e:TExpr):Bool {
		// TODO: this should really be done properly using TTNull(t) instead of relying on specific expressions
		return switch skipParens(e).kind {
			case TEArrayAccess({eobj: {type: TTDictionary(_, _)}}): true;
			case _: false;
		}
	}
}
