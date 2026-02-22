/**
 * Test case: normalize URLRequestHeader content-type name for native targets.
 * Expected behavior:
 * - `new URLRequestHeader("content-type", "...")` should become `Content-Type`.
 * - mixed-case variants (`Content-type`, `CONTENT-TYPE`) should also normalize.
 * - unrelated header names must remain untouched.
 */
package {
	import flash.net.URLRequestHeader;

	public class TestFilterNormalizeContentTypeHeader {
		public function TestFilterNormalizeContentTypeHeader() {
			var lower:URLRequestHeader = new URLRequestHeader("content-type", "application/json");
			var mixed:URLRequestHeader = new URLRequestHeader("Content-type", "application/json");
			var upper:URLRequestHeader = new URLRequestHeader("CONTENT-TYPE", "application/json");
			var other:URLRequestHeader = new URLRequestHeader("X-Trace-Id", "abc");
		}
	}
}
