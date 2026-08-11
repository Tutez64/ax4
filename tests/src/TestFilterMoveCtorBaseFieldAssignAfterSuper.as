/**
 * Test case for MoveCtorBaseFieldAssignAfterSuper filter.
 *
 * Expectations:
 * - Only trailing assignments to base class fields immediately before super() are moved after super().
 * - Assignments to subclass fields before super() stay in place.
 * - Assignments nested inside other statements (like if blocks) are not moved.
 * - Constructors where super() is already first remain unchanged.
 * - Base-field assigns read by a later pre-super statement stay before super()
 *   (e.g. mHost = x; mHelper = new Helper(mHost); super()).
 * - Default (reorderFieldInitsForCtorDeps off): trailing base assigns that only a
 *   child field init reads still move after super(); MoveFieldInits places the
 *   init at the start of the ctor (ASC: field inits see the default value).
 *   Expect warning from MoveFieldInits on ChildWithBaseFieldDep.
 */
package {
    public class TestFilterMoveCtorBaseFieldAssignAfterSuper {
        public function TestFilterMoveCtorBaseFieldAssignAfterSuper() {
            var a:ChildWithPreSuperBaseAssigns = new ChildWithPreSuperBaseAssigns(10);
            var b:ChildSuperFirst = new ChildSuperFirst();
            var c:ChildNoSuperCall = new ChildNoSuperCall();
            var d:ChildWithBaseFieldDep = new ChildWithBaseFieldDep(5);
            var e:ChildWithBaseFieldReadBeforeSuper = new ChildWithBaseFieldReadBeforeSuper({});
        }
    }
}

class BaseWithFields {
    public var baseA:int = 0;
    public var baseB:int = 0;
}

class ChildWithPreSuperBaseAssigns extends BaseWithFields {
    public var ownA:int = 0;

    public function ChildWithPreSuperBaseAssigns(v:int) {
        baseA = v;       // should stay before super() (not trailing)
        ownA = 3;        // should stay before super()
        if (v > 0) {
            baseA = 4;   // should stay before super() (nested statement)
        }
        this.baseB = 2;  // should move after super() (trailing)
        super.baseA = 6; // should move after super() (trailing, explicit super access)
        super();
        baseA = 5;       // should stay after super()
    }
}

class ChildSuperFirst extends BaseWithFields {
    public function ChildSuperFirst() {
        super();
        baseA = 1; // already after super(), should remain as-is
    }
}

class ChildNoSuperCall extends BaseWithFields {
    public function ChildNoSuperCall() {
        baseA = 2; // no super() call, should remain as-is
    }
}

// Field init depends on mBaseValue assigned before super().
// Default: trailing mBaseValue moves after super; mComponent init at ctor start.
class BaseWithProtectedField {
    protected var mBaseValue:int;

    public function BaseWithProtectedField(val:int) {}
}

class ChildWithBaseFieldDep extends BaseWithProtectedField {
    protected var mComponent:Component = new Component(mBaseValue);

    public function ChildWithBaseFieldDep(v:int) {
        mBaseValue = v;
        super(v);
    }
}

// Base field assigned then read by a later pre-super statement.
// mHost must stay before super() (and before the Helper construction).
class BaseWithHost {
    protected var mHost:Object;

    public function BaseWithHost(host:Object) {
        mHost = host;
    }
}

class ChildWithBaseFieldReadBeforeSuper extends BaseWithHost {
    private var mHelper:Helper;

    public function ChildWithBaseFieldReadBeforeSuper(host:Object) {
        mHost = host;
        mHelper = new Helper(mHost);
        super(host);
    }
}

class Component {
    public function Component(val:int) {}
}

class Helper {
    public function Helper(host:Object) {}
}
