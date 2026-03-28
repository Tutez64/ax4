import sys.FileSystem;

class RunCompiledMain {
	static function main() {
		var args = Sys.args();
		if (args.length != 1) {
			Sys.println("Usage: RunCompiledMain <base-path>");
			Sys.exit(2);
		}

		var basePath = args[0];
		var candidates = switch (Sys.systemName()) {
			case "Windows": [basePath + ".exe", basePath];
			default: [basePath, basePath + ".exe"];
		};

		for (path in candidates) {
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) {
				Sys.exit(Sys.command(path, []));
			}
		}

		Sys.println('Could not find compiled test executable. Tried: ' + candidates.join(", "));
		Sys.exit(1);
	}
}
