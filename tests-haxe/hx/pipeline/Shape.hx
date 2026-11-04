package pipeline;

class Shape {
	/** Properties with @:flash.property also compile to flash accessors calling get_x and set_x, for AS3 code. */
	public var name:String;
	@:flash.property public var size(get, set):Int;
	@:flash.property public var label(get, never):String;

	var storedSize = 1;

	function get_size():Int {
		return storedSize;
	}

	function set_size(v:Int):Int {
		storedSize = v * 10;
		return v;
	}

	function get_label():String {
		return "shape";
	}

	public function new(name:String) {
		this.name = name;
	}

	public function area():Float {
		return 0;
	}
}
