/**
 * Test case for RewriteCasts filter.
 * Verifies how AS3 casts are converted to Haxe.
 *
 * Boolean(ref) / Boolean(bool && ref) must go through CoerceToBool (e.g. != null),
 * not a raw ASCompat.toBool around uncoerced Haxe && (invalid when a side is an object).
 * Explicit Boolean(...) wrappers appear in some AS3 sources (including decompiled output).
 *
 * Expected for the Boolean-wrapper cases:
 * - Boolean(child) -> child != null
 * - Boolean(1 > 0 && child) -> 1 > 0 && child != null
 * - Boolean(stageRef) -> stageRef != null
 * - Boolean(bool || stageRef && bool) -> bool || stageRef != null && bool (no thisOrDefault)
 */
package {
    import flash.display.Stage;

    public class TestFilterRewriteCasts {
        public var child:LocalSprite;
        public var stageRef:Stage;
        public var pos:Number = 0;
        public var size:Number = 0;

        public function TestFilterRewriteCasts() {
            var a:Object = "test";
            
            // Basic casts
            var s:String = String(a);
            var i:int = int(a);
            var n:Number = Number(a);
            var b:Boolean = Boolean(a);
            var u:uint = uint(a);

            // Class casts
            var spr:LocalSprite = LocalSprite(a);
            
            // Cast on complex expression
            var s2:String = String(a + "suffix");

            // Explicit Boolean(...) around object truthiness / &&
            if (Boolean(child)) {}
            if (Boolean(1 > 0 && child)) {}
            if (Boolean(stageRef) && Boolean(stageRef.stageWidth < 10)) {}
            if (Boolean(pos + size < 10 || stageRef && stageRef.stageWidth < pos + 10)) {}
        }
    }
}

class LocalSprite {}
