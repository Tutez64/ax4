package ax4.filters;

class ExtensionContextCall extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall(eobj, args):
				if (!isExtensionContextCall(eobj) || args.args.length <= 2) {
					e;
				} else {
					var nextArgs = rewriteArgs(args);
					e.with(kind = TECall(eobj, nextArgs));
				}
			case _:
				e;
		}
	}

	function isExtensionContextCall(eobj:TExpr):Bool {
		return switch eobj.kind {
			case TEField(obj, "call", _):
				switch obj.type {
					case TTInst(cls):
						cls.name == "ExtensionContext" && cls.parentModule.parentPack.name == "flash.external";
					case _:
						false;
				}
			case _:
				false;
		}
	}

	function rewriteArgs(args:TCallArgs):TCallArgs {
		var methodArg = args.args[0];
		var rest = args.args.slice(1);
		var elements = [];
		for (i in 0...rest.length) {
			var item = rest[i];
			elements.push({expr: item.expr, comma: i == rest.length - 1 ? null : commaWithSpace});
		}
		var arrayExpr = mk(TEArrayDecl({
			syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
			elements: elements
		}), TTArray(TTAny), TTArray(TTAny));

		var nextArgs = [
			{expr: methodArg.expr, comma: commaWithSpace},
			{expr: arrayExpr, comma: null}
		];
		return args.with(args = nextArgs);
	}
}
