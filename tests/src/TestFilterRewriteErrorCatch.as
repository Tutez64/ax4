/**
 * Test case: rewrite broad AS3 Error catches for cross-target runtime compatibility.
 * Expected behavior:
 * - `catch (e:Error)` should be rewritten to `catch (e:Dynamic)` in generated Haxe.
 * - specific catches (e.g. `TypeError`) must remain typed.
 * - catch body expressions should remain intact after rewrite.
 * - reads of the caught value become `ASCompat.asError(e)`, an Error even when a runtime error outside
 *   flash is not one: a field read, an argument where an Error is expected, an untyped copy.
 * - the API filters see those reads: `e.message.replace(regexp, "")` becomes a RegExp replace.
 * - a rethrow (`throw e`) and an assignment to the caught variable keep the caught value itself.
 */
package {
	public class TestFilterRewriteErrorCatch {
		public function TestFilterRewriteErrorCatch() {
			testSingleErrorCatch();
			testTypedThenErrorCatch();
			testUntypedThrowWithErrorCatch();
			testErrorReadsAndRethrow();
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

		private function testErrorReadsAndRethrow():void {
			try {
				var o:Object = null;
				o.field = 1;
			} catch (e:Error) {
				report(e);
				var id:int = e.errorID;
				trace(e.message.replace(/\.+$/, ""));
				if (id == 0) {
					throw e;
				}
				e = new Error("replaced");
			}
		}

		private function report(error:Error):void {
			trace(error.message);
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
