package checks {
	public class Base {
		public static const BASE_VALUE:int = 21;
		public static var instances:int = 0;

		protected var mSize:Number;
		public var constructed:String = "base";

		public function Base(size:Number) {
			instances++;
			mSize = size;
			constructed += ":" + describe();
		}

		public function describe():String {
			return "base" + mSize;
		}

		public function get size():Number {
			return mSize;
		}

		public function set size(value:Number):void {
			mSize = value;
		}
	}
}
