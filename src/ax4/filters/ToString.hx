package ax4.filters;

class ToString extends AbstractFilter {
	public static final tToString = TTFun([], TTString);
	static final tStdString = TTFun([TTAny], TTString);
	static final tToRadix = TTFun([TTNumber], TTString);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, op = OpAdd(_), b):
				rewriteStringConcatBinop(e, a, op, b);

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: t})}, "toString", _)}, args = {args: []}) if (shouldRewriteInstToString(t)):
				var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eStdString, args.with(args = [{expr: eValue, comma: null}])));

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint | TTNumber | TTBoolean | TTAny | TTObject(_)})}, "toString", _)}, args = {args: []}):
				var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eStdString, args.with(args = [{expr: eValue, comma: null}])));

			case TECall({kind: TEField({kind: TOExplicit(_, eValue = {type: TTInt | TTUint | TTNumber})}, "toString", _)}, args = {args: [digitsArg] }):
				var eToRadix = mkBuiltin("ASCompat.toRadix", tToRadix, removeLeadingTrivia(eValue));
				e.with(kind = TECall(eToRadix, args.with(args = [{expr: eValue, comma: commaWithSpace}, digitsArg])));

			case _:
				// implicit to string coercions
				switch [e.type, e.expectedType] {
					case [TTString, TTString]:
						e; // ok

					case [TTAny | TTObject(_), TTString]:
						e; // handled at run-time

					case [TTInt | TTUint | TTNumber | TTBoolean, TTString]:
						var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(e));
						e.with(
							kind = TECall(eStdString, {
								openParen: mkOpenParen(),
								args: [{expr: e, comma: null}],
								closeParen: mkCloseParen(removeTrailingTrivia(e))
							}),
							type = TTString
						);

					case [TTXML | TTXMLList, TTString]:
						var eToString = mk(TEField({kind: TOExplicit(mkDot(), e), type: e.type}, "toString", mkIdent("toString")), tToString, tToString);
						mkCall(eToString, [], TTString, removeTrailingTrivia(e));

					// these are not really about "ToString", but I haven't found a better place to add them without introducing yet another filter
					// normally this can't happen in AS3, unless you do `for (var i:int in someObject)` then it can ¯\_(ツ)_/¯
					case [TTString, TTInt | TTUint]: mkCastCall("toInt", e, TTInt);
					case [TTString, TTNumber]: mkCastCall("toNumber", e, TTNumber);

					case [_, TTString]:
						reportError(exprPos(e), "Unknown to string coercion (actual type is " + e.type + ")");
						e;

					case _:
						e;
				}
		}
	}

	function rewriteStringConcatBinop(e:TExpr, a:TExpr, op:Binop, b:TExpr):TExpr {
		if (!isStringLike(a.type) && !isStringLike(b.type)) {
			return e;
		}

		var a2 = if (isStringLike(b.type) && shouldStringifyInConcat(a.type)) mkStdString(a) else a;
		var b2 = if (isStringLike(a.type) && shouldStringifyInConcat(b.type)) mkStdString(b) else b;

		if (a2 == a && b2 == b) {
			return e;
		}
		return e.with(kind = TEBinop(a2, op, b2));
	}

	static inline function isStringLike(t:TType):Bool {
		return t.match(TTString | TTXML | TTXMLList);
	}

	static inline function shouldStringifyInConcat(t:TType):Bool {
		return t.match(TTAny | TTObject(_) | TTBuiltin);
	}

	static function mkStdString(e:TExpr):TExpr {
		var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(e));
		return e.with(
			kind = TECall(eStdString, {
				openParen: mkOpenParen(),
				args: [{expr: e, comma: null}],
				closeParen: mkCloseParen(removeTrailingTrivia(e))
			}),
			type = TTString
		);
	}

	static function shouldRewriteInstToString(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				cls.findFieldInHierarchy("toString", false) == null;
			case _:
				false;
		}
	}

	static function mkCastCall(methodName:String, e:TExpr, t:TType):TExpr {
		var eCastMethod = mkBuiltin("ASCompat." + methodName, TTFunction, removeLeadingTrivia(e));
		return e.with(
			kind = TECall(eCastMethod, {
				openParen: mkOpenParen(),
				args: [{expr: e, comma: null}],
				closeParen: mkCloseParen(removeTrailingTrivia(e))
			}),
			type = t
		);
	}
}
