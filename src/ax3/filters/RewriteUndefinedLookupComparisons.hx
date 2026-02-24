package ax3.filters;

private typedef LookupTarget = {
	var eobj:TExpr;
	var eindex:TExpr;
	var useDictionaryExists:Bool;
}

private typedef MapItemForTarget = {
	var emap:TExpr;
	var ekey:TExpr;
}

class RewriteUndefinedLookupComparisons extends AbstractFilter {
	static final tHasProperty = TTFun([TTAny, TTAny], TTBoolean);
	static final tLookupNullCompare = TTFun([TTAny, TTAny], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		return switch skipParens(e).kind {
			case TEBinop(a, op = OpEquals(_) | OpStrictEquals(_) | OpNotEquals(_) | OpNotStrictEquals(_), b):
				rewriteLookupComparisons(e, a, op, b);

			case _:
				e;
		}
	}

	function rewriteLookupComparisons(original:TExpr, a:TExpr, op:Binop, b:TExpr):TExpr {
		final target = if (isUndefinedLiteral(a)) getLookupTarget(b) else if (isUndefinedLiteral(b)) getLookupTarget(a) else null;
		if (target != null) {
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

		final nullTargetExpr = if (isNullLiteral(a)) b else if (isNullLiteral(b)) a else null;
		if (nullTargetExpr == null) {
			return original;
		}
		final nullIsNonStrict = switch op {
			case OpEquals(_) | OpNotEquals(_): true;
			case _: false;
		}
		if (!nullIsNonStrict) {
			return original;
		}
		final nullLookupTarget = getLookupTarget(nullTargetExpr);
		if (nullLookupTarget != null && nullLookupTarget.useDictionaryExists) {
			return rewriteNullComparison(
				original,
				op,
				"ASCompat.dictionaryLookupEqNull",
				"ASCompat.dictionaryLookupNeNull",
				nullLookupTarget.eobj,
				nullLookupTarget.eindex
			);
		}
		final mapItemForTarget = getMapItemForTarget(nullTargetExpr);
		if (mapItemForTarget != null) {
			return rewriteNullComparison(
				original,
				op,
				"ASCompat.mapItemForEqNull",
				"ASCompat.mapItemForNeNull",
				mapItemForTarget.emap,
				mapItemForTarget.ekey
			);
		}
		return original;
	}

	function rewriteNullComparison(original:TExpr, op:Binop, eqMethod:String, neMethod:String, eobj:TExpr, ekey:TExpr):TExpr {
		final methodName = switch op {
			case OpEquals(_): eqMethod;
			case OpNotEquals(_): neMethod;
			case _: null;
		}
		if (methodName == null) {
			return original;
		}
		final lead = removeLeadingTrivia(original);
		final trail = removeTrailingTrivia(original);
		final callLead = switch op {
			case OpEquals(_): lead;
			case _: [];
		}
		final eMethod = mkBuiltin(methodName, tLookupNullCompare, callLead, []);
		final rewritten = mkCall(eMethod, [eobj, ekey], TTBoolean);
		processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), rewritten);
		return rewritten;
	}

	static function isNullLiteral(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TELiteral(TLNull(_)): true;
			case _: false;
		}
	}

	static function getMapItemForTarget(e:TExpr):Null<MapItemForTarget> {
		return switch skipParens(e).kind {
			case TECall(eMethod, call) if (call.args.length == 1):
				switch skipParens(eMethod).kind {
					case TEField({kind: TOExplicit(_, eobj)}, "itemFor", _) if (isAs3CommonsMapType(eobj.type)):
						{emap: eobj, ekey: call.args[0].expr};
					case _:
						null;
				}
			case _:
				null;
		}
	}

	static function isAs3CommonsMapType(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				var pack = cls.parentModule.parentPack.name;
				(pack == "org.as3commons.collections" && (cls.name == "Map" || cls.name == "SortedMap"))
				|| (pack == "org.as3commons.collections.framework" && (cls.name == "IMap" || cls.name == "ISortedMap"));
			case _:
				false;
		}
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
