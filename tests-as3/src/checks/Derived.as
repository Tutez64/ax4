package checks {
	public class Derived extends Base implements INamed {
		// initialized before the constructor body, so before super() runs describe()
		public var doubled:Number = BASE_VALUE * 2;
		public var setCount:int;

		public function Derived(size:Number) {
			super(size * 10);
		}

		// called by the base constructor, while doubled is already set
		override public function describe():String {
			return "derived" + mSize + "/" + doubled;
		}

		public function describeBase():String {
			return super.describe();
		}

		override public function set size(value:Number):void {
			setCount++;
			super.size = value + 1;
		}

		public function get name():String {
			return "named" + size;
		}
	}
}
