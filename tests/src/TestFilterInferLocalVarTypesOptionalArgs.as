/**
 * Test case: InferLocalVarTypes, a local function with default arguments.
 * Starling's AssetManager assigns `function(name:String = null, asset:Object = null, type:String = null)`
 * to a local and calls it with no arguments. A Haxe function type has no optional arguments.
 * Expected: the local is an ASFunction, not `(String, ASObject, String) -> Void`.
 */
package {
    public class TestFilterInferLocalVarTypesOptionalArgs {
        public function TestFilterInferLocalVarTypesOptionalArgs() {
            var onLoaded:* = function(name:String = null, asset:Object = null):void {
            };
            onLoaded();
            onLoaded("a", {});
            var onDone:* = function(name:String):void {
            };
            onDone("b");
        }
    }
}
