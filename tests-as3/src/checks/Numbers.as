package checks {
	/** int, uint and Number arithmetic, conversions and formatting. */
	public class Numbers {
		public static function run(out:Array):void {
			var three:uint = 3;
			var five:uint = 5;
			var empty:uint = 0;
			var zero:int = 0;
			// uint - uint is a Number, which can be negative
			out.push("uintSub=" + (three - five) + "," + (zero < empty - 1) + "," + (empty - 1 < zero));
			var max:int = int.MAX_VALUE;
			var wrapped:int = max + 1;
			// int arithmetic is a Number until stored
			out.push("intOverflow=" + (max + 1) + "," + wrapped + "," + (max * 2) + "," + int(max * 2));
			var f:Number = 3.7;
			var g:Number = -3.7;
			var nan:Number = NaN;
			var huge:Number = 4294967301;
			out.push("toInt=" + int(f) + "," + int(g) + "," + int(nan) + "," + int(huge) + "," + int(" 42 ") + "," + int("0x10"));
			out.push("toUint=" + uint(-1) + "," + uint(f) + "," + uint(g) + "," + uint(huge));
			var minusOne:int = -1;
			var one:int = 1;
			var shift:int = 32;
			out.push("shifts=" + (minusOne >>> 0) + "," + (minusOne >>> 28) + "," + (one << 31) + "," + (one << shift) + "," + (-8 >> 1));
			var key:uint = 0xFFFFFFFF;
			var edge:int = 0x12;
			// & binds tighter than ^, which binds tighter than |
			out.push("precedence=" + (key & 0xFFFFFF00 | edge & 0xFF) + "," + (1 | 2 ^ 3 & 6));
			out.push("division=" + (7 / 2) + "," + (-7 % 3) + "," + (7.5 % 2) + "," + (one / 0) + "," + (-one / 0) + "," + (zero / 0));
			var tenth:Number = 0.1;
			out.push("format=" + (tenth + 0.2) + "," + (one / 3) + "," + 1e21 + "," + 1e-7 + "," + 123456789012 + "," + (-zero) + "," + 2.50);
			out.push("toFixed=" + (1.25).toFixed(1) + "," + (2.5).toFixed(0) + "," + (-1.5).toFixed(0) + "," + (1234.5678).toFixed(2) + "," + (0.000001).toFixed(3));
			var neg:int = -255;
			out.push("radix=" + (255).toString(16) + "," + neg.toString(2) + "," + key.toString(16) + "," + (35).toString(36));
			out.push("parse=" + parseInt("0x1F") + "," + parseInt("08") + "," + parseInt("12px") + "," + parseFloat("3.5e2x") + "," + isNaN(parseInt("x"))
				+ "," + Number("") + "," + Number(" 12 ") + "," + isNaN(Number("12px")) + "," + Number(null) + "," + isNaN(Number(undefined)));
			out.push("math=" + Math.round(-2.5) + "," + Math.round(2.5) + "," + Math.floor(-0.5) + "," + Math.max() + "," + Math.min(1, NaN) + "," + Math.abs(int.MIN_VALUE));
			var u:uint = 0;
			u--;
			var v:uint = 10;
			v -= 20;
			var d:int = 7;
			d /= 2;
			var m:int = 7;
			m *= 1.5;
			var inc:Number = 0.5;
			inc++;
			out.push("compound=" + u + "," + v + "," + d + "," + m + "," + inc);
			var small:uint = 1;
			out.push("mixedCompare=" + (small > minusOne) + "," + (key == minusOne) + "," + (uint(minusOne) == key) + "," + (key + 1));
			var s:* = "3";
			out.push("untypedMath=" + (s * 4) + "," + (s + 4) + "," + (s - 1) + "," + (-s) + "," + (s / 2));
			out.push("constants=" + int.MIN_VALUE + "," + uint.MAX_VALUE + "," + (Number.MAX_VALUE > 1e308) + "," + Number.MIN_VALUE);
			var uintMax:Number = uint.MAX_VALUE;
			out.push("limits=" + uintMax + "," + (uint.MAX_VALUE > int.MAX_VALUE) + "," + uint.MIN_VALUE + "," + Number.POSITIVE_INFINITY + "," + Number.NEGATIVE_INFINITY
				+ "," + (Number.NEGATIVE_INFINITY < -1e308) + "," + (Number.MIN_VALUE > 0));
		}
	}
}
