package ax4.filters;

class FixEventListenerArity extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall(eobj, args):
				var name = extractCallName(eobj);
				if (name != "addEventListener" && name != "removeEventListener") {
					e;
				} else if (args.args.length < 2) {
					e;
				} else {
					var listenerArg = args.args[1];
					if (!isZeroArgFunction(listenerArg.expr)) {
						e;
					} else {
						var nextExpr = listenerArg.expr.with(expectedType = TTFun([TTAny], TTVoid));
						if (nextExpr == listenerArg.expr) {
							e;
						} else {
							var nextArgs = args.args.copy();
							nextArgs[1] = {expr: nextExpr, comma: listenerArg.comma};
							e.with(kind = TECall(eobj, args.with(args = nextArgs)));
						}
					}
				}
			case _:
				e;
		}
	}

	static function extractCallName(eobj:TExpr):Null<String> {
		return switch eobj.kind {
			case TEField(_, name, _): name;
			case _: null;
		}
	}

	static function isZeroArgFunction(e:TExpr):Bool {
		return switch e.kind {
			case TELocalFunction(f): f.fun.sig.args.length == 0;
			case _: e.type.match(TTFun([], _));
		}
	}
}
