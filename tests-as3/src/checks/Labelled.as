package checks {
	/** A class with toString and valueOf, read through implicit conversions. */
	public class Labelled {
		private var mName:String;

		public function Labelled(name:String) {
			mName = name;
		}

		public function toString():String {
			return "<" + mName + ">";
		}

		public function valueOf():Object {
			return 41;
		}
	}
}
