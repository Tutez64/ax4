package {
	import checks.Checks;
	import flash.display.Sprite;

	/** Flash entry point of build.sh: traces the checks, each after "| " to tell them from the player's own messages, then the end marker build.sh waits for. */
	public class Main extends Sprite {
		public function Main() {
			var lines:Array = Checks.run();
			for each (var line:String in lines) {
				trace("| " + line);
			}
			trace("#END");
		}
	}
}
