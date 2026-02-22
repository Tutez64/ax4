/**
 * Test case: rewrite HTTP-oriented URLStream usage to URLLoader.
 * Expected behavior:
 * - URLStream declarations used with HTTP event flow are rewritten to URLLoader
 * - readUTFBytes(bytesAvailable) is rewritten to compatibility helpers
 * - constructor/field types depending on URLStream are rewritten consistently
 */
package {
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.net.URLStream;

	public class TestFilterURLStreamHttpToURLLoader {
		private var stream:URLStream;

		public function TestFilterURLStreamHttpToURLLoader() {
			stream = new URLStream();
		}

		public function makeRequest(req:URLRequest):void {
			var local:URLStream = new URLStream();
			local.addEventListener("httpResponseStatus", onStatus);
			local.addEventListener("httpStatus", onStatus);
			local.addEventListener("complete", function(e:Event):void {
				var body:String = local.readUTFBytes(local.bytesAvailable);
				sink(body);
			});
			local.load(req);
		}

		public function bindPending(pending:PendingURLStreamHolder):void {
			pending.replace(stream);
		}

		private function onStatus(e:*):void {}

		private function sink(v:String):void {}
	}
}

import flash.net.URLStream;

class PendingURLStreamHolder {
	private var stream:URLStream;

	public function PendingURLStreamHolder(stream:URLStream) {
		this.stream = stream;
	}

	public function replace(next:URLStream):void {
		stream = next;
	}

	public function close():void {
		stream.close();
	}
}

