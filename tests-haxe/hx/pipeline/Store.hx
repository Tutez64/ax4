package pipeline;

import haxe.ds.StringMap;
import haxe.ds.IntMap;
import haxe.ds.ObjectMap;

/** The map methods Haxe inlines on flash: their compiled code reads the maps' storage. */
class Store {
	public var byName:StringMap<Int> = new StringMap();
	public var byId:IntMap<String> = new IntMap();
	public var tags:ObjectMap<Circle, String> = new ObjectMap();

	public function new() {
	}

	public function add(name:String, id:Int):Void {
		byName.set(name, id);
		byId.set(id, name);
	}

	public function nameOf(id:Int):String {
		return byId.exists(id) ? byId.get(id) : "?";
	}

	public function idOf(name:String):Int {
		return byName.exists(name) ? byName.get(name) : -1;
	}

	public function firstName():String {
		return first(byName.keys());
	}

	static function first(it:Iterator<String>):String {
		return it.hasNext() ? it.next() : "-";
	}

	public function tag(c:Circle, s:String):Void {
		tags.set(c, s);
	}

	public function tagOf(c:Circle):String {
		return tags.exists(c) ? tags.get(c) : "none";
	}

	public function reset():Void {
		byName.clear();
		byId.clear();
	}

	/** Inlined iterations: Haxe iterates the maps' storage with hasnext2, which FFDec prints as §§hasnext. */
	public function total():Int {
		var t = 0;
		for (k in byName.keys()) t += byName.get(k);
		return t;
	}

	public function joinedNames():String {
		var names = [for (name in byId) name];
		names.sort(Reflect.compare);
		return names.join("+");
	}

	/** Through an unchecked cast, the decompiled code reads the storage of a map typed IMap. */
	public var anyMap:haxe.Constraints.IMap<Int, String> = new IntMap<String>();

	public function putAny(k:Int, v:String):Void {
		var m:IntMap<String> = cast anyMap;
		m.set(k, v);
	}

	public function anyKeys():String {
		var it:Iterator<Int> = (cast anyMap : IntMap<String>).keys();
		var ks = [];
		while (it.hasNext()) ks.push(it.next());
		ks.sort(Reflect.compare);
		return ks.join("+");
	}

	public function sumMap(m:haxe.Constraints.IMap<String, Int>):Int {
		var t = 0;
		for (k in m.keys()) t += m.get(k);
		return t;
	}
}
