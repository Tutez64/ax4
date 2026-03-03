package ax4.filters;

class ColorMatrixFilterApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TENew(keyword, obj, args):
				var nextArgs = coerceCtorArgs(obj, args);
				if (nextArgs == args) e else e.with(kind = TENew(keyword, obj, nextArgs));

			case TEBinop(a, op = OpAssign(_), b):
				if (isColorMatrixMatrixField(a)) {
					var nextB = coerceFloatArray(b);
					if (nextB == b) e else e.with(kind = TEBinop(a, op, nextB));
				} else {
					e;
				}

			case _:
				e;
		}
	}

	function coerceCtorArgs(obj:TNewObject, args:Null<TCallArgs>):Null<TCallArgs> {
		if (!isColorMatrixFilterNew(obj) || args == null || args.args.length == 0) {
			return args;
		}
		var first = args.args[0];
		var coerced = coerceFloatArray(first.expr);
		if (coerced == first.expr) {
			return args;
		}
		var nextArgs = args.args.copy();
		nextArgs[0] = {expr: coerced, comma: first.comma};
		return args.with(args = nextArgs);
	}

	static function isColorMatrixFilterNew(obj:TNewObject):Bool {
		return switch obj {
			case TNType(tref): isColorMatrixFilterType(tref.type);
			case TNExpr(e): isColorMatrixFilterType(e.type);
		}
	}

	static function isColorMatrixFilterType(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				cls.name == "ColorMatrixFilter" && isFilterModule(cls.parentModule.parentPack.name);
			case _:
				false;
		}
	}

	static inline function isFilterModule(pack:String):Bool {
		return pack == "flash.filters" || pack == "openfl.filters";
	}

	function isColorMatrixMatrixField(e:TExpr):Bool {
		return switch e.kind {
			case TEField(obj, "matrix", _):
				isColorMatrixFilterType(obj.type);
			case TEParens(_, inner, _):
				isColorMatrixMatrixField(inner);
			case TEHaxeRetype(inner):
				isColorMatrixMatrixField(inner);
			case TECast(c):
				isColorMatrixMatrixField(c.expr);
			case _:
				false;
		}
	}

	function coerceFloatArray(e:TExpr):TExpr {
		return switch e.type {
			case TTArray(elem) if (isAnyLike(elem)):
				var target = TTArray(TTNumber);
				wrapCast(e, target);
			case _:
				e;
		}
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}

	function wrapCast(e:TExpr, targetType:TType):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var eCast = mkBuiltin("cast", TTFunction, lead);
		return mkCall(eCast, [e], targetType, trail);
	}
}
