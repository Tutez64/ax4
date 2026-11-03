/**
 * Test case: `v.push.apply(v, items)` (Starling's ColorMatrixFilter: _userMatrix.push.apply(_userMatrix, IDENTITY)).
 * Array/Vector push takes a rest, which Reflect.callMethod fills with the first item on native targets.
 * Expected: ASCompat.ASVector.pushAll(v, items) / ASCompat.ASArray.unshiftAll(a, items).
 */
package {
    public class TestFunctionApplyPushAll {
        private static const IDENTITY:Array = [1, 0, 0, 1];

        public function TestFunctionApplyPushAll() {
            var matrix:Vector.<Number> = new Vector.<Number>();
            matrix.push.apply(matrix, IDENTITY);
            var names:Array = ["c"];
            names.unshift.apply(names, ["a", "b"]);
        }
    }
}
