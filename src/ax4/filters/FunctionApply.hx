package ax4.filters;

class FunctionApply extends AbstractFilter {
	static final tcallMethod = TTFun([TTAny, TTFunction, TTArray(TTAny)], TTAny);
	static final tApplyClosure = TTFun([TTAny, TTArray(TTAny)], TTAny);
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
							if (thisArg.comma == null) thisArg.comma = commaWithSpace;
							e.with(kind = TECall(eCallMethod, args.with(args = [
								thisArg, {expr: eFun, comma: commaWithSpace}, {expr: eEmptyArray, comma: null}
							])));
						}
					case [thisArg, eArgs]:
						if (isNullLikeThisArg(thisArg.expr)) {
							switch extractTypedBoundMethod(eFun) {
								case {obj: eobj, name: methodName, token: methodToken}:
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
									var eApplyClosure = mkBuiltin("ASCompatMacro.applyClosure", tApplyClosure, removeLeadingTrivia(eFun));
									e.with(kind = TECall(eApplyClosure, args.with(args = [
										{expr: eFun, comma: commaWithSpace}, eArgs
									])));
							}
						} else {
							var eCallMethod = mkBuiltin("Reflect.callMethod", tcallMethod, removeLeadingTrivia(eFun));
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

	static function extractTypedBoundMethod(eFun:TExpr):Null<{obj:TExpr, name:String, token:Token}> {
		return switch eFun.kind {
			case TEField(obj, fieldName, fieldToken):
				switch resolveMethodField(obj, fieldName) {
					case {objExpr: objExpr}:
						{obj: objExpr, name: fieldName, token: fieldToken};
					case null:
						null;
				}
			case _:
				switch eFun.kind {
					case TEParens(_, inner, _) | TEHaxeRetype(inner):
						extractTypedBoundMethod(inner);
					case _:
						null;
				}
		}
	}

	static function resolveMethodField(obj:TFieldObject, fieldName:String):Null<{objExpr:TExpr}> {
		return switch obj.kind {
			case TOExplicit(_, eobj):
				return if (isTypedMethodField(eobj.type, fieldName, false)) {objExpr: eobj} else null;
			case TOImplicitThis(cls):
				return if (isTypedMethodField(TTInst(cls), fieldName, false)) {
					{objExpr: mk(TELiteral(TLThis(mkIdent("this"))), TTInst(cls), TTInst(cls))}
				} else null;
			case TOImplicitClass(cls):
				return if (isTypedMethodField(TTStatic(cls), fieldName, true)) {
					{objExpr: mkDeclRef({first: mkIdent(cls.name), rest: []}, {name: cls.name, kind: TDClassOrInterface(cls)}, null)}
				} else null;
		}
	}

	static function isTypedMethodField(t:TType, fieldName:String, isStatic:Bool):Bool {
		return switch t {
			case TTInst(cls):
				isMethodField(cls, fieldName, isStatic);
			case TTStatic(cls):
				isMethodField(cls, fieldName, true);
			case _:
				false;
		}
	}

	static function isMethodField(cls:TClassOrInterfaceDecl, fieldName:String, isStatic:Bool):Bool {
		return switch cls.findFieldInHierarchy(fieldName, isStatic) {
			case {field: {kind: TFFun(_)}}:
				true;
			case _:
				false;
		}
	}
}
