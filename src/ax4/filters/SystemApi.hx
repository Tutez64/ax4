package ax4.filters;

class SystemApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(_, {type: TTStatic(cls) | TTInst(cls)})}, "pauseForGCIfCollectionImminent", _)}, args)
				if (isSystemClass(cls)):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var eMethod = mkBuiltin("ASCompat.pauseForGCIfCollectionImminent", TTFunction, lead);
				var newArgs = if (args == null) {
					{openParen: mkOpenParen(), args: [], closeParen: mkCloseParen(trail)};
				} else {
					args.closeParen.trailTrivia = trail;
					args;
				}
				e.with(kind = TECall(eMethod, newArgs));

			case _:
				e;
		}
	}

	static inline function isSystemClass(cls:TClassOrInterfaceDecl):Bool {
		if (cls.name != "System") return false;
		return switch cls.parentModule.parentPack.name {
			case "flash.system" | "openfl.system":
				true;
			case _:
				false;
		}
	}
}
