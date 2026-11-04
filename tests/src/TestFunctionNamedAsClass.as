/**
 * Test case: a second function named as its class, which only decompiled non-AS3 code has (Box2D's
 * b2LineJointDef, ported to Haxe, keeps its AS3 constructor body as a method the Haxe constructor
 * does not call). The first is the constructor; the other is a method, renamed with a trailing _
 * so it is not a second `new` (reported).
 */
package {
    public class TestFunctionNamedAsClass {
        public var ready:Boolean;

        public function TestFunctionNamedAsClass() {
        }

        public function TestFunctionNamedAsClass() : void {
            ready = true;
        }
    }
}
