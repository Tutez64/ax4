package {
	public class TestNamespaceNew {
		public function builtin(obj:Object, name:String):* {
			return obj[new QName(new Namespace("http://adobe.com/AS3/2006/builtin"), name)];
		}
	}
}
