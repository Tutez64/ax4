/**
 * Test case: AS3's `>>>` gives a uint (Haxe's an Int).
 * `(pixel >>> 0).toString(16)` must print ffff8800 for 0xFFFF8800, not -7800.
 * Expected: `(pixel >>> 0 : UInt)`, still usable in bit operations.
 */
package {
    public class TestUshrUint {
        public function TestUshrUint(pixel:int) {
            var hex:String = (pixel >>> 0).toString(16);
            var alpha:uint = pixel >>> 24;
            var mixed:int = (pixel >>> 8) & 0xFF;
        }
    }
}
