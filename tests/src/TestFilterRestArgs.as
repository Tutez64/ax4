/**
 * Test case: exhaustive coverage for RestArgs filter rewrite on Haxe >= 4.2.
 * Expected behavior:
 * - every function body using AS3 `...rest` should initialize its local rest array via ASCompat.restToArray(...)
 * - converter must avoid direct `_rest.toArray()` calls (runtime crash risk on some dynamic/callable paths)
 * - rest parameter renaming must avoid collisions (`args`, `_args`, `__args`) while preserving body references
 * - local functions and anonymous functions with rest should also be rewritten
 */
package {
	public class TestFilterRestArgs {
		public var events:Array;

		public function TestFilterRestArgs() {
			events = [];

			var cb:Function = withCallbacks;
			cb(1, 2, onResult, onError);
			cb("onlyResult", onResult);
			cb();

			staticWithRest("s", 1, 2, 3);
			defaultAndRest();
			defaultAndRest(10, true, 20, 30);

			events.push(conflictWithUnderscore(10, 1, 2));
			events.push(conflictWithDoubleUnderscore(10, 20, 1, 2, 3));
			events.push(localAndAnonymousRest("tag"));

			var passthrough:Array = passThrough(5, 6, 7);
			events.push(passthrough.length);
		}

		public function withCallbacks(...args):void {
			if (args.length > 0) {
				var fn:* = args[args.length - 1];
				if (fn is Function) {
					Function(fn)();
				}
			}
		}

		public static function staticWithRest(prefix:String, ...values):String {
			return prefix + ":" + values.length;
		}

		public function defaultAndRest(seed:int = 1, enabled:Boolean = false, ...tail):int {
			if (!enabled) {
				return seed;
			}
			return seed + tail.length;
		}

		public function conflictWithUnderscore(_args:int, ...args):int {
			return _args + args.length;
		}

		public function conflictWithDoubleUnderscore(_args:int, __args:int, ...args):int {
			return _args + __args + args.length;
		}

		public function localAndAnonymousRest(tag:String):String {
			function local(base:int, ...rest):int {
				return base + rest.length;
			}

			var anon:Function = function(prefix:String, ...rest):String {
				return prefix + ":" + rest.length;
			};

			var localValue:int = local(2, 10, 20, 30);
			var anonValue:String = String(anon(tag, 1, 2, 3, 4));
			return anonValue + ":" + localValue;
		}

		public function passThrough(..._rest):Array {
			return _rest;
		}

		private function onResult():void {}

		private function onError():void {}
	}
}
