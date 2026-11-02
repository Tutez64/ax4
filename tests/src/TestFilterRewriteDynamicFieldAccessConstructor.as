/**
 * Test case: AS3's `o.constructor`, the class of an instance (Starling's TextFormat.clone:
 * `new (Object(this).constructor as Class)()`). It is a dynamic field in Haxe, which reads null.
 * Expected: ASCompat.constructorOf(this).
 */
package {
    public class TestFilterRewriteDynamicFieldAccessConstructor {
        public function clone():TestFilterRewriteDynamicFieldAccessConstructor {
            var cls:Class = Object(this).constructor as Class;
            return new cls() as TestFilterRewriteDynamicFieldAccessConstructor;
        }
    }
}
