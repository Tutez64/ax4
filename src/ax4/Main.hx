package ax4;

import sys.io.File;
import sys.FileSystem;

import haxe.zip.Reader;
import haxe.io.Path;

import ax4.Utils.*;
import ax4.Context;

using StringTools;

class Main {
	static var ctx:Context;
	static var skipFiles = new Map<String,Bool>();
	static var sourceRootsAbsolute:Array<String> = [];
	static var dataFilesLookup = new Map<String,Bool>();

	static function main() {
		var total = stamp();

		var args = Sys.args();
		if (args.length != 1) error('invalid args');

		var config:Config = haxe.Json.parse(File.getContent(args[0]));
		checkSet(config.src, 'src');
		checkSet(config.hxout, 'hxout');
		checkSet(config.swc, 'swc');
		if (config.settings == null) config.settings = {};
		if (config.settings.flashProperties == null) config.settings.flashProperties = FlashPropertiesSetting.none;
		if (config.copyNonAs == null) config.copyNonAs = true;

		ctx = new Context(config);
		var srcs = if (Std.isOfType(config.src, String)) [config.src] else config.src;
		initSourceRoots(srcs);
		initDataFilesLookup();

		clean();
		copy();
		unpackswc();

		var tree = new TypedTree();

		var t = stamp();
		SWCLoader.load(tree, config.haxeTypes, config.swc);
		Timers.swcs = stamp() - t;

		var files = [];
		for (src in srcs) {
			walk(src, src, files);
		}
		copydatafiles();

		t = stamp();
		Typer.process(ctx, tree, files);
		Timers.typing = stamp() - t;

		// File.saveContent("structure.txt", tree.dump());

		t = stamp();
		Filters.run(ctx, tree);
		Timers.filters = stamp() - t;

		var haxeDir = FileSystem.absolutePath(config.hxout);
		t = stamp();
		for (packName => pack in tree.packages) {
			var normalizedPackName = Utils.normalizePackageName(packName, config.packagePartRenames);

			var dir = Path.join({
				var parts = normalizedPackName.split(".");
				parts.unshift(haxeDir);
				parts;
			});

			for (mod in pack) {
				if (mod.isExtern) continue;
				Utils.createDirectory(dir);
				var gen = new ax4.GenHaxe(ctx);
				gen.writeModule(mod);
				var out = gen.toString();
				var moduleName = switch mod.pack.decl.kind {
					case TDClassOrInterface(c): Utils.normalizeTypeName(c.name);
					case _: mod.name;
				}
				var path = dir + "/" + moduleName + ".hx";
				File.saveContent(path, out);
			}
		}

		var imports = [];
		for (path => kind in ctx.getToplevelImports()) {
			imports.push('$kind $path;');
		}
		if (config.rootImports != null) {
			imports.push(File.getContent(config.rootImports));
		}
		if (imports.length > 0) {
			imports.unshift("#if !macro");
			imports.push("#end");
			File.saveContent(Path.join([haxeDir, "import.hx"]), imports.join("\n"));
		}

		Timers.output = stamp() - t;

		formatter();

		total = (stamp() - total);

		if (Timers.copy > 0)
		print("copy      " + Timers.copy);
		if (Timers.unpack > 0)
		print("unpack    " + Timers.unpack);
		print("parsing   " + Timers.parsing);
		print("swcs      " + Timers.swcs);
		print("typing    " + Timers.typing);
		print("filters   " + Timers.filters);
		print("output    " + Timers.output);
		if (Timers.formatter > 0)
		print("formatter " + Timers.formatter);
		print("-- TOTAL  " + total);
	}

	static function checkSet(value: Any, name: String): Void {
		if (value == null) error('$name not set');
	}

	static function error(message: String): Void {
		printerr(message);
		Sys.exit(1);
	}

	static function shouldSkip(path:String):Bool {
		var skipFiles = ctx.config.skipFiles;
		return skipFiles != null && skipFiles.contains(path);
	}

