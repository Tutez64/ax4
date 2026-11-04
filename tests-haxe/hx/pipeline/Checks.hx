package pipeline;

/** The cases the AS3 host prints: compiled to a SWC, linked in an AIR app, decompiled and converted. */
class Checks {
	public static function run():Array<String> {
		var out = [];
		var store = new Store();
		store.add("b", 2);
		store.add("a", 1);
		store.add("c", 3);
		var empty:Circle = Type.createEmptyInstance(Circle);
		out.push("empty=" + (empty.name == null ? "unset" : "set"));
		out.push("area=" + Math.round(new Circle(2).area() * 100));
		out.push("kinds=" + Tools.kindName(Kind.Small) + "," + Tools.kindName(Kind.Big(3)) + "," + Std.string(Kind.Big(4)));
		out.push("names=" + store.nameOf(1) + "," + store.nameOf(9));
		out.push("imap=" + store.sumMap(store.byName));
		out.push("scale=" + Tools.scale(3) + "," + Tools.scale(3, 5));
		out.push("radius=" + Tools.radiusOf(new Circle(7)));
		out.push("parse=" + Tools.safeParse("x") + "," + Tools.safeParse(""));
		out.push("count=" + Tools.count(4));
		out.push("emoji=" + Tools.emoji());
		out.push("nan=" + Math.isNaN(Math.NaN) + "," + (Math.POSITIVE_INFINITY > 0));
		var one = new Store();
		one.add("only", 5);
		out.push("smap=" + store.idOf("b") + "," + store.idOf("z") + "," + one.firstName());
		var c = new Circle(1);
		store.tag(c, "unit");
		out.push("omap=" + store.tagOf(c) + "," + store.tagOf(new Circle(1)));
		var shape:Shape = new Circle(2);
		var assigned = (shape.size = 4);
		out.push("props=" + shape.size + "," + assigned + "," + shape.label + "," + new Shape("s").label);
		store.reset();
		out.push("reset=" + store.idOf("a") + "," + store.nameOf(1));
		return out;
	}
}
