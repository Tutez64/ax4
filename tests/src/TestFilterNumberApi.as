/**
 * Test case for NumberApi filter.
 * Covers:
 * - toFixed/toPrecision/toExponential on a Number: ASCompat.toFixed(n, digits)...
 * - The same methods on an untyped (*) or Object value, which may hold a Number: a Number has
 *   no methods outside flash and JS, so they become ASCompat.callNumberMethod(v, "toFixed", digits),
 *   which calls the object's own method otherwise.
 * - int.MAX_VALUE/MIN_VALUE and Number.MAX_VALUE/MIN_VALUE/POSITIVE_INFINITY/NEGATIVE_INFINITY.
 */
package {
    public class TestFilterNumberApi {
        public function TestFilterNumberApi() {
            var n:Number = 1.25;
            var a:String = n.toFixed(1);
            var b:String = n.toFixed();
            var c:String = n.toPrecision(3);

            var d:String = format(1.25);
            var obj:Object = 2.5;
            var f:String = obj.toPrecision(2);

            var g:int = int.MAX_VALUE;
            var h:Number = Number.POSITIVE_INFINITY;
        }

        private function format(value:*):String {
            return value.toFixed(1) + value.toExponential();
        }
    }
}
