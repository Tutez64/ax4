/**
 * Test case: RewriteNonBoolOr, AS3's || and && giving one of their operands.
 * Expected:
 * - `a || b` with a local `a`: `if (a) a else b`; `a && b`: `if (a) b else a`.
 * - with an `a` that is not read twice (a call): `ASCompat.orValue(a, b)` and `ASCompat.andValue(a, b)`,
 *   macros that read `a` once and `b` only when it is the result (here `fallback()` is not called
 *   when `name()` is not empty).
 * - Boolean operands stay Haxe's || and &&.
 */
package {
	public class TestFilterRewriteNonBoolOr {
		public function TestFilterRewriteNonBoolOr(label:String, flag:Boolean, other:Boolean) {
			var orLocal:String = label || "none";
			var andLocal:String = label && "set";
			var orCall:String = name() || fallback();
			var andCall:* = name() && fallback();
			var both:Boolean = flag || other && flag;
			trace(orLocal, andLocal, orCall, andCall, both);
		}

		private function name():String {
			return "";
		}

		private function fallback():String {
			return "fallback";
		}
	}
}
