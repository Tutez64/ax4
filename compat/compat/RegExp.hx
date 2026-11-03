package compat;
#if js
import js.lib.RegExp.RegExpMatch;
#end
import haxe.extern.EitherType;
import haxe.Constraints.Function;

private typedef RegExpImpl = #if js js.lib.RegExp #elseif flash flash.utils.RegExp #else Dynamic #end;

class RegExp {
	#if (!js && !flash)
	var regex:EReg;
	var global:Bool;
	var groupCount:Int;
	#end

	#if (js || flash)
	var impl:RegExpImpl;
	public var lastIndex(get, set):Int;
	inline function get_lastIndex():Int return impl.lastIndex;
	inline function set_lastIndex(v:Int):Int return impl.lastIndex = v;
	#else
	public var lastIndex:Int = 0;
	#end

	public function new(pattern:String, options = "") {
		#if (js || flash)
		impl = new RegExpImpl(pattern, options);
		#else
		global = options.indexOf("g") >= 0;
		regex = new EReg(pattern, options);
		groupCount = countCaptureGroups(pattern);
		#end
	}

	public function exec(s:String):RegExpResult {
		#if js
		return impl.exec(s);
		#elseif flash
		return impl.exec(s);
		#else
		var start = global ? lastIndex : 0;
		if (!regex.matchSub(s, start)) {
			if (global) lastIndex = 0;
			return null;
		}
		var pos = regex.matchedPos();
		if (global) {
			lastIndex = pos.pos + (pos.len > 0 ? pos.len : 1);
		}
		// with the captured groups, as AS3 (Starling's AssetManager reads its name from group 2)
		var result = [regex.matched(0)];
		for (group in 1...groupCount + 1) {
			result.push(regex.matched(group));
		}
		return result;
		#end
	}

	#if (!js && !flash)
	// EReg has no group count: count the capturing ( outside escapes and classes, (?<name> included
	static function countCaptureGroups(pattern:String):Int {
		var count = 0;
		var inClass = false;
		var i = 0;
		while (i < pattern.length) {
			var c = pattern.charAt(i);
			if (c == "\\") {
				i += 2;
				continue;
			}
			if (inClass) {
				if (c == "]") inClass = false;
			} else if (c == "[") {
				inClass = true;
			} else if (c == "(") {
				if (pattern.charAt(i + 1) != "?") {
					count++;
				} else if ((pattern.charAt(i + 2) == "<" && pattern.charAt(i + 3) != "=" && pattern.charAt(i + 3) != "!")
					|| (pattern.charAt(i + 2) == "P" && pattern.charAt(i + 3) == "<")) {
					count++;
				}
			}
			i++;
		}
		return count;
	}
	#end

	public function test(s:String):Bool {
		#if (js || flash)
		return impl.test(s);
		#else
		return exec(s) != null;
		#end
	}

	// As AS3's String.match when nothing matches: null without the g flag (AGALMiniAssembler applies its
	// default mask then), [] with it
	public function match(s:String):Null<Array<String>> {
		#if flash
		return (cast s).match(impl);
		#elseif js
		var result = (cast s).match(impl);
		return if (result == null && impl.global) [] else result;
		#else
		if (!global) {
			var result = exec(s);
			return result == null ? null : cast result;
		}
		var out:Array<String> = [];
		var index = 0;
		while (regex.matchSub(s, index)) {
			var pos = regex.matchedPos();
			out.push(regex.matched(0));
			index = pos.pos + (pos.len > 0 ? pos.len : 1);
			if (index > s.length) break;
		}
		lastIndex = 0;
		return out;
		#end
	}

	public function search(s:String):Int {
		#if (js || flash)
		return (cast s).search(impl);
		#else
		return if (regex.match(s)) regex.matchedPos().pos else -1;
		#end
	}

	// TODO: have separate function for String and Function values of `by`?
	public function replace(s:String, by:EitherType<String, Function>):String {
		#if (js || flash)
		return (cast s).replace(impl, by);
		#else
		if (Reflect.isFunction(by)) {
			var fn:Dynamic = by;
			if (!regex.matchSub(s, 0)) return s;
			var pos = regex.matchedPos();
			var repl = Std.string(Reflect.callMethod(null, fn, [regex.matched(0), pos.pos, s]));
			return s.substr(0, pos.pos) + repl + s.substr(pos.pos + pos.len);
		}
		return regex.replace(s, cast by);
		#end
	}

	public function split(s:String):Array<String> {
		#if (js || flash)
		return (cast s).split(impl);
		#else
		return regex.split(s);
		#end
	}
}

#if js
abstract RegExpResult(RegExpMatch) from RegExpMatch to RegExpMatch {
	@:to public function toString():Null<String> return this != null ? this[0] : null;
}
#elseif flash
typedef RegExpResult = Dynamic;
#else
typedef RegExpResult = Array<String>;
#end
