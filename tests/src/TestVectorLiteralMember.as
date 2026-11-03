package {
	public class TestVectorLiteralMember {
		public function joined(a:String, rest:Vector.<String>):Vector.<String> {
			return new <String>[a].concat(rest);
		}

		public function count(a:int):int {
			return new <int>[a, a].length;
		}
	}
}
