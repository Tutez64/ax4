/**
 * Test case for RewriteSwitch filter.
 * Covers:
 * - Basic switch (trailing breaks removed).
 * - Nested break (should wrap in do-while loop).
 * - Fall-through cases (grouped).
 * - Fall-through with case bodies (suffix duplicated into earlier cases).
 * - Default case.
 * - Continue inside switch (should use flag rewrite).
 * - int subject with uint case should cast case in guard.
 */
package {
    public class TestFilterRewriteSwitch {
        public function testBasic(val:int):void {
            var res:int = 0;
            switch(val) {
                case 1:
                    res = 10;
                    break;
                case 2:
                    res = 20;
                    break;
                default:
                    res = 30;
                    break;
            }
        }

        public function testNestedBreak(val:int):void {
            var res:int = 0;
            switch(val) {
                case 1:
                    if (val > 0) {
                        res = 10;
                        break; // Nested break triggers loop wrapper
                    }
                    res = 20;
                    break;
            }
        }

        public function testFallThrough(val:int):void {
            switch(val) {
                case 1:
                case 2:
                    trace("1 or 2");
                    break;
            }
        }

        // Each case assigns then falls through.
        public function testFallThroughBodies(val:int):void {
            var name:String = "";
            switch(val) {
                case 0:
                    name = "ach1";
                case 1:
                    name = "ach2";
                case 2:
                    name = "ach3";
            }
            trace(name);
        }

        // Body without break, empty cases, then another body.
        public function testFallThroughIntoGroupedCases(kind:String):void {
            var action:String = null;
            switch(kind) {
                case "scale":
                    action = "scale";
                case "zoom":
                case "timeScale":
                case "sufferImmunity":
                    action = "suffer";
                    break;
                case "other":
                    action = "other";
                    break;
            }
            trace(action);
        }

        public function testContinue(val:int):void {
            var res:int = 0;
            for (var i:int = 0; i < 3; i++) {
                switch(val) {
                    case 0:
                        continue;
                    case 1:
                        if (i > 0) {
                            res++;
                            break;
                        }
                        res += 2;
                        break;
                }
            }
        }

        public function testIntUintSwitch(val:int):void {
            var code:uint = 5;
            switch(val) {
                case code:
                    trace("uint case");
                    break;
            }
        }
    }
}
