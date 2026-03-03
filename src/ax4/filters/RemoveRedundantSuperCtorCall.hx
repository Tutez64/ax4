package ax4.filters;

import ax4.Token.Trivia;

class RemoveRedundantSuperCtorCall extends AbstractFilter {
	override function processDecl(c:TDecl) {
		switch c.kind {
			case TDClassOrInterface(c = {kind: TClass(info)}) if (info.extend == null):
				for (m in c.members) {
					switch (m) {
						case TMField({kind: TFFun(f)}) if (f.name == c.name):
							if (f.fun.expr != null) {
								f.fun.expr = processCtorExpr(f.fun.expr);
							}
							break;
						case _:
					}
				}
			case _:
		}
	}

	function processCtorExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBlock(block):
				var pendingTrivia:Array<Trivia> = [];
				var newExprs = [];
				var changed = false;
				for (blockExpr in block.exprs) {
					var mapped = mapExpr(processCtorExpr, blockExpr.expr);
					if (isRedundantSuperCall(mapped)) {
						pendingTrivia = pendingTrivia.concat(collectTrivia(blockExpr, mapped));
						changed = true;
						continue;
					}
					if (pendingTrivia.length > 0) {
						processLeadingToken(t -> {
							t.leadTrivia = pendingTrivia.concat(t.leadTrivia);
							null;
						}, mapped);
						pendingTrivia = [];
						changed = true;
					}
					if (mapped != blockExpr.expr) {
						changed = true;
					}
					newExprs.push({expr: mapped, semicolon: blockExpr.semicolon});
				}
				if (pendingTrivia.length > 0) {
					block.syntax.closeBrace.leadTrivia = pendingTrivia.concat(block.syntax.closeBrace.leadTrivia);
					changed = true;
				}
				if (!changed) {
					e;
				} else {
					e.with(kind = TEBlock(block.with(exprs = newExprs)));
				}

			case _:
				mapExpr(processCtorExpr, e);
		}
	}

	function isRedundantSuperCall(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): isRedundantSuperCall(inner);
			case TECall({kind: TELiteral(TLSuper(_))}, _): true;
			case _: false;
		}
	}

	function collectTrivia(blockExpr:TBlockExpr, expr:TExpr):Array<Trivia> {
		var trivia = removeLeadingTrivia(expr).concat(removeTrailingTrivia(expr));
		if (blockExpr.semicolon != null) {
			trivia = trivia.concat(blockExpr.semicolon.leadTrivia);
			trivia = trivia.concat(blockExpr.semicolon.trailTrivia);
			blockExpr.semicolon.leadTrivia = [];
			blockExpr.semicolon.trailTrivia = [];
		}
		return trivia;
	}
}