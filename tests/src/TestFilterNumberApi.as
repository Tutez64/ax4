/**
 * Test case for NumberApi filter.
 * Covers:
 * - toFixed/toPrecision/toExponential on a Number: ASCompat.toFixed(n, digits)...
 * - The same methods on an untyped (*) or Object value, which may hold a Number: a Number has
 *   no methods outside flash and JS, so they become ASCompat.callNumberMethod(v, "toFixed", digits),
 *   which calls the object's own method otherwise.
 * - int.MAX_VALUE/MIN_VALUE, uint.MAX_VALUE/MIN_VALUE (ASCompat.MAX_UINT/MIN_UINT, not int's), and
 *   Number.MAX_VALUE/MIN_VALUE, with POSITIVE_INFINITY/NEGATIVE_INFINITY as Math's (not MAX/MIN_VALUE).
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
            var hn:Number = Number.NEGATIVE_INFINITY;
            var hu:uint = uint.MAX_VALUE;
            var hz:uint = uint.MIN_VALUE;
        }

        private function format(value:*):String {
            return value.toFixed(1) + value.toExponential();
        }
    }
}
