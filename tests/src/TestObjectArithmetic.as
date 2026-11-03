package {
	public class TestObjectArithmetic {
		public function scale(x:Number, factor:Object = null):Number {
			if (factor == null) {
				factor = 2;
			}
			return x * factor - factor % 3;
		}
	}
}
