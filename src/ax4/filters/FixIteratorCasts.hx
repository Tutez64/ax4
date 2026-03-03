package ax4.filters;

class FixIteratorCasts extends AbstractFilter {
	var iteratorDecl:Null<TDecl>;
	var iteratorClass:Null<TClassOrInterfaceDecl>;

	override public function run(tree:TypedTree) {
		this.tree = tree;
		iteratorDecl = try tree.getDecl("org.as3commons.collections.framework", "IIterator") catch (_:Dynamic) null;
		iteratorClass = switch iteratorDecl {
			case {kind: TDClassOrInterface(c)}: c;
			case _: null;
		}
		super.run(tree);
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		if (iteratorClass == null) return e;
		return switch e.kind {
			case TEHaxeRetype(inner):
				switch e.type {
					case TTInst(c) if (c == iteratorClass):
						wrapCast(inner, e.type, e);
					case _:
						e;
				}
			case _:
				e;
		}
	}

	function wrapCast(inner:TExpr, targetType:TType, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		var eCast = mkBuiltin("cast", TTFunction, lead);
		return mkCall(eCast, [inner], targetType, trail);
	}
}
