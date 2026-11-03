/** Prints the reference output of the checks, from the Haxe sources themselves. */
class RefMain {
	static function main() {
		for (line in pipeline.Checks.run()) Sys.println(line);
	}
}
