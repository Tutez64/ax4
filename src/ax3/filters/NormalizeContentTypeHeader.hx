package ax3.filters;

class NormalizeContentTypeHeader extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TENew(keyword, obj, args):
				if (args == null || args.args.length == 0 || !isUrlRequestHeaderCtor(obj)) {
					e;
				} else {
					var nextArgs = normalizeCtorArgs(args);
					if (nextArgs == args) e else e.with(kind = TENew(keyword, obj, nextArgs));
				}
			case _:
				e;
		}
	}

	function normalizeCtorArgs(args:TCallArgs):TCallArgs {
		if (args.args.length == 0) return args;
		var first = args.args[0];
		var nextExpr = normalizeHeaderExpr(first.expr);
		if (nextExpr == first.expr) return args;
		var nextArgs = args.args.copy();
		nextArgs[0] = {expr: nextExpr, comma: first.comma};
		return args.with(args = nextArgs);
	}

	function normalizeHeaderExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TELiteral(TLString(token)):
				var raw = unquote(token.text);
				if (raw == null || raw.toLowerCase() != "content-type") {
					e;
				} else {
					var nextToken = new Token(token.pos, TkStringDouble, haxe.Json.stringify("Content-Type"), token.leadTrivia, token.trailTrivia);
					e.with(kind = TELiteral(TLString(nextToken)));
				}
			case _:
				e;
		}
	}

	static function isUrlRequestHeaderCtor(obj:TNewObject):Bool {
		return switch obj {
			case TNType(tref):
				switch tref.type {
					case TTInst(cls):
						var pack = cls.parentModule.parentPack.name;
						(pack == "flash.net" || pack == "openfl.net" || pack == "") && cls.name == "URLRequestHeader";
					case _:
						false;
				}
			case TNExpr(_):
				false;
		}
	}

	static function unquote(value:String):Null<String> {
		if (value == null || value.length < 2) return null;
		var first = value.charAt(0);
		var last = value.charAt(value.length - 1);
		if ((first == "\"" && last == "\"") || (first == "'" && last == "'")) {
			return value.substr(1, value.length - 2);
		}
		return null;
	}
}
