package pipeline;

class Circle extends Shape {
	public var radius:Float;

	public function new(radius:Float) {
		super("circle");
		this.radius = radius;
	}

	override function get_label():String {
		return "circle " + radius;
	}

	override public function area():Float {
		return Math.PI * radius * radius;
	}
}
