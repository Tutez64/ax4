package checks {
	/** Static initialization order, inheritance, accessors, super calls and interfaces. */
	public class Classes {
		// read before it is initialized: it is still 0 then
		public static var LATER_PLUS_ONE:int = LATER + 1;
		public static var LATER:int = 5;
		public static const NAMES:Array = ["x", "y"];
		public static const FIRST:String = NAMES[0];
		public static var fromOther:int = Base.BASE_VALUE * 2;

		public static function run(out:Array):void {
			out.push("staticOrder=" + LATER_PLUS_ONE + "," + LATER + "," + FIRST + "," + fromOther);
			var d:Derived = new Derived(3);
			var asBase:Base = d;
			out.push("override=" + asBase.describe() + "," + d.describeBase() + "," + (asBase is Derived) + "," + (asBase is INamed) + "," + INamed(asBase).name);
			d.size = 4;
			out.push("accessors=" + d.size + "," + d.setCount + "," + (d.size = 9) + "," + d.setCount);
			out.push("fieldInit=" + d.doubled + "," + d.constructed + "," + Base.instances);
			var plain:Base = new Base(1);
			out.push("baseOnly=" + plain.describe() + "," + (plain is INamed) + "," + ((plain as INamed) == null) + "," + Base.instances);
			var cls:Class = Derived;
			var made:Object = new cls(2);
			out.push("classValue=" + (made is Derived) + "," + Derived(made).describe() + "," + (Object(d).constructor == Derived));
			var o:Object = d;
			out.push("dynamicCall=" + o.describe() + "," + o.size + "," + o["name"]);
		}
	}
}
