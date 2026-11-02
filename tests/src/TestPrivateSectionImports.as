/**
 * Test case: imports of the file's private section.
 * Starling.as imports starling.display.DisplayObject in its package block and
 * flash.display.DisplayObject after it, for its private isNativeDisplayObjectEmpty.
 * Expected: the private function takes flash.display.DisplayObject and the class
 * privateSectionImports.DisplayObject, each printed so that it resolves to its own type,
 * class references included (`value as DisplayObject`).
 */
package {
    import flash.display.Sprite;
    import privateSectionImports.DisplayObject;

    public class TestPrivateSectionImports {
        public var root:DisplayObject;

        public function TestPrivateSectionImports(nativeRoot:Sprite) {
            root = new DisplayObject();
            isNativeEmpty(nativeRoot);
            var value:Object = root;
            root = value as DisplayObject;
        }
    }
}

import flash.display.DisplayObject;

function isNativeEmpty(object:DisplayObject):Boolean {
    return object.width == 0;
}
