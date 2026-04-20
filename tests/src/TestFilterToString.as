/**
 * Test case for ToString filter.
 * Covers:
 * - Error.toString() should be rewritten to Std.string to avoid missing method on flash.errors.Error.
 * - Custom class with its own toString should remain unchanged.
 * - Primitive toString() and radix toString() stay mapped correctly.
 * - String concatenation with dynamic values should stringify dynamic operands to avoid hxcpp invalid numeric branch.
 * - Array values passed where String is expected should be coerced through ASCompat.toString.
 */
package {
    public class TestFilterToString {
        public function TestFilterToString() {
            var err:Error = new Error("boom");
            var msg:String = err.toString();
            trace(msg);

            var custom:HasToString = new HasToString();
            trace(custom.toString());

            var num:int = 255;
            trace(num.toString());
            trace(num.toString(16));

            var flag:Boolean = true;
            trace(flag.toString());

            var any:* = {};
            any.value = 42;
            var dyn:* = passthrough(any.value);
            trace("prefix=" + dyn);
            trace(dyn + "=suffix");

            var values:Array = ["a", "b"];
            takesString(values);
        }

        private function passthrough(value:*):* {
            return value;
        }

        private function takesString(value:String):void {
            trace(value);
        }
    }
}
