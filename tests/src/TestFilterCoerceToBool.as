/**
 * Test case for CoerceToBool filter.
 * AS3 allow using non-boolean values in conditions.
 * They should be explicitly coerced to boolean in Haxe.
 * Void return used as Bool (AVM2 undefined) becomes `{call; false;}`.
 */
package {
    public class TestFilterCoerceToBool {
        public function TestFilterCoerceToBool() {
            var obj:Object = {};
            var str:String = "hello";
            var num:Number = 123;
            var arr:Array = [];

            if (obj) {}
            if (str) {}
            if (num) {}
            if (arr) {}
            if (obj && str) {}
            if (str && num) {}

            var b:Boolean = obj ? true : false;

            while (str) {
                str = null;
            }

            if (!num) {}

            // void method used in if — side effects kept, condition always false.
            if (voidSideEffect()) {
                throw new Error("unreachable");
            } else {
                trace("else");
            }
        }

        private function voidSideEffect():void {
            trace("side");
        }
    }
}
