package checks {
	/**
	 * The AS3 checks: each pushes `name=value` lines, which Flash Player prints into expected.txt
	 * (build.sh) and the converted code must print the same (test-as3.hxml).
	 */
	public class Checks {
		public static function run():Array {
			var out:Array = [];
			Numbers.run(out);
			Strings.run(out);
			Arrays.run(out);
			Objects.run(out);
			Errors.run(out);
			Closures.run(out);
			Classes.run(out);
			Switches.run(out);
			return out;
		}
	}
}
