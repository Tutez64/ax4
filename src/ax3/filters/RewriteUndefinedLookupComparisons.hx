package ax3.filters;

private typedef LookupTarget = {
	var eobj:TExpr;
	var eindex:TExpr;
	var useDictionaryExists:Bool;
}

class RewriteUndefinedLookupComparisons extends AbstractFilter {
	static final tHasProperty = TTFun([TTAny, TTAny], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		return switch skipParens(e).kind {
			case TEBinop(a, op = OpEquals(_) | OpStrictEquals(_) | OpNotEquals(_) | OpNotStrictEquals(_), b):
				rewriteUndefinedCompare(e, a, op, b);

			case _:
				e;
		}
	}

	function rewriteUndefinedCompare(original:TExpr, a:TExpr, op:Binop, b:TExpr):TExpr {
		final target = if (isUndefinedLiteral(a)) getLookupTarget(b) else if (isUndefinedLiteral(b)) getLookupTarget(a) else null;
		if (target == null) return original;

		final lead = removeLeadingTrivia(original);
		final trail = removeTrailingTrivia(original);
		final negate = switch op {
			case OpEquals(_) | OpStrictEquals(_): true;
			case OpNotEquals(_) | OpNotStrictEquals(_): false;
			case _: false;
		}

		var existsCheck = if (target.useDictionaryExists) {
			mkDictionaryExists(target.eobj, target.eindex, negate ? [] : lead);
		} else {
			mkHasPropertyCall(target.eobj, target.eindex, negate ? [] : lead);
		}

		var rewritten = if (negate) {
			mkNot(existsCheck, lead);
		} else {
			existsCheck;
		}

		processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), rewritten);
		return rewritten;
	}

	function mkDictionaryExists(eobj:TExpr, eindex:TExpr, lead:Array<Trivia>):TExpr {
		final eExistsMethod = mk(
			TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, "exists", mkIdent("exists", lead, [])),
			TTFunction,
			TTFunction
		);
		return mk(TECall(eExistsMethod, {
			openParen: mkOpenParen(),
			args: [{expr: eindex, comma: null}],
			closeParen: mkCloseParen()
		}), TTBoolean, TTBoolean);
	}

	function mkHasPropertyCall(eobj:TExpr, eindex:TExpr, lead:Array<Trivia>):TExpr {
		final eHasProperty = mkBuiltin("ASCompat.hasProperty", tHasProperty, lead, []);
		return mkCall(eHasProperty, [eobj, eindex], TTBoolean);
	}

	function mkNot(e:TExpr, lead:Array<Trivia>):TExpr {
		final notToken = new Token(0, TkExclamation, "!", lead, []);
		return mk(TEPreUnop(PreNot(notToken), e), TTBoolean, TTBoolean);
	}

	static function isUndefinedLiteral(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TELiteral(TLUndefined(_)): true;
			case _: false;
		}
	}

	static function getLookupTarget(e:TExpr):Null<LookupTarget> {
		return switch skipParens(e).kind {
			case TEArrayAccess(a):
				switch a.eobj.type {
					case TTDictionary(_, _):
						{eobj: a.eobj, eindex: a.eindex, useDictionaryExists: true};

					case TTObject(_):
						{eobj: a.eobj, eindex: a.eindex, useDictionaryExists: false};

					case TTInst(cls) if (cls.name == "ASObject" && cls.parentModule.parentPack.name == ""):
						{eobj: a.eobj, eindex: a.eindex, useDictionaryExists: false};

					case _:
						null;
				}

			case _:
				null;
		}
	}
}
