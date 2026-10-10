/**
 * Test case for RewriteAccessorAccess filter.
 * Property reads/writes should be rewritten to explicit get_/set_ calls
 * when superclasses only declare the opposite accessor.
 * This filter changes access sites (not the class declaration), useful for extern parents
 * (ExternGetterChild), where AddMissingAccessorInSuper cannot add the missing accessor.
 */
package {
    import flash.display.Sprite;

    public class TestFilterRewriteAccessorAccess {
        public function TestFilterRewriteAccessorAccess() {
            var childA:ChildGetter = new ChildGetter();
            var value:int = childA.readValue();

            var childB:ChildSetter = new ChildSetter();
            childB.writeFlag(true);

            // The extern parent only has the getter and cannot get a setter added:
            // the write goes through set_numChildren() instead.
            var childC:ExternGetterChild = new ExternGetterChild();
            childC.numChildren = 3;
        }
    }
}

class BaseSetter {
    protected var _value:int = 0;

    public function set value(v:int):void {
        _value = v;
    }
}

class ChildGetter extends BaseSetter {
    public function get value():int {
        return _value;
    }

    public function readValue():int {
        return value;
    }
}

class BaseGetter {
    protected var _flag:Boolean = false;

    public function get flag():Boolean {
        return _flag;
    }
}

class ChildSetter extends BaseGetter {
    public function set flag(v:Boolean):void {
        _flag = v;
    }

    public function writeFlag(v:Boolean):void {
        flag = v;
    }
}

class ExternGetterChild extends Sprite {
    public function set numChildren(value:int):void {
    }
}
