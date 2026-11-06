package checks {
	import flash.utils.Dictionary;

	/** Dynamic objects, Dictionary, equality, truthiness, typeof, is and as. */
	public class Objects {
		public static function run(out:Array):void {
			var o:Object = {b: 1, a: 2};
			o.c = 3;
			o["d"] = 4;
			delete o.a;
			var keys:Array = [];
			for (var key:String in o) {
				keys.push(key);
			}
			keys.sort();
			var total:int = 0;
			for each (var v:int in o) {
				total += v;
			}
			out.push("dynamic=" + keys.join(",") + "|" + total + "|" + ("a" in o) + "|" + ("b" in o) + "|" + o.hasOwnProperty("c") + "|" + (o.missing === undefined) + "|" + (o.missing == null));
			var numericKeys:Object = {};
			numericKeys[1] = "x";
			out.push("numericKey=" + numericKeys["1"] + "," + numericKeys.hasOwnProperty(1));
			var nothing:* = undefined;
			var none:* = null;
			var str:* = "1";
			var empty:* = "";
			var nan:Number = NaN;
			out.push("equality=" + (none == nothing) + "," + (none === nothing) + "," + (str == 1) + "," + (str === 1) + "," + (nan == nan) + "," + (empty == 0) + "," + (empty == false));
			out.push("truthy=" + Boolean("") + "," + Boolean("0") + "," + Boolean(nan) + "," + Boolean({}) + "," + Boolean(0) + "," + !nothing + "," + Boolean(-1));
			var zero:* = 0;
			var falseValue:* = false;
			out.push("logical=" + (none || "d") + "," + (zero || 5) + "," + ("a" && "b") + "," + (zero && "never") + "," + (falseValue || empty || "last"));
			// the operand that is not the result is not evaluated
			var calls:Array = [];
			var orFirst:* = pick("first", calls) || pick("never", calls);
			var orSecond:* = pick("", calls) || pick("second", calls);
			var andFirst:* = pick("", calls) && pick("never", calls);
			var andSecond:* = pick("x", calls) && pick("y", calls);
			out.push("lazyLogical=" + orFirst + "," + orSecond + "," + andFirst + "," + andSecond + "," + calls.join(""));
			var fn:Function = function():void {};
			var integer:int = 3;
			out.push("typeof=" + typeof 1 + "," + typeof "s" + "," + typeof none + "," + typeof nothing + "," + typeof o + "," + typeof fn + "," + typeof [] + "," + typeof true
				+ "," + typeof integer + "," + typeof Objects + "," + typeof new XML("<a/>"));
			var three:* = 3;
			var half:* = 1.5;
			var negative:* = -1;
			var text:* = "s";
			var whole:* = 2.0;
			out.push("is=" + (three is int) + "," + (half is int) + "," + (three is uint) + "," + (negative is uint) + "," + (whole is int) + "," + (three is Number) + "," + (text is String)
				+ "," + (none is Object) + "," + ([] is Object) + "," + (fn is Function));
			out.push("as=" + (text as Number) + "," + (three as String) + "," + (three as int) + "," + (half as int) + "," + ((o as Array) == null) + "," + ([1] as Array).length);
			var dict:Dictionary = new Dictionary();
			var k1:Object = {};
			var k2:Object = {};
			dict[k1] = "one";
			dict[k2] = "two";
			dict[1] = "number";
			dict["1"] = "string";
			dict[true] = "bool";
			var count:int = 0;
			for (var dk:* in dict) {
				count++;
			}
			delete dict[k2];
			out.push("dictionary=" + dict[k1] + "," + dict[k2] + "," + dict[1] + "," + count + "," + (k1 in dict) + "," + dict["true"]);
			var primitiveKeys:Dictionary = new Dictionary();
			var nameKey:String = "name";
			var numberName:String = "7";
			var noName:String = null;
			var intKey:int = 7;
			var largeKey:int = 5000;
			var negativeKey:int = -3;
			var uintKey:uint = 9;
			primitiveKeys[nameKey] = "named";
			primitiveKeys[intKey] = "seven";
			primitiveKeys[largeKey] = "large";
			primitiveKeys[negativeKey] = "negative";
			primitiveKeys[uintKey] = "nine";
			out.push("dictionaryRead=" + primitiveKeys[nameKey] + "," + primitiveKeys[numberName] + "," + primitiveKeys[intKey] + "," + primitiveKeys[largeKey]
				+ "," + primitiveKeys[negativeKey] + "," + primitiveKeys[uintKey] + "," + primitiveKeys[noName] + "," + primitiveKeys["missing"] + "," + primitiveKeys[8]);
			var yes:Boolean = true;
			var no:Boolean = false;
			out.push("intFromBool=" + int(yes) + "," + int(no) + "," + uint(yes) + "," + (int(yes) + 1) + "," + (1 + int(no) * 2));
			var withToString:Labelled = new Labelled("lbl");
			// a class instance in an arithmetic + stops ax4 (Unsupported + operation): it goes through an untyped value
			var untypedLabel:* = withToString;
			out.push("implicit=" + withToString + "," + String(withToString) + "," + (untypedLabel + 1) + "," + [withToString].join(""));
			var proto:Object = new Object();
			proto["with space"] = 1;
			proto["0"] = "zero";
			out.push("keys=" + proto["with space"] + "," + proto[0]);
		}

		private static function pick(value:String, calls:Array):String {
			calls.push(value.length > 0 ? value.charAt(0) : "_");
			return value;
		}
	}
}
