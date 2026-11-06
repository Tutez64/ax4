package checks {
	/** switch fall-through, strict matching and loops. */
	public class Switches {
		public static function run(out:Array):void {
			var fall:Array = [];
			for (var i:int = 0; i < 4; i++) {
				fall.push(classify(i));
			}
			out.push("fallThrough=" + fall.join(","));
			var untyped:* = "1";
			var matched:String = "none";
			switch (untyped) {
				case 1:
					matched = "number";
					break;
				case "1":
					matched = "string";
					break;
			}
			out.push("strictCase=" + matched);
			// a case after default stops ax4 (`case` after `default` in switch): not checked here
			// labelled break and continue are not parsed by ax4: not checked here
			var w:int = 0;
			do {
				w++;
			} while (w < 0);
			var countdown:int = 3;
			var steps:Array = [];
			while (countdown--) {
				steps.push(countdown);
			}
			out.push("loops=" + w + "," + steps.join("") + "," + countdown);
		}

		private static function classify(value:int):String {
			var result:String = "";
			switch (value) {
				case 0:
					result += "zero";
				case 1:
					result += "one";
					break;
				case 2:
					return "two";
				default:
					result = "other";
			}
			return result;
		}
	}
}
