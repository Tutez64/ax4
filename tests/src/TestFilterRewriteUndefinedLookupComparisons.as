/**
 * Test case for RewriteUndefinedLookupComparisons filter.
 * Dictionary/Object dynamic lookups compared to undefined should be rewritten
 * as existence checks to preserve AS3 runtime behavior on non-Flash targets.
 *
 * Also, loose null checks on Dictionary lookups should be rewritten so that
 * missing entries (undefined) still behave like null (`undefined == null`).
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

            // Loose null checks on Dictionary lookup should treat missing as null.
            var n1:Boolean = dict[key] == null;
            var n2:Boolean = dict[key] != null;
            var n3:Boolean = null == dict[key];
            var n4:Boolean = null != dict[key];

            // Object null checks should remain simple value checks.
            var keepObjEq:Boolean = obj[key] == null;
            var keepObjNe:Boolean = obj[key] != null;
        }
    }
}
