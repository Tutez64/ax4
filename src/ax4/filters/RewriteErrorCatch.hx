package ax4.filters;

class RewriteErrorCatch extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TETry(t):
				var changed = false;
				var catches = [for (c in t.catches) {
					if (isCatchErrorType(c.v.type)) {
						changed = true;
						rewriteErrorCatch(c);
					} else {
						c;
					}
				}];
				if (changed) e.with(kind = TETry(t.with(catches = catches))) else e;
			case _:
				e;
		}
	}

	static function rewriteErrorCatch(c:TCatch):TCatch {
		var lead = ParseTree.getSyntaxTypeLeadingTrivia(c.syntax.type.type);
		var trail = ParseTree.getSyntaxTypeTrailingTrivia(c.syntax.type.type);
		var dynamicToken = new Token(0, TkIdent, "Dynamic", lead, trail);
		return c.with(
			v = c.v.with(type = TTAny),
			syntax = c.syntax.with(type = c.syntax.type.with(type = TPath({first: dynamicToken, rest: []})))
		);
	}

	static function isCatchErrorType(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				if (cls.name != "Error") {
					false;
				} else {
					var packName = if (cls.parentModule == null) "" else cls.parentModule.parentPack.name;
					packName == "flash.errors" || packName == "openfl.errors" || packName == "";
				}
			case _:
				false;
		}
	}
}
