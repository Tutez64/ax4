/**
 * Test case: AS3 subtracts uints as Numbers, Haxe's UInt wraps.
 * Starling's Color.interpolate: `startRed + (endRed - startRed) * ratio` with endRed < startRed.
 * Expected: the uint operands become Floats `((endRed : Float) - (startRed : Float))`; int - int stays an Int.
 */
package {
    public class TestUintSubtraction {
        public function TestUintSubtraction(startRed:uint, endRed:uint, ratio:Number, count:int) {
            var red:uint = startRed + (endRed - startRed) * ratio;
            var left:int = Math.max(endRed - startRed, 0);
            var mixed:Number = count - startRed;
            var ints:int = count - 1;
        }
    }
}
