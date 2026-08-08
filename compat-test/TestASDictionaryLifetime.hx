#if (cpp || flash)
import utest.Assert.*;

// Lifetime checks for Dictionary values under a primitive key.
// cpp: validates the WeakMap primitiveStore optimization.
// flash: validates the native Dictionary reference semantics that optimization targets.
// js: skipped while primitiveStore uses a strong ObjectMap (haxe.ds.WeakMap unimplemented).

private typedef PrimitiveValueWeakRefImpl =
	#if cpp cpp.vm.WeakRef<Dynamic>
	#elseif flash ASDictionary<Dynamic, Bool>
	#end;

private abstract PrimitiveValueWeakRef(PrimitiveValueWeakRefImpl) {
	inline function new(value:PrimitiveValueWeakRefImpl) {
		this = value;
	}

	public static inline function of(value:Dynamic):PrimitiveValueWeakRef {
		#if cpp
		return new PrimitiveValueWeakRef(new cpp.vm.WeakRef(value));
		#elseif flash
		var watcher = new ASDictionary<Dynamic, Bool>(true);
		watcher[value] = true;
		return new PrimitiveValueWeakRef(watcher);
		#end
	}

	public inline function isAlive():Bool {
		#if cpp
		return this.get() != null;
		#elseif flash
		return this.keys().hasNext();
		#end
	}
}

private class PrimitiveValueProbe {
	public var state:String;

	public function new(state:String) {
		this.state = state;
	}
}

class TestASDictionaryLifetime extends utest.Test {
	function testPrimitiveKeyValueKeptWhileDictionaryIsAlive(
		#if flash async:utest.Async #end
	) {
		var retained = createRetainedPrimitiveValue();

		#if cpp
		forceCollection();
		isTrue(retained.value.isAlive());
		equals("alive", retained.dictionary[1].state);
		#elseif flash
		// Flash GC is incremental: wait a few frames so mark/sweep can finish.
		afterFlashCollection(async, function() {
			isTrue(retained.value.isAlive());
			equals("alive", retained.dictionary[1].state);
		});
		#end
	}

	function testPrimitiveKeyValueReleasedWithDictionary(
		#if flash async:utest.Async #end
	) {
		var value = createReleasedPrimitiveValue();

		#if cpp
		forceCollection();
		isFalse(value.isAlive());
		#elseif flash
		afterFlashCollection(async, function() {
			isFalse(value.isAlive());
		});
		#end
	}

	#if flash
	static function afterFlashCollection(async:utest.Async, body:()->Void):Void {
		var framesLeft = 4;
		function tick(_):Void {
			forceCollection();
			if (--framesLeft > 0) return;
			flash.Lib.current.removeEventListener(flash.events.Event.ENTER_FRAME, tick);
			body();
			async.done();
		}
		forceCollection();
		flash.Lib.current.addEventListener(flash.events.Event.ENTER_FRAME, tick);
	}
	#end

	static function forceCollection():Void {
		#if cpp
		cpp.vm.Gc.run(true);
		#elseif flash
		// Classic AVM2 kick to make collection more likely to run immediately.
		try {
			new flash.net.LocalConnection().connect("_ax4_force_gc");
			new flash.net.LocalConnection().connect("_ax4_force_gc");
		} catch (_:Dynamic) {}
		flash.system.System.gc();
		#end
	}

	static function createRetainedPrimitiveValue():{
		dictionary:ASDictionary<Dynamic, Dynamic>,
		value:PrimitiveValueWeakRef
	} {
		var dictionary = new ASDictionary<Dynamic, Dynamic>();
		var value:Dynamic = new PrimitiveValueProbe("alive");
		dictionary[1] = value;
		return {dictionary: dictionary, value: PrimitiveValueWeakRef.of(value)};
	}

	static function createReleasedPrimitiveValue():PrimitiveValueWeakRef {
		var dictionary = new ASDictionary<Dynamic, Dynamic>();
		var value:Dynamic = new PrimitiveValueProbe("released");
		dictionary[1] = value;
		var weakRef = PrimitiveValueWeakRef.of(value);
		// Drop strong locals before returning so residual stack refs are less likely.
		value = null;
		dictionary = null;
		return weakRef;
	}
}
#end
