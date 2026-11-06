package checks {
	/** Function scoping, closures, default values, rest arguments and bound methods. */
	public class Closures {
		private var mName:String;

		public function Closures(name:String = "default") {
			mName = name;
		}

		public function greet(suffix:String = "!"):String {
			return mName + suffix;
		}

		public static function run(out:Array):void {
			// a var is scoped to the function: every closure sees its last value
			var fs:Array = [];
			for (var i:int = 0; i < 3; i++) {
				fs.push(function():int { return i; });
			}
			out.push("loopCapture=" + fs[0]() + "," + fs[2]());
			var made:Array = [];
			for (var j:int = 0; j < 3; j++) {
				made.push(capture(j));
			}
			out.push("factoryCapture=" + made[0]() + "," + made[2]());
			var n:Number;
			var k:int;
			var u:uint;
			var s:String;
			var b:Boolean;
			var o:Object;
			var a:*;
			out.push("defaults=" + n + "," + k + "," + u + "," + s + "," + b + "," + o + "," + a);
			out.push("hoisting=" + hoisted());
			out.push("rest=" + count() + "," + count(1, "two", null) + "," + joinRest("-", 1, 2, 3) + "," + defaults() + "," + defaults(5));
			var bound:Function = new Closures("bound").greet;
			out.push("bound=" + bound() + "," + bound("?") + "," + bound.call(null, ".") + "," + bound.apply(null, [";"]) + "," + new Closures().greet());
			var counter:int = 0;
			var incr:Function = function():void { counter++; };
			incr();
			incr();
			out.push("shared=" + counter);
			// a named function expression (function self(x) {...}) is not typed by ax4: not checked here
			var fact:Function;
			fact = function(x:int):int { return x <= 1 ? 1 : x * fact(x - 1); };
			out.push("recursive=" + fact(5));
			// arguments is not typed by ax4: not checked here
			var add:Function = function(x:Number, y:Number):Number { return x + y; };
			out.push("apply=" + add.apply(null, [2, 3]) + "," + add.call(null, 4, 5) + "," + add.length);
		}

		private static function capture(value:int):Function {
			return function():int { return value; };
		}

		private static function hoisted():String {
			var before:String = String(late);
			var late:int = 5;
			return before + "," + late;
		}

		private static function count(... rest):int {
			return rest.length;
		}

		private static function joinRest(separator:String, ... rest):String {
			return rest.join(separator);
		}

		private static function defaults(x:int = 2, y:Number = 0.5, z:String = null):String {
			return x + ":" + y + ":" + z;
		}
	}
}
