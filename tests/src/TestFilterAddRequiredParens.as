/**
 * Test case: AddRequiredParens, comparisons inside equalities.
 * AS3 binds `>` tighter than `==`; Haxe gives them one left-associative level.
 * `a == b > 0` (Starling's Earcut: `clockwise == signedArea(...) > 0`) must become `a == (b > 0)`,
 * and `a > c != b > c` is `a > c != (b > c)`; a comparison on the left needs no parens.
 */
package {
    public class TestFilterAddRequiredParens {
        public function TestFilterAddRequiredParens(clockwise:Boolean, area:Number, a:Number, b:Number, c:Number) {
            var same:Boolean = clockwise == area > 0;
            var crosses:Boolean = a > c != b > c;
            var left:Boolean = a > c == clockwise;
        }
    }
}
