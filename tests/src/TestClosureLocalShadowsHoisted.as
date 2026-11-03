package {
	public class TestClosureLocalShadowsHoisted {
		public function run(items:Array):int {
			var f:Function = function(o:Object):int {
				var n:String = String(o);
				return n.length;
			};
			var n:Array = items;
			return f(n[0]);
		}
	}
}
