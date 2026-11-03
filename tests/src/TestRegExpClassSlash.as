package {
	public class TestRegExpClassSlash {
		public function endsWithSlash(path:String):Boolean {
			return /[\\/]$/.test(path);
		}

		public function stripBrackets(s:String):String {
			return s.replace(/[\[\]\/]/g, "");
		}
	}
}
