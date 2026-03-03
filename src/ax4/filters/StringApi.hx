package ax4.filters;

class StringApi extends AbstractFilter {
	static final tCompareMethod = TTFun([TTAny, TTAny], TTInt);
	static final tReplaceMethod = TTFun([TTString, TTString], TTString);
	static final tSplitMethod = TTFun([TTString], TTArray(TTString));
	static final tMatchMethod = TTFun([TTString], TTArray(TTString));
	static final tSearchMethod = TTFun([TTString], TTInt);
	static final tStringToolsReplace = TTFun([TTString, TTString, TTString], TTString);
	static final tStdString = TTFun([TTAny], TTString);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall(eMethod = {kind: TEField(fieldObject = {kind: TOExplicit(dot, eString = {type: TTString})}, methodName = "substring" | "substr" | "slice", fieldToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				var renamed = methodName == "slice";
				if (renamed) {
					methodName = "substring";
					fieldToken = new Token(fieldToken.pos, TkIdent, methodName, fieldToken.leadTrivia, fieldToken.trailTrivia);
					eMethod = eMethod.with(kind = TEField(fieldObject, methodName, fieldToken));
				}
				if (args.args.length == 0) {
					var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
					args = args.with(args = [{expr: zeroExpr, comma: null}]);
				}
				e.with(kind = TECall(eMethod, args));

			case TECall({kind: TEField({kind: TOExplicit(dot, eString = {type: TTString})}, "replace", replaceToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}, eBy = {expr: {type: TTString | TTFunction | TTFun(_) | TTAny /*hmm*/}}]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eReplaceMethod = mk(TEField(obj, "replace", replaceToken), tReplaceMethod, tReplaceMethod);
						e.with(kind = TECall(eReplaceMethod, args.with(args = [
							{expr: eString, comma: ePattern.comma}, eBy
						])));

					case [ePattern = {expr: {type: TTString}}, eBy = {expr: {type: TTString | TTAny | TTObject(_) | TTInt | TTUint | TTNumber | TTBoolean}}]:
						var eStringToolsReplace = mkBuiltin("StringTools.replace", tStringToolsReplace, removeLeadingTrivia(eString));
						var eReplaceBy = coerceToString(eBy.expr);
						e.with(kind = TECall(eStringToolsReplace, args.with(args = [
							{expr: eString, comma: commaWithSpace}, ePattern, {expr: eReplaceBy, comma: eBy.comma}
						])));

					case _:
						throwError(exprPos(e), "Unsupported String.replace arguments");
				}

			case TECall({kind: TEField({kind: TOExplicit(dot, eString = {type: TTString})}, "match", fieldToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eMatchMethod = mk(TEField(obj, "match", fieldToken), tMatchMethod, tMatchMethod);
						e.with(kind = TECall(eMatchMethod, args.with(args = [{expr: eString, comma: null}])));

					case _:
						throwError(exprPos(e), "Unsupported String.match arguments");
				}

			case TECall({kind: TEField(fieldObject = {kind: TOExplicit(dot, eString = {type: TTString})}, "search", fieldToken)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}]:
						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eSearchMethod = mk(TEField(obj, "search", fieldToken), tSearchMethod, tSearchMethod);
						e.with(kind = TECall(eSearchMethod, args.with(args = [{expr: eString, comma: null}])));

					case [{expr: {type: TTString}}]:
						var fieldToken = new Token(fieldToken.pos, TkIdent, "indexOf", fieldToken.leadTrivia, fieldToken.trailTrivia);
						var eSearchMethod = mk(TEField(fieldObject, "indexOf", fieldToken), tSearchMethod, tSearchMethod);
						e.with(kind = TECall(eSearchMethod, args));

					case _:
						throwError(exprPos(e), "Unsupported String.search arguments");
				}

			case TECall({kind: TEField(fieldObject = {kind: TOExplicit(dot, eString = {type: TTString})}, "localeCompare", _)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [{expr: eOtherString = {type: TTString}}]:
						var eCompareMethod = mkBuiltin("Reflect.compare", tCompareMethod, removeLeadingTrivia(eString));
						e.with(kind = TECall(eCompareMethod, args.with(args = [
							{expr: eString, comma: commaWithSpace}, {expr: eOtherString, comma: null}
						])));

					case _:
						throwError(exprPos(e), "Unsupported String.localeCompare arguments");
				}

			case TECall({kind: TEField({kind: TOExplicit(_, eString = {type: TTString})}, "concat", _)}, args):
				eString = processExpr(eString);
				args = mapCallArgs(processExpr, args);
				var e = eString;
				for (arg in args.args) {
					e = mk(TEBinop(e, OpAdd(new Token(0, TkPlus, "+", [whitespace], [whitespace])), arg.expr.with(expectedType = TTString)), TTString, TTString);
				}
				e;

			case TECall(eMethod = {kind: TEField({kind: TOExplicit(dot, eString = {type: TTString})}, "split", fieldToken)}, args):
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case [ePattern = {expr: {type: TTRegExp}}]:
						eString = processExpr(eString);

						processLeadingToken(t -> t.leadTrivia = removeLeadingTrivia(eString).concat(t.leadTrivia), ePattern.expr);
						var obj:TFieldObject = {
							kind: TOExplicit(dot, ePattern.expr),
							type: TTRegExp
						}
						var eSplitMethod = mk(TEField(obj, "split", fieldToken), tSplitMethod, tSplitMethod);
						e.with(kind = TECall(eSplitMethod, args.with(args = [{expr: eString, comma: null}])));

					case [{expr: {type: TTString}}]:
						eMethod = eMethod.with(kind = TEField({kind: TOExplicit(dot, processExpr(eString)), type: TTString}, "split", fieldToken));
						e.with(kind = TECall(eMethod, args));

					case _:
						throwError(exprPos(e), "Unsupported String.split arguments");
				}

			case TEField(fobj = {type: TTString}, "slice", fieldToken):
				mapExpr(processExpr, e).with(kind = TEField(fobj, "substring", new Token(fieldToken.pos, TkIdent, "substring", fieldToken.leadTrivia, fieldToken.trailTrivia)));

			case TEField(fobj = {type: TTString}, "toLocaleLowerCase", fieldToken):
				mapExpr(processExpr, e).with(kind = TEField(fobj, "toLowerCase", new Token(fieldToken.pos, TkIdent, "toLowerCase", fieldToken.leadTrivia, fieldToken.trailTrivia)));

			case TEField(fobj = {type: TTString}, "toLocaleUpperCase", fieldToken):
				mapExpr(processExpr, e).with(kind = TEField(fobj, "toUpperCase", new Token(fieldToken.pos, TkIdent, "toUpperCase", fieldToken.leadTrivia, fieldToken.trailTrivia)));

			case TEField({type: TTString}, name = "replace" | "match" | "split" | "concat" | "search" | "localeCompare", _):
				throwError(exprPos(e), "closure on String." + name);

			case TECall({kind: TEField(fieldObject = {kind: TOExplicit(dot, eObject)}, methodName = "toUpperCase" | "toLowerCase" | "toLocaleUpperCase" | "toLocaleLowerCase" | "charAt" | "charCodeAt" | "substr" | "substring", fieldToken)}, args)
				if (isEffectivelyAny(eObject)):
				var eCoerced = coerceToString(processExpr(eObject));
				var newFieldObj:TFieldObject = {kind: TOExplicit(dot, eCoerced), type: TTString};
				var newMethod = mk(TEField(newFieldObj, methodName, fieldToken), TTFun([], TTString), TTFun([], TTString));
				processExpr(e.with(kind = TECall(newMethod, args)));

			case _:
				mapExpr(processExpr, e);
		}
	}

	function isEffectivelyAny(e:TExpr):Bool {
		if (e.type != TTAny) return false;

		function getBaseType(e:TExpr):TType {
			return switch e.kind {
				case TELocal(_, v): v.type;
				case TEField(fobj, _, _):
					switch fobj.kind {
						case TOExplicit(_, inner): getBaseType(inner);
						case TOImplicitThis(cls) | TOImplicitClass(cls): TTInst(cls);
					}
				case TEParens(_, inner, _): getBaseType(inner);
				case _: e.type;
			}
		}

		var baseType = getBaseType(e);
		return baseType.match(TTAny | TTObject(_));
	}

	function coerceToString(e:TExpr):TExpr {
		if (e.type == TTString) {
			return e.with(expectedType = TTString);
		}
		var eStdString = mkBuiltin("Std.string", tStdString, removeLeadingTrivia(e));
		return e.with(
			kind = TECall(eStdString, {
				openParen: mkOpenParen(),
				args: [{expr: e, comma: null}],
				closeParen: mkCloseParen(removeTrailingTrivia(e))
			}),
			type = TTString,
			expectedType = TTString
		);
	}
}
