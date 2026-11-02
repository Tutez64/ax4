#if flash
typedef ASFunction = flash.utils.Function;
#else
@:callable
abstract ASFunction(Dynamic)
	from haxe.Constraints.Function
	to haxe.Constraints.Function

	// to haxe.Constraints.Function is not enough for unifying with actual function types
	// so we have to do this ¯\_(ツ)_/¯
	to ()->Dynamic
	to (Dynamic)->Dynamic
	to (Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic,Dynamic,Dynamic)->Dynamic
	to (Dynamic,Dynamic,Dynamic,Dynamic,Dynamic,Dynamic)->Dynamic
{

	#if (js || cpp)
	// AS3's Function.length: Starling's EventDispatcher calls a listener without the event when it is 0
	public var length(get, never): Int;
	#end

	#if js
	private function get_length(): Int {
		return (this : Dynamic).length;
	}
	#elseif cpp
	private function get_length(): Int {
		// hxcpp closures know their arity (local functions and method closures alike)
		final f:Dynamic = this;
		return untyped f.__ArgCount();
	}
	#end

}
#end