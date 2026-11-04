package pipeline;

private class Counter {
	public var n:Int = 0;

	public function new() {
	}
}

class Tools {
	public static function scale(x:Float, ?factor:Float):Float {
		if (factor == null) factor = 2;
		return x * factor;
	}

	public static function kindName(k:Kind):String {
		return switch k {
			case Small: "small";
			case Big(size): "big" + size;
		}
	}

	public static function radiusOf(s:Shape):Float {
		var c:Circle = cast s;
		return c.radius;
	}

	public static function safeParse(s:String):String {
		try {
			if (s == "") throw "empty";
			return "ok " + s;
		} catch (e:String) {
			return "caught " + e;
		}
	}

	public static function count(times:Int):Int {
		var c = new Counter();
		for (i in 0...times) c.n++;
		return c.n;
	}

	public static function isFunction(x:Dynamic):Bool {
		return Type.typeof(x) == TFunction;
	}

	public static function emoji():String {
		return String.fromCharCode(0x1F600).length > 0 ? "yes" : "no";
	}
}
