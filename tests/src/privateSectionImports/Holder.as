/**
 * Test case: a full type path whose root is shadowed by a field
 * (starling.display.Stage has a `starling` getter, and ASCompat.coerce names starling.display.DisplayObject).
 * Expected: `DisplayObject` (same package) instead of `privateSectionImports.DisplayObject`.
 */
package privateSectionImports {
    public class Holder {
        public function get privateSectionImports():Object {
            return null;
        }

        public function pick(value:Object):DisplayObject {
            return value;
        }
    }
}
