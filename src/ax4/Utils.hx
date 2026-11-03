package ax4;

import sys.FileSystem;
import haxe.DynamicAccess;

class Utils {
	public static inline function print(s:String) {
		#if hxnodejs js.Node.console.log(s) #else Sys.println(s) #end;
	}

	public static inline function printerr(s:String) {
		#if hxnodejs js.Node.console.error(s) #else Sys.println(s) #end;
	}

	public static function stripBOM(text:String):String {
		return if (StringTools.fastCodeAt(text, 0) == 0xFEFF) text.substring(1) else text;
	}

	public static function createDirectory(dir:String) {
		var tocreate = [];
		while (!FileSystem.exists(dir) && dir != '') {
			var parts = dir.split("/");
			tocreate.unshift(parts.pop());
			dir = parts.join("/");
		}
		for (part in tocreate) {
			if (part == '')
				continue;
			dir += "/" + part;
			try {
				FileSystem.createDirectory(dir);
			} catch (e:Any) {
				throw "unable to create dir: " + dir;
			}
		}
	}

	public static function normalizePackagePart(part:String, ?renames:DynamicAccess<String>):String {
		if (part.length == 0) return part;
		// Haxe reads a name whose first letter after its leading underscores is uppercase as a type
		var first = 0;
		while (first < part.length - 1 && part.charAt(first) == "_") first++;
		var normalized = part.substring(0, first) + part.charAt(first).toLowerCase() + part.substring(first + 1);
		if (renames != null) {
			var renamed = renames[part];
			if (renamed == null || renamed == "") {
				renamed = renames[normalized];
			}
			if (renamed != null && renamed != "") {
				return renamed;
			}
		}
		return normalized;
	}

	public static function normalizeTypeName(name:String):String {
		if (name.length == 0) return name;
		// Haxe type names cannot hold `$` (ASC [Embed] classes: `atlas_xml$<sha1>`)
		if (name.indexOf("$") != -1) name = StringTools.replace(name, "$", "_");
		var first = name.charAt(0);
		return if (first >= "a" && first <= "z") first.toUpperCase() + name.substring(1) else name;
	}

	public static function normalizePackageName(packName:String, ?renames:DynamicAccess<String>):String {
		if (packName == "") return packName;
		var parts = packName.split(".");
		for (i in 0...parts.length) {
			parts[i] = normalizePackagePart(parts[i], renames);
		}
		return parts.join(".");
	}
}
