#if openfl
private typedef Dictionary<K,V> = openfl.utils.Dictionary<K,V>;
#else
private typedef Dictionary<K,V> = flash.utils.Dictionary;
#end

abstract ASDictionary<K,V>(Dictionary<K,V>) from Dictionary<K,V> to Dictionary<K,V> { //TODO: remove implicit cast?
	#if !flash
	#if cpp
	static final primitiveStore:haxe.ds.WeakMap<{}, haxe.ds.StringMap<ASDictionaryPrimitiveEntry>> = new haxe.ds.WeakMap();
	#else
	static final primitiveStore:haxe.ds.ObjectMap<Dynamic, haxe.ds.StringMap<ASDictionaryPrimitiveEntry>> = new haxe.ds.ObjectMap();
	#end

	static inline function isPrimitiveKey(key:Dynamic):Bool {
		#if cpp
		// one virtual call, where each Std.isOfType against a runtime class is a generic type test
		return ASDictionaryPrimitiveEntry.isPrimitiveType(key);
		#else
		return Std.isOfType(key, String) || Std.isOfType(key, Int) || Std.isOfType(key, Float) || Std.isOfType(key, Bool);
		#end
	}

	static function primitiveKeyId(key:Dynamic):String {
		#if cpp
		if (untyped __cpp__("({0}.mPtr->__GetType() == vtString)", key)) {
			return key;
		}
		if (untyped __cpp__("({0}.mPtr->__GetType() == vtInt)", key)) {
			var n:Int = key;
			if (n >= 0 && n < SMALL_INT_IDS) {
				return smallIntId(n);
			}
		}
		#end
		if (Std.isOfType(key, Float)) {
			var n:Float = key;
			if (Math.isNaN(n)) return "NaN";
			if (!Math.isFinite(n)) return n > 0 ? "Infinity" : "-Infinity";
		}
		// Match Flash Dictionary semantics for primitive keys:
		// numeric/string/bool keys are effectively compared by string form.
		return ASCompat.toString(key);
	}

	#if cpp
	static inline final SMALL_INT_IDS = 1024;
	static final smallIntIds:Array<String> = [];

	static function intKeyId(n:Int):String {
		return n >= 0 && n < SMALL_INT_IDS ? smallIntId(n) : Std.string(n);
	}

	// The id of a small int key, kept: converting it on each access allocated a string.
	static function smallIntId(n:Int):String {
		var id = smallIntIds[n];
		if (id == null) {
			id = Std.string(n);
			smallIntIds[n] = id;
		}
		return id;
	}
	#end

	inline function getPrimitiveEntries(createIfMissing:Bool):Null<haxe.ds.StringMap<ASDictionaryPrimitiveEntry>> {
		var mapKey:Dynamic = this;
		var entries = primitiveStore.get(mapKey);
		if (entries == null && createIfMissing) {
			entries = new haxe.ds.StringMap<ASDictionaryPrimitiveEntry>();
			primitiveStore.set(mapKey, entries);
		}
		return entries;
	}
	#end

	public extern inline function new(weakKeys : Bool = false) {
		this = new Dictionary<K,V>(weakKeys);
	}

	@:op([]) public inline function get(key:K):Null<V> {
		#if flash
		return untyped this[key];
		#else
		var result:Dynamic = null;
		if (isPrimitiveKey(key)) {
			var entries = getPrimitiveEntries(false);
			if (entries != null) {
				var entry = entries.get(primitiveKeyId(key));
				if (entry != null) {
					result = entry.value;
				} else {
					#if js
					result = js.Syntax.code("undefined");
					#else
					result = ASCompat.UNDEFINED;
					#end
				}
			} else {
				#if js
				result = js.Syntax.code("undefined");
				#else
				result = ASCompat.UNDEFINED;
				#end
			}
		} else {
			#if cpp
			result = this.exists(key) ? this.get(key) : ASCompat.UNDEFINED;
			#elseif js
			result = key != null && this.exists(key) ? this.get(key) : js.Syntax.code("undefined");
			#else
			result = this.get(key);
			#end
		}
		return cast result;
		#end
	}

	#if flash
	// Dynamic: a value typed by a type parameter here would turn undefined into null.
	public static inline function getString(dict:Dynamic, key:String):Dynamic {
		return untyped dict[key];
	}

	public static inline function getInt(dict:Dynamic, key:Int):Dynamic {
		return untyped dict[key];
	}
	#else
	/** `dict[key]` for a key known to be a String. On C++ it skips boxing the key and testing its type at runtime. **/
	public static inline function getString<K,V>(dict:ASDictionary<K,V>, key:String):Null<V> {
		#if cpp
		if (key == null) {
			return dict.get(cast key);
		}
		var entries = dict.getPrimitiveEntries(false);
		var entry = entries != null ? entries.get(key) : null;
		var result:Dynamic = entry != null ? entry.value : ASCompat.UNDEFINED;
		return cast result;
		#else
		return dict.get(cast key);
		#end
	}

	/** `dict[key]` for a key known to be an int. On C++ it skips boxing the key and testing its type at runtime. **/
	public static inline function getInt<K,V>(dict:ASDictionary<K,V>, key:Int):Null<V> {
		#if cpp
		var entries = dict.getPrimitiveEntries(false);
		var entry = entries != null ? entries.get(intKeyId(key)) : null;
		var result:Dynamic = entry != null ? entry.value : ASCompat.UNDEFINED;
		return cast result;
		#else
		return dict.get(cast key);
		#end
	}
	#end

	@:op([]) public inline function set(key:K, value:V):Null<V> {
		#if flash
		return untyped this[key] = value;
		#else
		var result:Dynamic = null;
		if (isPrimitiveKey(key)) {
			var entries = getPrimitiveEntries(true);
			entries.set(primitiveKeyId(key), new ASDictionaryPrimitiveEntry(key, value));
			result = value;
		} else {
			result = this.set(key, value);
		}
		return cast result;
		#end
	}

	public inline function exists(key:K):Bool {
		#if flash
		return untyped __in__(key, this);
		#else
		var result = false;
		if (isPrimitiveKey(key)) {
			var entries = getPrimitiveEntries(false);
			result = entries != null && entries.exists(primitiveKeyId(key));
		} else {
			result = this.exists(key);
		}
		return result;
		#end
	}

	public inline function hasOwnProperty(key:K):Bool {
		return exists(key);
	}

	public inline function remove(key:K):Bool {
		#if flash
		return untyped __delete__(this, key);
		#else
		var result = false;
		if (isPrimitiveKey(key)) {
			var entries = getPrimitiveEntries(false);
			result = entries != null && entries.remove(primitiveKeyId(key));
		} else {
			result = this.remove(key);
		}
		return result;
		#end
	}

	public inline function keys():Iterator<K> {
		#if flash
		return new NativePropertyIterator<K>(this);
		#else
		var result:Dynamic = null;
		var entries = getPrimitiveEntries(false);
		if (entries == null || !entries.keys().hasNext()) {
			result = this.iterator();
		} else {
			var merged:Array<K> = [for (k in this.iterator()) k];
			for (entry in entries) {
				merged.push(cast entry.key);
			}
			result = merged.iterator();
		}
		return cast result;
		#end
	}

	public inline function iterator():Iterator<V> {
		#if flash
		return new NativeValueIterator<V>(this);
		#else
		var result:Dynamic = null;
		var entries = getPrimitiveEntries(false);
		if (entries == null || !entries.keys().hasNext()) {
			result = this.each();
		} else {
			var merged:Array<V> = [for (v in this.each()) v];
			for (entry in entries) {
				merged.push(cast entry.value);
			}
			result = merged.iterator();
		}
		return cast result;
		#end
	}

	public inline function keyValueIterator():KeyValueIterator<K,V> {
		#if flash
		return cast new NativePropertyValueIterator<K,V>(this);
		#else
		var pairs:Array<{key:K, value:V}> = [for (key in keys()) {key: key, value: this[key]}];
		return cast pairs.iterator();
		#end
	}

	#if !flash
	/**
		`exists` for a dictionary only known at runtime: typed as `ASDictionary<Dynamic, Dynamic>`,
		openfl's Dictionary would read it as a StringMap.
	**/
	public static function existsIn(map:haxe.Constraints.IMap<Dynamic, Dynamic>, key:Dynamic):Bool {
		if (isPrimitiveKey(key)) {
			var entries = primitiveStore.get(map);
			return entries != null && entries.exists(primitiveKeyId(key));
		}
		return map.exists(key);
	}

	/** `[]=` for a dictionary only known at runtime, see `existsIn`. **/
	public static function setIn(map:haxe.Constraints.IMap<Dynamic, Dynamic>, key:Dynamic, value:Dynamic):Void {
		if (isPrimitiveKey(key)) {
			var entries = primitiveStore.get(map);
			if (entries == null) {
				entries = new haxe.ds.StringMap<ASDictionaryPrimitiveEntry>();
				primitiveStore.set(map, entries);
			}
			entries.set(primitiveKeyId(key), new ASDictionaryPrimitiveEntry(key, value));
		} else {
			map.set(key, value);
		}
	}

	/** `keys` for a dictionary only known at runtime, see `existsIn`. **/
	public static function keysIn(map:haxe.Constraints.IMap<Dynamic, Dynamic>):Iterator<Dynamic> {
		var entries = primitiveStore.get(map);
		if (entries == null) {
			return map.keys();
		}
		var merged:Array<Dynamic> = [for (k in map.keys()) k];
		for (entry in entries) {
			merged.push(entry.key);
		}
		return merged.iterator();
	}

	/** `iterator` for a dictionary only known at runtime, see `existsIn`. **/
	public static function valuesIn(map:haxe.Constraints.IMap<Dynamic, Dynamic>):Iterator<Dynamic> {
		var entries = primitiveStore.get(map);
		if (entries == null) {
			return map.iterator();
		}
		var merged:Array<Dynamic> = [for (v in map) v];
		for (entry in entries) {
			merged.push(entry.value);
		}
		return merged.iterator();
	}

	/** `remove` for a dictionary only known at runtime, see `existsIn`. **/
	public static function removeIn(map:haxe.Constraints.IMap<Dynamic, Dynamic>, key:Dynamic):Bool {
		if (isPrimitiveKey(key)) {
			var entries = primitiveStore.get(map);
			return entries != null && entries.remove(primitiveKeyId(key));
		}
		return map.remove(key);
	}

	/** `[]` for a dictionary only known at runtime, see `existsIn`. **/
	public static function getIn(map:haxe.Constraints.IMap<Dynamic, Dynamic>, key:Dynamic):Dynamic {
		if (existsIn(map, key)) {
			if (isPrimitiveKey(key)) {
				var entry = primitiveStore.get(map).get(primitiveKeyId(key));
				return entry.value;
			}
			return map.get(key);
		}
		#if js
		return js.Syntax.code("undefined");
		#else
		return ASCompat.UNDEFINED;
		#end
	}
	#end

	public static inline function asDictionary<K,V>(v:Any):Null<Dictionary<K,V>> {
		#if flash
		return flash.Lib.as(v, flash.utils.Dictionary);
		#else
		return if (Std.isOfType(v, haxe.Constraints.IMap)) v else null;
		#end
	}

	public static final type = #if flash flash.utils.Dictionary #else haxe.Constraints.IMap #end;
}

#if !flash
/** The key and value of an ASDictionary entry whose key is a String, Number, int or Boolean. **/
@:noCompletion final class ASDictionaryPrimitiveEntry {
	public final key:Dynamic;
	public final value:Dynamic;

	public function new(key:Dynamic, value:Dynamic) {
		this.key = key;
		this.value = value;
	}

	#if cpp
	public static function isPrimitiveType(key:Dynamic):Bool {
		if (untyped __cpp__("!{0}.mPtr", key)) {
			return false;
		}
		var type:Int = untyped __cpp__("{0}.mPtr->__GetType()", key);
		var primitive:Bool = untyped __cpp__("({0} == vtString || {0} == vtInt || {0} == vtFloat || {0} == vtBool)", type);
		return primitive;
	}
	#end
}
#end
