/**
 * Test case: rewrite broad AS3 Error catches for cross-target runtime compatibility.
 * Expected behavior:
 * - `catch (e:Error)` should be rewritten to `catch (e:Dynamic)` in generated Haxe.
 * - specific catches (e.g. `TypeError`) must remain typed.
 * - catch body expressions should remain intact after rewrite.
 */
package {
	public class TestFilterRewriteErrorCatch {
		public function TestFilterRewriteErrorCatch() {
			testSingleErrorCatch();
			testTypedThenErrorCatch();
			testUntypedThrowWithErrorCatch();
		}

		private function testSingleErrorCatch():void {
			try {
				throw new Error("single");
			} catch (e:Error) {
				var msg:String = e.message;
			}
		}

		private function testTypedThenErrorCatch():void {
			try {
				throw new TypeError("typed");
			} catch (typed:TypeError) {
				var first:String = typed.message;
			} catch (fallback:Error) {
				var second:String = fallback.message;
			}
		}

		private function testUntypedThrowWithErrorCatch():void {
			try {
				throw "string throw";
			} catch (e:Error) {
				var value:* = e;
			}
		}
	}
}