	static function initSourceRoots(srcs:Array<String>):Void {
		sourceRootsAbsolute = [];
		for (src in srcs) sourceRootsAbsolute.push(normalizePath(FileSystem.absolutePath(src)));
	}

	static function initDataFilesLookup():Void {
		dataFilesLookup = new Map<String,Bool>();
		if (ctx.config.datafiles == null) return;

		for (path in ctx.config.datafiles) {
			var normalized = normalizePath(path);
			dataFilesLookup.set(normalized, true);
			dataFilesLookup.set(normalizePath(FileSystem.absolutePath(path)), true);
		}
	}

	static function normalizePath(path:String):String {
		return path.replace("\\", "/");
	}

	static function makeRelativePath(root:String, path:String):String {
		var rootNorm = normalizePath(root);
		var pathNorm = normalizePath(path);
		if (pathNorm == rootNorm) return "";
		if (pathNorm.startsWith(rootNorm + "/")) return pathNorm.substr(rootNorm.length + 1);

		var rootAbs = normalizePath(FileSystem.absolutePath(root));
		var pathAbs = normalizePath(FileSystem.absolutePath(path));
		if (pathAbs == rootAbs) return "";
		if (pathAbs.startsWith(rootAbs + "/")) return pathAbs.substr(rootAbs.length + 1);

		return pathNorm;
	}

	static function findSourceRelativePath(path:String):Null<String> {
		var pathAbs = normalizePath(FileSystem.absolutePath(path));
		for (root in sourceRootsAbsolute) {
			if (pathAbs == root) return "";
			if (pathAbs.startsWith(root + "/")) return pathAbs.substr(root.length + 1);
		}
		return null;
	}

	static function getDataOutputDir():String {
		return ctx.config.dataout != null ? ctx.config.dataout : ctx.config.hxout;
	}

	static function hasDataSelectionFilters():Bool {
		return ctx.config.dataext != null || ctx.config.datafiles != null;
	}

	static function isDataFileSelected(path:String):Bool {
		var normalized = normalizePath(path);
		if (dataFilesLookup.exists(normalized)) return true;
		return dataFilesLookup.exists(normalizePath(FileSystem.absolutePath(path)));
	}

	static function shouldCopyNonAsFromSource(path:String, ext:String):Bool {
		if (!ctx.config.copyNonAs) return false;
		if (!hasDataSelectionFilters()) return true;
		if (ctx.config.dataext != null && ctx.config.dataext.indexOf(ext) != -1) return true;
		return isDataFileSelected(path);
	}

	static function copyFileToDataOutput(sourcePath:String, relPath:String):Void {
		var destinationPath = Path.join([getDataOutputDir(), normalizePath(relPath)]);
		var destinationDir = Path.directory(destinationPath);
		if (destinationDir != "" && !FileSystem.exists(destinationDir)) FileSystem.createDirectory(destinationDir);
		File.copy(sourcePath, destinationPath);
	}

	static function fileBaseName(path:String):String {
		var normalized = normalizePath(path);
		var slash = normalized.lastIndexOf("/");
		return slash == -1 ? normalized : normalized.substr(slash + 1);
	}

	static function walk(root:String, dir:String, files:Array<ParseTree.File>) {
		for (name in FileSystem.readDirectory(dir)) {
			var absPath = dir + "/" + name;
			if (FileSystem.isDirectory(absPath)) {
				walk(root, absPath, files);
			} else if (!shouldSkip(absPath)) {
				final extIndex = name.lastIndexOf('.') + 1;
				if (extIndex <= 1) continue;
				final ext = name.substr(extIndex);
				if (ext == "as") {
					var file = parseFile(absPath);
					if (file != null) {
						files.push(file);
					}
				} else if (shouldCopyNonAsFromSource(absPath, ext)) {
					var relPath = makeRelativePath(root, absPath);
					final t = stamp();
					copyFileToDataOutput(absPath, relPath);
					Timers.copy += stamp() - t;
				}
			}
		}
	}

