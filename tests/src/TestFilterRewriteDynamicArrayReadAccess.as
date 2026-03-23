/**
 * Test case for RewriteDynamicArrayReadAccess filter.
 * Nested numeric reads that come from a prior dynamic [] lookup must preserve
 * array semantics when the intermediate value is actually an Array at runtime.
 * Direct dynamic reads should stay untouched to avoid broad runtime overhead.
 */
package {
    public class TestFilterRewriteDynamicArrayReadAccess {
        public function TestFilterRewriteDynamicArrayReadAccess() {
            var any:*;
            var direct:Object = any[0];

            var anyArray:* = [10, 20, 30];
            var directArray:Object = anyArray[1];

            var objectArray:Object = [40, 50, 60];
            var stringIndex:Object = objectArray[2];

            var nested:* = [[7, 8, 9]];
            var nestedRead:Object = nested[0][1];

            var anyIndex:* = 2;
            var dynamicIndex:Object = any[anyIndex - 1];

            var rewardInfo:Array = [3,5,[5,10,15],0,5];
            var rewardValue:Object = rewardInfo[2][rewardInfo[0] - 1];
        }
    }
}
