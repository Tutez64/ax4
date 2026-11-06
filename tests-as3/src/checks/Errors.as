package checks {
	/** try/catch/finally: typed catches, rethrows, non-Error values and runtime errors. */
	public class Errors {
		public static function run(out:Array):void {
			try {
				throw new Error("boom", 7);
			} catch (e:Error) {
				out.push("error=" + e.message + "," + e.errorID + "," + e.name + "," + e);
			}
			var which:String;
			try {
				throw new ArgumentError("arg");
			} catch (e:TypeError) {
				which = "type";
			} catch (e:ArgumentError) {
				which = "argument:" + e.message + ":" + (e is Error);
			}
			out.push("typedCatch=" + which);
			var thrown:*;
			try {
				throw "plain";
			} catch (e:Error) {
				thrown = "error";
			} catch (e:*) {
				thrown = "any:" + e;
			}
			out.push("nonError=" + thrown);
			var order:Array = [];
			out.push("finally=" + withFinally(order) + "," + order.join(""));
			var none:Object = null;
			var caught:String = "no";
			try {
				none.field = 1;
			} catch (e:Error) {
				caught = "yes:" + (e is Error) + ":" + (e.message.length > 0);
			}
			out.push("nullAccess=" + caught);
			var outer:String;
			try {
				try {
					throw new RangeError("inner");
				} catch (e:Error) {
					throw e;
				}
			} catch (e:RangeError) {
				outer = "range:" + e.message;
			}
			out.push("rethrow=" + outer);
			var replaced:String;
			try {
				throw new Error("first");
			} catch (e:Error) {
				e = new Error("second");
				replaced = e.message;
			}
			out.push("assignCaught=" + replaced);
			var loops:int = 0;
			for (var i:int = 0; i < 3; i++) {
				try {
					if (i == 1) {
						continue;
					}
					loops += 10;
				} finally {
					loops++;
				}
			}
			out.push("finallyContinue=" + loops);
			out.push("errorToString=" + new Error("m") + "|" + new TypeError("t") + "|" + String(new Error()));
		}

		private static function withFinally(order:Array):String {
			try {
				order.push("t");
				return "returned";
			} finally {
				order.push("f");
			}
			return "unreached";
		}
	}
}
