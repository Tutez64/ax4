/**
 * Test case for CoerceFromAny filter.
 * Covers:
 * - ASAny to class types via ASCompat.coerce (TypeError on a wrong type, like AVM2).
 * - ASAny to ByteArray via ASCompat.asByteArray helper.
 * - ASAny to array types via ASCompat.coerce.
 * - Untyped array literals mixing different types in ASAny context.
 */
package {
    import flash.display.Sprite;
    import flash.filters.BitmapFilter;
    import flash.filters.BlurFilter;
    import flash.utils.ByteArray;

    public class TestFilterCoerceFromAny {
        public function TestFilterCoerceFromAny() {
            var anySprite:* = new Sprite();
            var sprite:Sprite = anySprite;

            var anyFilter:* = new BlurFilter();
            var filter:BitmapFilter = anyFilter;

            this.acceptAnyBytes(new ByteArray());

            var anyArray:* = [1, 2, 3];
            var arr:Array = anyArray;

            var mixedStore:Object = {};
            var fn:Function = function():void {};
            var args:Array = [1, 2, 3];
            mixedStore["bind"] = [fn, args];
            mixedStore["menu"] = new Array(10, args, "label");
        }

        private function acceptAnyValue(value:*):void {
            // An untyped parameter cannot be inferred: both assignments go through ASCompat.coerce.
            var sprite:Sprite = value;
            var list:Array = value;
            trace(sprite, list);
        }

        private function acceptAnyBytes(value:*):void {
            var bytes:ByteArray = value;
        }
    }
}
