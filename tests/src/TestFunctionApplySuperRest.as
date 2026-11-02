/**
 * Test case: `f.apply(this, args)` on a method with a rest argument (Starling's Polygon:
 * addVertices.apply(this, vertices), and super.addVertices.apply in its immutable subclass).
 * hxcpp passes a rest as one array argument, so Reflect.callMethod gave it the first item,
 * and Haxe cannot make a closure of a super method.
 * Expected: `addVertices(...(vertices ?? []))` and `super.addVertices(...(args ?? []))`.
 */
package {
    public class TestFunctionApplySuperRest extends FunctionApplySuperRestBase {
        override public function addVertices(...args):void {
            super.addVertices.apply(this, args);
        }
    }
}

class FunctionApplySuperRestBase {
    public function FunctionApplySuperRestBase(vertices:Array = null) {
        addVertices.apply(this, vertices);
    }

    public function addVertices(...args):void {
    }
}
