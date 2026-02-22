package ax3;

import ax3.TypedTree;
import ax3.filters.*;

class Filters {
	public static function run(context:Context, tree:TypedTree) {
		var externImports = new ExternModuleLevelImports(context);
		var detectCppMacroConflicts = new CppMacroConflicts.DetectCppMacroConflicts(context);
		var coerceToBool = new CoerceToBool(context);
		var detectFieldRedefinitions = new RewriteRedefinedPrivate.DetectFieldRedefinitions(context);
		var detectStaticInstanceConflicts = new HandleStaticInstanceConflict.DetectStaticInstanceConflicts(context);
		// cloneExpr needs coverage both before and after rewrites to hit pre- and post-transform node kinds.
		var cloneExprSmokeEarly = context.config.testCloneExpr == true ? new CloneExprSmoke(context) : null;
		var cloneExprSmokeLate = context.config.testCloneExpr == true ? new CloneExprSmoke(context) : null;

		var filters:Array<AbstractFilter> = [];
		if (cloneExprSmokeEarly != null) filters.push(cloneExprSmokeEarly);
		filters = filters.concat([
			detectCppMacroConflicts,
			new CppMacroConflicts.RenameCppMacroConflicts(context, detectCppMacroConflicts),
			detectFieldRedefinitions,
			detectStaticInstanceConflicts,
			new RewriteRedefinedPrivate.RenameRedefinedFields(context, detectFieldRedefinitions),
			new HandleStaticInstanceConflict.RenameStaticInstanceConflicts(context, detectStaticInstanceConflicts),
			new RewriteAssignOps(context),
			new WrapModuleLevelDecls(context),
			new HandleVisibilityModifiers(context),
			new RewriteMeta(context),
			new MathApi(context),
			new RewriteJSON(context),
			new UtilFunctions(context),
			externImports,
			new InlineStaticConsts(context),
			new InlineStaticConsts.FixInlineStaticConstAccess(context),
			new RewriteE4X(context),
			new RewriteSwitch(context),
			new RestArgs(context),
			new RewriteRegexLiterals(context),
			new HandleNew(context),
			new RewriteVectorDecl(context),
			new AddSuperCtorCall(context),
			new RemoveRedundantSuperCtorCall(context),
			new RewriteBlockBinops(context),
			new RewriteNewArray(context),
			new RewriteTypesWithComment(context),
			new RewriteDelete(context),
			new InferLocalVarTypes(context),
			new RewriteArrayAccess(context),
			new RewriteDynamicFieldAccess(context),
			new RewriteAs(context),
			new RewriteIs(context),
			new RewriteCFor(context)
		]);
		if (cloneExprSmokeLate != null) filters.push(cloneExprSmokeLate);
		filters = filters.concat([
			new ApiSignatureOverrides(context),
			new RewriteForIn(context),
			new RewriteHasOwnProperty(context),
			new RewriteUndefinedLookupComparisons(context),
			new NumberToInt(context),
			new CoerceToNumber(context),
			new RewriteObjectCompare(context),
			new RewriteCasts(context),
			new RewriteClassCast(context),
			new HandleBasicValueDictionaryLookups(context),
			coerceToBool,
			new RewriteNonBoolOr(context, coerceToBool),
			new InvertNegatedEquality(context),
			new HaxeProperties(context),
			new AlignAccessorTypes(context),
			new AddMissingAccessorInSuper(context),
			new RewriteAccessorAccess(context),
			new UnqualifiedSuperStatics(context),
			// new AddParens(context),
			new AddRequiredParens(context),
			// new CheckExpectedTypes(context)
			new DateApi(context),
			new ArrayApi(context),
			new FiltersApi(context),
			new SystemApi(context),
			new StringApi(context),
			new TextFieldApi(context),
			new DisplayObjectContainerApi(context),
			new ApiSignatureOverrides(context), // This second appearance is useful
			new FileModeApi(context),
			new ColorMatrixFilterApi(context),
			new NumberApi(context),
			new RewriteArguments(context),
			new FixEventListenerArity(context),
			new ExtensionContextCall(context),
			new FunctionApply(context),
			new ToString(context),
			new CoerceFromAny(context),
			new FixNonInlineableDefaultArgs(context),
			new FixIteratorCasts(context),
			new FixDowncastRetypes(context),
			new NamespacedToPublic(context),
			new MoveCtorBaseFieldAssignAfterSuper(context),
			new MoveFieldInits(context),
			new HoistLocalDecls(context),
			new VarInits(context),
			new FixVoidReturn(context),
			new UintComparison(context),
			new HandleProtectedOverrides(context),
			new FixOverrides(context),
			new RewriteErrorCatch(context),
			new CheckUntypedMethodCalls(context),
			new RemoveRedundantParenthesis(context),
			new RewriteProxyInheritance(context),
			new FixImports(context)
		]);

		for (f in filters) {
			f.run(tree);
		}

		externImports.addGlobalsModule(tree);
	}
}
