package ax4.filters;

class RewriteProxyInheritance extends AbstractFilter {
	override function processClass(c:TClassOrInterfaceDecl) {
		super.processClass(c);
		switch c.kind {
			case TClass(info):
				if (info.extend == null || !isProxyBase(info.extend)) {
					return;
				}
				var lead = ParseTree.getDotPathLeadingTrivia(info.extend.syntax.path);
				var trail = ParseTree.getDotPathTrailingTrivia(info.extend.syntax.path);
				info.extend.syntax.path = {first: mkIdent("ASProxyBase", lead, trail), rest: []};
			case _:
		}
	}

	static function isProxyBase(extend:TClassExtend):Bool {
		if (extend.superClass != null) {
			var superClass = extend.superClass;
			if (superClass.name == "Proxy" && superClass.parentModule.parentPack.name == "flash.utils") {
				return true;
			}
		}
		var path = ParseTree.dotPathToString(extend.syntax.path);
		return path == "Proxy" || path == "flash.utils.Proxy";
	}
}
