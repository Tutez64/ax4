/**
 * Test case: `super.f.apply(this, args)` on a method with a rest argument
 * (Starling's Polygon.addVertices in its immutable subclass).
 * Haxe cannot make a closure of a super method.
 * Expected: `super.addVertices(...rest)`.
 */
package {
    public class TestFunctionApplySuperRest extends FunctionApplySuperRestBase {
        override public function addVertices(...args):void {
            super.addVertices.apply(this, args);
        }
    }
}

class FunctionApplySuperRestBase {
    public function addVertices(...args):void {
    }
}
