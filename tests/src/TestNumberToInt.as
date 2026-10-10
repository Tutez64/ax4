/**
 * Test case: Number values used where an int/uint is expected.
 * CoerceToNumber converts them with ASCompat.floatToInt (AS3 int() semantics).
 */
package {
    public class TestNumberToInt {
        public function TestNumberToInt() {
            var n:Number = 10.5;
            var i:int = n;
            
            var arr:Array = [1, 2, 3];
            var val:* = arr[n];
            
            var s:String = "abc";
            var char:* = s.charAt(n);

            takeInt(n);

            var bigDec:* = 2303741511;
            var bigHex:* = 0xFFFFFFFF;
            takeUInt(bigDec);
            takeUInt(bigHex);
        }

        public function takeInt(val:int):void {}

        public function takeUInt(val:uint):void {}
    }
}
