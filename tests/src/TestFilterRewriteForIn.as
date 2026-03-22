/**
 * Test case for RewriteForIn filter.
 * `for each` over Object should use a runtime helper so Object-typed Arrays still iterate as arrays.
 * `for in` over Object should iterate keys.
 */
package {
    public class TestFilterRewriteForIn {
        public function TestFilterRewriteForIn() {
            var obj:Object = { "a": 1, "b": 2 };
            var arrAsObject:Object = [3, 4];
            var sum:int = 0;

            // Object literals should still iterate values.
            for each (var v:* in obj) {
                sum += int(v);
            }

            // Object-typed arrays must keep array iteration at runtime.
            for each (var arrValue:* in arrAsObject) {
                sum += int(arrValue);
            }

            // Key iteration for Object should use keys/___keys() in Haxe.
            for (var k:String in obj) {
                sum += k.length;
            }
        }
    }
}
