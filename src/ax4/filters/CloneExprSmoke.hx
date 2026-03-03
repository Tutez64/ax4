package ax4.filters;

class CloneExprSmoke extends AbstractFilter {
	// Smoke-check filter: forces cloneExpr over the tree, does not change semantics.
	override function processExpr(e:TExpr):TExpr {
		return cloneExpr(e);
	}
}
