package ax4.filters;

class UtilFunctions extends AbstractFilter {
	static final tResolveClass = TTFun([TTString], TTClass);
	static final tGetTimer = TTFun([], TTInt);
	static final tDescribeType = TTFun([TTAny], TTXML);
	static final tGetUrl = TTFun([TTAny/*TODO:URLRequest*/, TTString], TTVoid);
	static final tGetQualifiedClassName = TTFun([TTAny], TTString);
	static final tShowRedrawRegions = TTFun([TTBoolean, TTAny], TTVoid);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getDefinitionByName", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("Type.resolveClass", tResolveClass, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TECall({kind: TEBuiltin(_, "Type.resolveClass")}, _):
				// `getDefinitionByName` returns Object, but `Type.resolveClass` can only return Class, so fix the type of its calls
				e.with(type = TTClass);
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getTimer", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("flash.Lib.getTimer", tGetTimer, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "describeType", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("ASCompat.describeType", tDescribeType, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "getQualifiedClassName", parentPack: {name: "flash.utils" | "avmplus"}}})}):
				mkBuiltin("ASCompat.getQualifiedClassName", tGetQualifiedClassName, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "showRedrawRegions", parentPack: {name: "flash.profiler"}}})}):
				mkBuiltin("ASCompat.showRedrawRegions", tShowRedrawRegions, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: methodName = "clearTimeout" | "setTimeout" | "clearInterval" | "setInterval", parentPack: {name: "flash.utils"}}})}):
				mkBuiltin("ASCompat." + methodName, TTFunction, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case TEDeclRef(_, {kind: TDFunction({parentModule: {name: "navigateToURL", parentPack: {name: "flash.net"}}})}):
				mkBuiltin("flash.Lib.getURL", tGetUrl, removeLeadingTrivia(e), removeTrailingTrivia(e));
			case _:
				e;
		}
	}
}
