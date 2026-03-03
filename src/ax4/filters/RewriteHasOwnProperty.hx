package ax4.filters;

class RewriteHasOwnProperty extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBinop(ekey, OpIn(_), edict = {type: TTDictionary(_)}):
				ekey = processExpr(ekey);
				edict = processExpr(edict);
				processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(ekey).concat(t.leadTrivia), edict);
				var eExistsMethod = mk(TEField({kind: TOExplicit(mkDot(), edict), type: edict.type}, "exists", mkIdent("exists")), TTFunction, TTFunction);
				e.with(kind = TECall(eExistsMethod, {
					openParen: mkOpenParen(),
					args: [{expr: ekey, comma: null}],
					closeParen: mkCloseParen(removeTrailingTrivia(edict))
				}));

			case TEBinop(ekey, OpIn(_), eobj):
				ekey = processExpr(ekey);
				eobj = processExpr(eobj);
				processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(ekey).concat(t.leadTrivia), eobj);
				var trail = removeTrailingTrivia(eobj);

				switch eobj.type {
					case TTObject(TTAny) | TTAny | TTXML | TTXMLList:
						mkHasOwnPropertyCall(e, eobj, ekey, trail);

					case TTObject(_):
						mkExistsCall(e, eobj, ekey, trail, TTString);

					case _:
						var eobjAny = if (eobj.type == TTAny) eobj else eobj.with(kind = TEHaxeRetype(eobj), type = TTAny);
						mkHasOwnPropertyCall(e, eobjAny, ekey, trail);
				}

			case TECall(eField = {kind: TEField(obj, "hasOwnProperty", fieldToken)}, args):
				switch obj.kind {
					case TOExplicit(dot, eobj):
						eobj = mapExpr(processExpr, eobj);
						args = mapCallArgs(processExpr, args);

						switch eobj.type {
							case TTDictionary(_, _):
								e.with(kind = TECall(
									eField.with(kind = TEField(
										obj.with(kind = TOExplicit(dot, eobj)),
										"exists",
										new Token(0, TkIdent, "exists", fieldToken.leadTrivia, fieldToken.trailTrivia)
									)),
									args
								));

							case TTObject(_) | TTAny | TTXML | TTXMLList:
								reportError(exprPos(e), "untyped hasOwnProperty detected");
								e.with(kind = TECall(
									eField.with(kind = TEField(obj.with(kind = TOExplicit(dot, eobj)), "hasOwnProperty", fieldToken)),
									args
								));

							case TTInst(_):
								reportError(exprPos(e), "hasOwnProperty on class instance detected");
								e.with(kind = TECall(
									eField.with(kind = TEField(
										obj.with(kind = TOExplicit(dot, eobj.with(kind = TEHaxeRetype(eobj), type = TTAny))),
										"hasOwnProperty",
										fieldToken
									)),
									args
								));

							case _:
								throwError(exprPos(e), "Unsupported hasOwnProperty call");
						}

					case TOImplicitThis(cls):
						reportError(exprPos(e), "hasOwnProperty on class instance detected");
						var eThis = mk(TELiteral(TLThis(mkIdent("this", fieldToken.leadTrivia, []))), obj.type, obj.type);
						fieldToken.leadTrivia = [];
						args = mapCallArgs(processExpr, args);
						e.with(kind = TECall(
							eField.with(kind = TEField(
								obj.with(kind = TOExplicit(mkDot(), eThis.with(kind = TEHaxeRetype(eThis), type = TTAny))),
								"hasOwnProperty",
								fieldToken
							)),
							args
						));

					case _:
						throwError(exprPos(e), "Unsupported hasOwnProperty call");
				}

			case TEField(_, "hasOwnProperty", _):
				throwError(exprPos(e), "closure on hasOwnProperty?");

			case _:
				mapExpr(processExpr, e);
		}
	}

	function mkExistsCall(e:TExpr, eobj:TExpr, ekey:TExpr, trail:Array<Trivia>, expectedKeyType:Null<TType>):TExpr {
		var keyArg = if (expectedKeyType == null) ekey else ekey.with(expectedType = expectedKeyType);
		var eExistsMethod = mk(TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, "exists", mkIdent("exists")), TTFunction, TTFunction);
		return e.with(kind = TECall(eExistsMethod, {
			openParen: mkOpenParen(),
			args: [{expr: keyArg, comma: null}],
			closeParen: mkCloseParen(trail)
		}));
	}

	function mkHasOwnPropertyCall(e:TExpr, eobj:TExpr, ekey:TExpr, trail:Array<Trivia>):TExpr {
		var keyArg = if (ekey.type == TTString) ekey else ekey.with(expectedType = TTString);
		var eHasOwnProperty = mk(TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, "hasOwnProperty", mkIdent("hasOwnProperty")), TTFunction, TTFunction);
		return e.with(kind = TECall(eHasOwnProperty, {
			openParen: mkOpenParen(),
			args: [{expr: keyArg, comma: null}],
			closeParen: mkCloseParen(trail)
		}));
	}
}
