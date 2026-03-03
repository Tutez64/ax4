package ax4.filters;

class FunctionApply extends AbstractFilter {
	static final tcallMethod = TTFun([TTAny, TTFunction, TTArray(TTAny)], TTAny);
	static final tApplyBoundMethod = TTFun([TTAny, TTString, TTArray(TTAny)], TTAny);
	static final eEmptyArray = mk(TEArrayDecl({syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()}, elements: []}), tUntypedArray, tUntypedArray);

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, eFun = {type: TTFunction | TTFun(_) | TTAny | TTObject(TTAny)})}, "apply", _)}, args):
				eFun = processExpr(eFun);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case []: // no args call, that happens :-/
						e.with(kind = TECall(eFun, args));
					case [thisArg]:
						if (isNullLikeThisArg(thisArg.expr)) {
							e.with(kind = TECall(eFun, args.with(args = [])));
						} else {
							var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
							thisArg = resolveThisArgForMethodClosure(thisArg, eFun);
							if (thisArg.comma == null) thisArg.comma = commaWithSpace;
							e.with(kind = TECall(eCallMethod, args.with(args = [
								thisArg, {expr: eFun, comma: commaWithSpace}, {expr: eEmptyArray, comma: null}
							])));
						}
					case [thisArg, eArgs]:
						if (isNullLikeThisArg(thisArg.expr)) {
							switch extractBoundMethod(eFun) {
								case {obj: eobj, name: methodName, token: methodToken} if (canUseTypedBoundApply(eobj)):
									var eApplyBoundMethod = mkBuiltin("ASCompatMacro.applyBoundMethod", tApplyBoundMethod, removeLeadingTrivia(eFun));
									var eMethodName = mk(
										TELiteral(TLString(new Token(methodToken.pos, TkStringDouble, haxe.Json.stringify(methodName), methodToken.leadTrivia, []))),
										TTString,
										TTString
									);
									methodToken.leadTrivia = [];
									e.with(kind = TECall(eApplyBoundMethod, args.with(args = [
										{expr: eobj, comma: commaWithSpace},
										{expr: eMethodName, comma: commaWithSpace},
										eArgs
									])));
								case _:
									var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
									thisArg = resolveThisArgForMethodClosure(thisArg, eFun);
									e.with(kind = TECall(eCallMethod, args.with(args = [
										thisArg, {expr: eFun, comma: commaWithSpace}, eArgs
									])));
							}
						} else {
							var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
							thisArg = resolveThisArgForMethodClosure(thisArg, eFun);
							e.with(kind = TECall(eCallMethod, args.with(args = [
								thisArg, {expr: eFun, comma: commaWithSpace}, eArgs
							])));
						}
					case _:
						throwError(exprPos(e), "Invalid Function.apply");
				}

			case TECall({kind: TEField({kind: TOExplicit(_, eFun = {type: TTFunction | TTFun(_) | TTAny | TTObject(TTAny)})}, "call", _)}, args):
				eFun = processExpr(eFun);
				args = mapCallArgs(processExpr, args);
				switch args.args {
					case []: // no args call, that happens :-/
						e.with(kind = TECall(eFun, args));
					case _[0] => {expr: {kind: TELiteral(TLNull(_))}}: // call with `null` first arg should be the same as simply calling the function
						e.with(kind = TECall(eFun, args.with(args = args.args.slice(1))));
					case _:
						var eArgs = mk(TEArrayDecl({
							syntax: {
								openBracket: mkOpenBracket(),
								closeBracket: mkCloseBracket()
							},
							elements: args.args.slice(1)
						}), tUntypedArray, tUntypedArray);
						var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
						var thisArg = args.args[0];
						if (thisArg.comma == null) thisArg.comma = commaWithSpace;
						e.with(kind = TECall(eCallMethod, args.with(args = [
							thisArg, {expr: eFun, comma: commaWithSpace}, {expr: eArgs, comma: null}
						])));
				}

			case TEField({type: TTFunction | TTFun(_) | TTAny | TTObject(TTAny)}, name = "apply" | "call", _):
				throwError(exprPos(e), "closure on Function." + name);

			case _:
				mapExpr(processExpr, e);
		}
	}

	static inline function canUseTypedBoundApply(eobj:TExpr):Bool {
		return switch eobj.type {
			case TTAny | TTObject(_) | TTBuiltin:
				false;
			case _:
				true;
		}
	}

	static function extractBoundMethod(eFun:TExpr):Null<{obj:TExpr, name:String, token:Token}> {
		return switch eFun.kind {
			case TEField({kind: TOExplicit(_, eobj)}, name, token):
				{obj: eobj, name: name, token: token};
			case TEParens(_, inner, _) | TEHaxeRetype(inner):
				extractBoundMethod(inner);
			case _:
				null;
		}
	}

	static inline function resolveThisArgForMethodClosure(arg:{expr:TExpr, comma:Null<Token>}, eFun:TExpr):{expr:TExpr, comma:Null<Token>} {
		if (!isNullLikeThisArg(arg.expr)) {
			return arg;
		}
		var boundObj = boundObjectForMethodClosure(eFun);
		return if (boundObj == null) arg else {expr: boundObj, comma: arg.comma};
	}

	static function isNullLikeThisArg(e:TExpr):Bool {
		return switch e.kind {
			case TELiteral(TLNull(_) | TLUndefined(_)):
				true;
			case TEParens(_, inner, _):
				isNullLikeThisArg(inner);
			case TEHaxeRetype(inner):
				isNullLikeThisArg(inner);
			case _:
				false;
		}
	}

	static function boundObjectForMethodClosure(eFun:TExpr):Null<TExpr> {
		return switch eFun.kind {
			case TEField(obj, _, fieldToken):
				switch obj.kind {
					case TOExplicit(_, eobj):
						eobj;
					case TOImplicitThis(cls):
						mk(TELiteral(TLThis(mkIdent("this", fieldToken.leadTrivia, []))), TTInst(cls), TTInst(cls));
					case TOImplicitClass(_):
						null;
				}
			case _:
				switch eFun.kind {
					case TEParens(_, inner, _) | TEHaxeRetype(inner):
						boundObjectForMethodClosure(inner);
					case _:
						null;
				}
		}
	}
}
