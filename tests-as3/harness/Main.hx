/**
	Runs the converted checks and compares their output with expected.txt (from Flash Player).

	A line that differs is allowed when it is listed, exactly as printed, in the target's
	known-<target>.txt: the conversion is known to differ there. A listed line that no longer shows
	(fixed, or differing in another way) fails too, so that the list stays the current state.
**/
class Main {
	static function main() {
		var expected = lines(haxe.Resource.getString("expected"));
		var known = [for (line in lines(haxe.Resource.getString("known"))) if (line != "" && !StringTools.startsWith(line, "#")) line => true];
		var actual:Array<String> = cast checks.Checks.run();
		var failures = 0;
		var differing = 0;
		var seen = new Map<String, Bool>();
		for (i in 0...Std.int(Math.max(expected.length, actual.length))) {
			var e = expected[i];
			var a = actual[i];
			if (e == a) {
				continue;
			}
			if (a != null && known.exists(a)) {
				differing++;
				seen[a] = true;
				continue;
			}
			failures++;
			Sys.println('FAIL $e\n  got $a');
		}
		for (line in known.keys()) {
			if (!seen.exists(line)) {
				failures++;
				Sys.println('FAIL known difference no longer printed (update known-$target.txt): $line');
			}
		}
		var summary = '${expected.length} checks, $differing known differences';
		Sys.println(failures == 0 ? 'OK $summary' : '$failures failures ($summary)');
		Sys.exit(failures == 0 ? 0 : 1);
	}

	static final target = #if js "js" #elseif cpp "cpp" #else "other" #end;

	static function lines(text:String):Array<String> {
		return StringTools.trim(StringTools.replace(text, "\r", "")).split("\n");
	}
}
