import utest.Assert.*;
#if flash
import flash.utils.Proxy;
#end

class TestASProxyBase extends utest.Test {
	function testProxyHooksThroughASCompat() {
		var p = new CountingProxy();

		#if flash
		p.setProperty("x", 10);
		equals(1, p.setCalls);
		equals(10, p.getProperty("x"));
		equals(1, p.getCalls);

		isTrue(p.deleteProperty("x"));
		equals(1, p.deleteCalls);
		equals(null, p.getProperty("x"));
		equals(2, p.getCalls);
		#else
		equals(10, ASCompat.setProperty(p, "x", 10));
		equals(1, p.setCalls);
		equals(10, ASCompat.getProperty(p, "x"));
		equals(1, p.getCalls);

		isTrue(ASCompat.deleteProperty(p, "x"));
		equals(1, p.deleteCalls);
		equals(null, ASCompat.getProperty(p, "x"));
		equals(2, p.getCalls);
		#end
	}

	function testProxyHooksThroughASAny() {
		var raw = new CountingProxy();
		#if flash
		raw.setProperty("k", 7);
		equals(1, raw.setCalls);

		var value = raw.getProperty("k");
		equals(7, value);
		equals(1, raw.getCalls);

		isTrue(raw.deleteProperty("k"));
		equals(1, raw.deleteCalls);
		#else
		var p:ASAny = raw;

		p["k"] = 7;
		equals(1, raw.setCalls);

		var value = p["k"];
		equals(7, value);
		equals(1, raw.getCalls);

		isTrue(ASCompat.deleteProperty(p, "k"));
		equals(1, raw.deleteCalls);
		#end
	}

	function testFallbackForPlainObject() {
		var o:Dynamic = {};

		equals(3, ASCompat.setProperty(o, "a", 3));
		equals(3, ASCompat.getProperty(o, "a"));
		isTrue(ASCompat.deleteProperty(o, "a"));
		equals(null, ASCompat.getProperty(o, "a"));
	}

	function testPlainClassWithProxyNamedMethodsIsNotAProxy() {
		var o = new NotAProxy();
		equals(1, ASCompat.getProperty(o, "value"));
		equals(2, ASCompat.setProperty(o, "value", 2));
		equals(2, o.value);
		equals(0, o.hookCalls);
	}
}

private class NotAProxy {
	public var value:Int = 1;
	public var hookCalls:Int = 0;

	public function new() {}

	public function getProperty(name:Dynamic):Dynamic {
		hookCalls++;
		return null;
	}

	public function setProperty(name:Dynamic, value:Dynamic):Void {
		hookCalls++;
	}
}

private class CountingProxy extends ProxyBase {
	var data:ASObject = {};
	public var getCalls:Int = 0;
	public var setCalls:Int = 0;
	public var deleteCalls:Int = 0;

	public function new() {
		super();
	}

	#if flash
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy")
	#end
	override public function getProperty(name:Dynamic):Dynamic {
		getCalls++;
		return data[Std.string(name)];
	}

	#if flash
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy")
	#end
	override public function setProperty(name:Dynamic, value:Dynamic):Void {
		setCalls++;
		data[Std.string(name)] = value;
	}

	#if flash
	@:ns("http://www.adobe.com/2006/actionscript/flash/proxy")
	#end
	override public function deleteProperty(name:Dynamic):Bool {
		deleteCalls++;
		return ASCompat.deleteProperty(data, name);
	}
}

#if flash
private class ProxyBase extends Proxy {
	public function new() {
		super();
	}
}
#else
private class ProxyBase extends ASProxyBase {}
#end
