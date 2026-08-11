/**
 * Test case for MoveFieldInits filter.
 * Covers:
 * - Instance field init reading another field.
 * - Instance field init with explicit this.
 * - Instance field init calling an instance method.
 * - Field init that does not touch this (should stay).
 * - Derived class with a super() call.
 * - Field init depending on a slot assigned in the ctor (e.g. before super()):
 *   ASC runs field inits before the ctor body (default value). Default ax4
 *   placement matches that; settings.reorderFieldInitsForCtorDeps places the
 *   init after pre-super assigns to those slots instead. Expect warning:
 *   Field initializer depends on a slot assigned in the constructor (ASC uses the default value)
 */
package {
    public class TestFilterMoveFieldInits extends BaseMoveFieldInits {
        private var a:int = 1;
        private var b:int = a + 1;
        private var c:int = this.a + 2;
        private var d:int = getValue();
        private var e:int = 7;

        public function TestFilterMoveFieldInits() {
            super();
        }

        private function getValue():int {
            return a + 3;
        }
    }
}

class BaseMoveFieldInits {
    public function BaseMoveFieldInits() {
    }
}

// Field init depends on mBaseField assigned before super().
// ASC: mComponent sees the default (0). Default ax4: init at start of ctor.
class TestMoveFieldInitsBeforeSuper extends BaseWithProtectedField {
    protected var mHelper:Helper;
    protected var mComponent:Component = new Component(mBaseField);

    public function TestMoveFieldInitsBeforeSuper(param1:int) {
        mBaseField = param1;
        super(param1);
    }
}

class BaseWithProtectedField {
    protected var mBaseField:int;

    public function BaseWithProtectedField(val:int) {
    }
}

class Helper {}

class Component {
    public function Component(val:int) {}
}