	static function parseFile(path:String):ParseTree.File {
		// print('Parsing $path');
		var t = stamp();
		var content = stripBOM(ctx.fileLoader.getContent(path));
		var scanner = new Scanner(content);
		var parser = new Parser(scanner, path);
		var parseTree = null;
		try {
			parseTree = parser.parse();
			// var dump = ParseTreeDump.printFile(parseTree, "");
			// Sys.println(dump);
		} catch (e:Any) {
			ctx.reportError(path, @:privateAccess scanner.pos, Std.string(e));
		}
		Timers.parsing += (stamp() - t);
		if (parseTree != null) {
			// checkParseTree(path, content, parseTree);
		}
		return parseTree;
	}

	static function checkParseTree(path:String, expected:String, parseTree:ParseTree.File) {
		var actual = Printer.print(parseTree);
		if (actual != expected) {
			printerr(actual);
			printerr("-=-=-=-=-");
			printerr(expected);
			// throw "not the same: " + haxe.Json.stringify(actual);
			throw new haxe.Exception('$path not the same');
		}
	}

	static function unpackswc() {
		if (ctx.config.unpackswc == null && ctx.config.unpackout == null) return;
		final t = stamp();
		if (!FileSystem.exists(ctx.config.unpackout)) FileSystem.createDirectory(ctx.config.unpackout);

		for (swc in ctx.config.unpackswc)
			for (entry in Reader.readZip(File.read(swc)))
				if (entry.fileName == 'library.swf') {
					print('Unpack ' + swc);
					File.saveBytes(ctx.config.unpackout + fileName(swc) + 'swf', Reader.unzip(entry));
					break;
				}
		Timers.unpack = stamp() - t;
	}

	static function fileName(path: String): String {
		return path.substring(path.lastIndexOf('/'), path.lastIndexOf('.') + 1);
	}

	static function copydatafiles(): Void {
		if (ctx.config.datafiles == null || ctx.config.datafiles.length == 0) return;
		final t = stamp();
		for (path in ctx.config.datafiles) {
			var relPath = findSourceRelativePath(path);
			if (relPath == null || relPath == "") relPath = fileBaseName(path);
			print('Copy file ' + fileBaseName(path));
			copyFileToDataOutput(path, relPath);
		}
		Timers.copy += stamp() - t;
	}

	static function clean(): Void {
		if (ctx.config.dataoutClean && ctx.config.dataout != null) deleteDirRecursively(ctx.config.dataout);
		if (ctx.config.hxoutClean) deleteDirRecursively(ctx.config.hxout);
	}

	static function deleteDirRecursively(path: String): Void {
		if (FileSystem.exists(path) && FileSystem.isDirectory(path)) {
			for (entry in FileSystem.readDirectory(path)) {
				if (FileSystem.isDirectory(path + '/' + entry)) {
					deleteDirRecursively(path + '/' + entry);
					FileSystem.deleteDirectory(path + '/' + entry);
				} else {
					FileSystem.deleteFile(path + '/' + entry);
				}
			}
		}
	}

	static function formatter(): Void {
		if (!ctx.config.formatter) return;
		final t = stamp();
		final args = ['run', 'formatter', '-s', ctx.config.hxout];
		print('haxelib ' + args.join(' '));
		Sys.command('haxelib', args);
		Timers.formatter = stamp() - t;
	}

	static function copy(): Void {
		if (ctx.config.copy != null && ctx.config.copy.length > 0) {
			final t = stamp();
			for (copy in ctx.config.copy) copyUnit(copy.unit, copy.to);
			Timers.copy += stamp() - t;
		}
	}

	static function copyUnit(unit: String, to: String): Void {
		if (FileSystem.isDirectory(unit)) {
			if (!unit.endsWith('/')) unit += '/';
			if (!to.endsWith('/')) to += '/';
			if (!FileSystem.exists(to)) FileSystem.createDirectory(to);
			for (u in FileSystem.readDirectory(unit)) copyUnit(unit + u, to + u);
		} else {
			print('Copy file $unit to $to');
			File.copy(unit, to);
		}
	}
}
