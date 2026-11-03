/**
 * Test case: AddRequiredParens, comparisons inside equalities.
 * AS3 binds `>` tighter than `==`; Haxe gives them one left-associative level.
 * `a == b > 0` (Starling's Earcut: `clockwise == signedArea(...) > 0`) must become `a == (b > 0)`,
 * and `a > c != b > c` is `a > c != (b > c)`; a comparison on the left needs no parens.
 * Haxe also puts & ^ | on one left-associative level above the comparisons, AS3 binds & over ^ over |
 * below them: `c << 8 & m | alpha & 0xFF` (Starling's VertexData.colorize) must become
 * `c << 8 & m | (alpha & 0xFF)`, and `flags ^ alpha & 0xF0` must become `flags ^ (alpha & 0xF0)`.
 */
package {
    public class TestFilterAddRequiredParens {
        public function TestFilterAddRequiredParens(clockwise:Boolean, area:Number, a:Number, b:Number, c:Number) {
            var same:Boolean = clockwise == area > 0;
            var crosses:Boolean = a > c != b > c;
            var left:Boolean = a > c == clockwise;
            var color:uint = 0xFFFFFF, alpha:int = 255, flags:int = 3;
            var rgba:uint = color << 8 & 0xFFFFFF00 | alpha & 0xFF;
            var mixed:int = flags ^ alpha & 0xF0;
            var tested:int = flags & alpha == 255;
        }
    }
}
