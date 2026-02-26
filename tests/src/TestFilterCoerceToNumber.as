/**
 * Test case for CoerceToNumber filter.
 * Covers:
 * - ASAny to int/uint/Number in assignments and args.
 * - String/Boolean to int/uint/Number.
 * - Number to int/uint truncation.
 * - Field access on * typed objects (uses toNumberField for undefined handling).
 */
package {
    public class TestFilterCoerceToNumber {
        public function TestFilterCoerceToNumber() {
            var any:* = "42";
            var num:Number = any;
            var i:int = any;
            var u:uint = any;

            var s:String = "7";
            var i2:int = s;
            var n2:Number = s;

            var b:Boolean = true;
            var i3:int = b;
            var u3:uint = b;

            var f:Number = 3.9;
            var i4:int = f;
            var u4:uint = f;

            var b2:Boolean = false;
            var cmp1:Boolean = b2 > 1;
            var cmp2:Boolean = 2 < b2;
            var cmp3:Boolean = b2 >= 0;
            var cmp4:Boolean = 0 <= b2;

            takesInt(any);
            takesUInt(any);
            takesNumber(any);

            if (cmp1 || cmp2 || cmp3 || cmp4) {
                trace(cmp1, cmp2, cmp3, cmp4);
            }

            // Test field access on * typed object - should use toNumberField
            // This ensures that accessing a potentially undefined field returns NaN
            // instead of 0 (which would happen with toNumber receiving null)
            testFieldAccessOnAny({length: 5});
            testFieldAccessOnAny({}); // Object without length field - should not trigger condition
        }

        private function takesInt(v:int):void {}
        private function takesUInt(v:uint):void {}
        private function takesNumber(v:Number):void {}

        private function testFieldAccessOnAny(param1:*):void {
            // When param1.length is undefined (field doesn't exist), AS3 Number(undefined) = NaN
            // and NaN <= 0 is false. Haxe would convert undefined to null, and Number(null) = 0,
            // so 0 <= 0 would be true (incorrect).
            // The filter should generate toNumberField(param1, "length") which checks if
            // the field exists before converting, returning NaN for missing fields.
            if (param1 == null || param1.length <= 0) {
                trace("Empty or null");
            } else {
                trace("Has items: " + param1.length);
            }
        }

        private function testBitwiseOnAny():void {
            // Keep variables as * to ensure CoerceToNumber inserts toInt for bitwise operands.
            var a:* = 1;
            var b:* = 2;
            var seed:uint = 3;
            a = "x";
            a = 4;
            b = "y";
            b = 5;

            var mixed:int = (seed & a) ^ (seed & b) ^ (a & b);
            trace(mixed);
        }
    }
}
