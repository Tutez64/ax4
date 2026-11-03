package {
	public class TestHaxeMathStatics {
		public function isValid(x:Number):Boolean {
			return !(Math.isNaN(x) || x == Math.NEGATIVE_INFINITY || x == Math.POSITIVE_INFINITY) && Math.isFinite(x);
		}

		public function nan():Number {
			return Math.NaN;
		}
	}
}
