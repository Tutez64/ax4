package checks {
	/** String conversions, methods and regular expressions. */
	public class Strings {
		public static function run(out:Array):void {
			var nothing:* = undefined;
			var none:Object = null;
			var noString:String = null;
			out.push("concat=" + "a" + 1 + 2 + "," + (1 + 2 + "a") + "," + none + "," + nothing + "," + noString + "," + String(none) + "," + String(nothing));
			var s:String = "Hello, World";
			out.push("substr=" + s.substr(-5) + "|" + s.substr(1, 3) + "|" + s.substring(5, 1) + "|" + s.slice(-5, -1) + "|" + s.slice(3) + "|" + s.substr(20) + "|");
			out.push("chars=" + s.charAt(1) + "|" + s.charAt(40) + "|" + s.charCodeAt(0) + "|" + isNaN(s.charCodeAt(40)) + "|" + String.fromCharCode(72, 105));
			out.push("index=" + s.indexOf("o") + "," + s.indexOf("o", 5) + "," + s.lastIndexOf("o") + "," + s.indexOf("") + "," + s.indexOf("", 40) + "," + s.indexOf("z"));
			// split with a limit stops ax4 (Unsupported String.split arguments): not checked here
			out.push("split=" + "a,b,,c".split(",").length + "|" + "abc".split("").join("-") + "|" + "a, b ,c".split(/\s*,\s*/).join("+")
				+ "|" + "".split(",").length);
			out.push("replace=" + "aaa".replace("a", "b") + "|" + "aaa".replace(/a/g, "b") + "|" + "john smith".replace(/(\w+) (\w+)/, "$2 $1") + "|"
				+ "a1b22".replace(/\d+/g, function(m:String, ... rest):String { return "<" + m.length + ">"; }) + "|" + "x.y".replace(".", "$&$&"));
			var found:Array = "a1b22c333".match(/\d+/g);
			out.push("match=" + found.join(",") + "|" + "abc".search(/c/) + "|" + ("abc".match(/z/) == null) + "|" + /(\d)(\d)/.exec("x12").join(","));
			out.push("case=" + "MiXeD".toUpperCase() + "," + "MiXeD".toLowerCase());
			out.push("compare=" + ("10" < "9") + "," + ("b" > "a") + "," + ("a" < "B") + "," + ("abc" == "abc"));
			var re:RegExp = /o/g;
			re.exec(s);
			out.push("regexp=" + re.lastIndex + "," + re.global + "," + re.source + "," + /A/i.test("a") + "," + new RegExp("^\\d+$").test("123"));
			var num:Number = 5;
			out.push("numberToString=" + String(num) + "," + num.toString() + "," + (num + "") + "," + String(true) + "," + String([1, [2, 3]]));
			out.push("trim=" + "[" + " pad ".split(" ").join("_") + "]");
			out.push("escape=" + escape("a b&c") + "," + unescape("%41%20") + "," + encodeURIComponent("a b/c") + "," + decodeURIComponent("%C3%A9"));
		}
	}
}
