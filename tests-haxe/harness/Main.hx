/** Runs the converted checks and compares their output with expected.txt (from the Haxe sources). */
class Main {
	static function main() {
		var expected = StringTools.trim(haxe.Resource.getString("expected")).split("\n");
		var actual = pipeline.Checks.run();
		var failures = 0;
		for (i in 0...Std.int(Math.max(expected.length, actual.length))) {
			var e = expected[i];
			var a:String = actual[i];
			if (e != a) {
				failures++;
				Sys.println('FAIL $e\n  got $a');
			}
		}
		// the handwritten FFDec forms (src-handwritten/), which no Haxe source of hx/ produces
		var handwritten = pipeline.UntypedMaps.run(new haxe.ds.StringMap<ASAny>());
		if (handwritten != "untyped=7,false") {
			failures++;
			Sys.println('FAIL untyped=7,false\n  got $handwritten');
		}
		Sys.println(failures == 0 ? 'OK ${expected.length + 1} checks' : '$failures of ${expected.length + 1} checks failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
