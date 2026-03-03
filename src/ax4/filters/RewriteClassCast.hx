package ax4.filters;

class RewriteClassCast extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall({kind: TEBuiltin(_, "Class")}, args) if (args.args.length == 1):
				var arg = args.args[0].expr;
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), arg);
				processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), arg);
				mk(TEHaxeRetype(arg), TTClass, e.expectedType);
			case _:
				e;
		}
	}
}
