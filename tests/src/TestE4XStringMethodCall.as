/**
 * Test case: String methods called on XML and XMLList (E4X CallMethod).
 * A method that XML/XMLList lacks is called on the string value of simple content,
 * as Starling's AssetManager does with `describeType(asset).@name.split("::")`.
 * Expected: `toString()` is inserted before the String method, instead of
 * typing `split` as a child list and failing to call it.
 */
package {
    public class TestE4XStringMethodCall {
        public function TestE4XStringMethodCall() {
            var typeXml:XML = <type name="flash.display::Sprite"/>;
            var shortName:String = typeXml.@name.split("::").pop();
            var lower:String = (typeXml.@name).toLowerCase();
            var index:int = typeXml.@name.indexOf("::");
            var node:XML = typeXml;
            var first:String = node.charAt(0);
            var children:XMLList = typeXml.children();
        }
    }
}
