/**
 * Test case: exhaustive coverage for `HandleNew`.
 * Expected behavior:
 * - `new` on expression-based constructors rewrites to `ASCompat.createInstance(...)`.
 * - dynamic `new` without parentheses also rewrites (empty args array case).
 * - direct `new ClassName(...)` stays as a normal constructor call.
 * - typed `new` on non-class types (Array/Vector) is unchanged by this filter.
 * - instantiated classes without explicit ctors receive injected constructors.
 * - when both parent and child are instantiated and both miss ctors, the filter
 *   prefers injecting on the parent path (per current filter logic).
 */
package {
    public class TestFilterHandleNew {
        public function TestFilterHandleNew() {
            // TNExpr branch: dynamic constructor with args.
            var ctorRef:* = HandleNewDep;
            var fromRef:* = new ctorRef(7, "from-ref");

            // TNExpr branch: dynamic constructor without parens (args == null path).
            var noArgCtorRef:* = HandleNewNoArgDep;
            var fromNoArgRef:* = new noArgCtorRef;

            // TNExpr branch: dynamic constructor selected through expression.
            var useAlt:Boolean = true;
            var selectedCtor:* = useAlt ? HandleNewAltDep : HandleNewDep;
            var fromSelected:* = new selectedCtor(9, "from-selected");

            // TNType(TTInst) branch: direct class instantiation remains unchanged.
            var fromStatic:HandleNewDep = new HandleNewDep(8, "from-static");
            var withCtor:HandleNewWithCtor = new HandleNewWithCtor();

            // TNType(TTInst) branch + ctor injection paths for missing ctors.
            var baseNoCtor:HandleNewBaseNoCtor = new HandleNewBaseNoCtor();
            var childNoCtor:HandleNewChildNoCtor = new HandleNewChildNoCtor();
            var onlyChildInstantiated:HandleNewOnlyChildInstantiatedNoCtor = new HandleNewOnlyChildInstantiatedNoCtor();

            // TNType(non-TTInst) branch: no rewrite in HandleNew.
            var list:Vector.<int> = new Vector.<int>(2, true);
            var arr:Array = new Array();
        }

        public function buildFromFunction(value:int):* {
            var ctor:* = getCtor();
            return new ctor(value, "from-function");
        }

        public function buildNoArgFromFunction():* {
            var ctor:* = getNoArgCtor();
            return new ctor;
        }

        private function getCtor():* {
            return HandleNewDep;
        }

        private function getNoArgCtor():* {
            return HandleNewNoArgDep;
        }
    }
}

class HandleNewDep {
    public var value:int;
    public var label:String;

    public function HandleNewDep(v:int = 0, l:String = "") {
        value = v;
        label = l;
    }
}

class HandleNewAltDep extends HandleNewDep {
    public function HandleNewAltDep(v:int = 0, l:String = "") {
        super(v, l);
    }
}

class HandleNewNoArgDep {
    public var marker:int = 1;
}

class HandleNewWithCtor {
    public function HandleNewWithCtor() {
    }
}

class HandleNewBaseNoCtor {
    public var baseValue:int = 10;
}

class HandleNewChildNoCtor extends HandleNewBaseNoCtor {
    public var childValue:int = 20;
}

class HandleNewParentNotInstantiatedNoCtor {
    public var parentValue:int = 30;
}

class HandleNewOnlyChildInstantiatedNoCtor extends HandleNewParentNotInstantiatedNoCtor {
    public var onlyChildValue:int = 40;
}
