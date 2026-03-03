package ax4.filters;

class FiltersApi extends AbstractFilter {
	var bitmapFilterType:Null<TType>;

	override public function run(tree:TypedTree) {
		this.tree = tree;
		bitmapFilterType = resolveBitmapFilterType();
		super.run(tree);
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a = {kind: TEField(_, "filters", _)}, op = OpAssign(_), b):
				var b2 = coerceFiltersArray(b, a.type);
				if (b2 == b) e else e.with(kind = TEBinop(a, op, b2));
			case _:
				e;
		}
	}

	function coerceFiltersArray(e:TExpr, targetType:Null<TType>):TExpr {
		var desired = resolveTargetType(targetType);
		if (desired == null && bitmapFilterType != null) {
			desired = TTArray(bitmapFilterType);
		} else if (bitmapFilterType != null) {
			switch desired {
				case TTArray(elem) if (isAnyLike(elem)):
					desired = TTArray(bitmapFilterType);
				case _:
			}
		}
		if (desired == null) return e;
		switch e.kind {
			case TELiteral(TLNull(_)):
				return wrapNull(desired, e);
			case TEHaxeRetype(inner):
				if (isNullLiteral(inner)) {
					return wrapNull(desired, e);
				}
				return wrapRetype(inner, desired, e);
			case _:
		}
		return switch e.type {
			case TTArray(elem) if (isAnyLike(elem)):
				wrapCast(e, desired);
			case TTAny | TTObject(TTAny):
				wrapCast(e, desired);
			case _:
				e;
		}
	}

	function wrapCast(e:TExpr, targetType:TType):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var eCast = mkBuiltin("cast", TTFunction, lead);
		return mkCall(eCast, [e], targetType, trail);
	}

	function wrapRetype(inner:TExpr, targetType:TType, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		var wrapped = mk(TEHaxeRetype(inner), targetType, targetType);
		processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), wrapped);
		processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), wrapped);
		return wrapped;
	}

	function wrapNull(targetType:TType, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		return mkNullExpr(targetType, lead, trail);
	}

	function isNullLiteral(e:TExpr):Bool {
		return switch e.kind {
			case TELiteral(TLNull(_)):
				true;
			case TEParens(_, inner, _):
				isNullLiteral(inner);
			case TEHaxeRetype(inner):
				isNullLiteral(inner);
			case _:
				false;
		}
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}

	static function resolveTargetType(t:Null<TType>):Null<TType> {
		if (t == null) return null;
		return switch t {
			case TTArray(_):
				t;
			case _:
				null;
		}
	}

	function resolveBitmapFilterType():Null<TType> {
		var decl = try tree.getDecl("flash.filters", "BitmapFilter") catch (_:Dynamic) null;
		if (decl == null) {
			decl = try tree.getDecl("openfl.filters", "BitmapFilter") catch (_:Dynamic) null;
		}
		return if (decl != null) {
			switch decl.kind {
				case TDClassOrInterface(c): TTInst(c);
				case _: null;
			}
		} else {
			null;
		}
	}
}
