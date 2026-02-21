/**
 * Test case for RewriteUndefinedLookupComparisons filter.
 * Dictionary/Object dynamic lookups compared to undefined should be rewritten
 * as existence checks to preserve AS3 runtime behavior on non-Flash targets.
 */
package {
    import flash.utils.Dictionary;

    public class TestFilterRewriteUndefinedLookupComparisons {
        public function TestFilterRewriteUndefinedLookupComparisons() {
            var dict:Dictionary = new Dictionary();
            var obj:Object = {};
            var key:* = "k";

            var d1:Boolean = dict[key] !== undefined;
            var d2:Boolean = dict[key] === undefined;
            var d3:Boolean = dict[key] != undefined;
            var d4:Boolean = dict[key] == undefined;

            var o1:Boolean = obj[key] !== undefined;
            var o2:Boolean = obj[key] === undefined;
            var l1:Boolean = undefined == dict[key];
            var l2:Boolean = undefined != obj[key];

            // Null comparisons should remain value checks.
            var keepDict:Boolean = dict[key] == null;
            var keepObj:Boolean = obj[key] != null;
        }
    }
}
