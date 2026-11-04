/**
	The keys and values of a Haxe map, in place of the flash storage (StringMap.h, IntMap.h...) that
	code compiled with Haxe iterates with the hasnext2 instruction (see ASCompat.nextIndex).

	It is a map itself, as the converted code can declare the storage with its flash type
	(Dictionary): an hxcpp interface variable holds null for an object not implementing it.
**/
class ASHaxeMapStorage implements haxe.Constraints.IMap<Dynamic, Dynamic> {
	public final keyList:Array<Dynamic> = [];
	public final valueList:Array<Dynamic> = [];

	public function new(?map:haxe.Constraints.IMap<Dynamic, Dynamic>) {
		if (map != null) {
			for (key in map.keys()) {
				keyList.push(key);
				valueList.push(map.get(key));
			}
		}
	}

	public function get(k:Dynamic):Null<Dynamic> {
		var i = keyList.indexOf(k);
		return i < 0 ? null : valueList[i];
	}

	public function set(k:Dynamic, v:Dynamic):Void {
		var i = keyList.indexOf(k);
		if (i < 0) {
			keyList.push(k);
			valueList.push(v);
		} else {
			valueList[i] = v;
		}
	}

	public function exists(k:Dynamic):Bool {
		return keyList.indexOf(k) >= 0;
	}

	public function remove(k:Dynamic):Bool {
		var i = keyList.indexOf(k);
		if (i < 0) {
			return false;
		}
		keyList.splice(i, 1);
		valueList.splice(i, 1);
		return true;
	}

	public function keys():Iterator<Dynamic> {
		return keyList.iterator();
	}

	public function iterator():Iterator<Dynamic> {
		return valueList.iterator();
	}

	public function keyValueIterator():KeyValueIterator<Dynamic, Dynamic> {
		return new haxe.iterators.MapKeyValueIterator(this);
	}

	public function copy():haxe.Constraints.IMap<Dynamic, Dynamic> {
		var c = new ASHaxeMapStorage();
		for (i in 0...keyList.length) {
			c.set(keyList[i], valueList[i]);
		}
		return c;
	}

	public function toString():String {
		return "[" + [for (i in 0...keyList.length) keyList[i] + " => " + valueList[i]].join(", ") + "]";
	}

	public function clear():Void {
		keyList.resize(0);
		valueList.resize(0);
	}
}
