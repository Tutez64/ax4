/**
 * Test case for RewriteTypesWithComment and HandleBasicValueDictionaryLookups filters.
 * A trailing `// Array<T>`, `// Dictionary<K, V>` or `// Object<V>` comment types an untyped
 * Array local or a new Dictionary/Object. Reading a typed Dictionary then goes through
 * ASCompat.processNull, so a missing key reads as the value type's default like in AS3.
 */
package {
    import flash.utils.Dictionary;

    public class TestFilterRewriteTypesWithComment {
        public function TestFilterRewriteTypesWithComment() {
            var ints:Array = []; // Array<int>
            ints.push(1);

            var counts:Dictionary = new Dictionary(); // Dictionary<String, int>
            var count:int = counts["missing"];

            var flags:Dictionary = new Dictionary(true); // Dictionary<String, Boolean>
            var flag:Boolean = flags["missing"];

            var names:Dictionary = new Dictionary(); // Dictionary<String, String>
            var name:String = names["missing"];

            trace(ints, count, flag, name);
        }
    }
}
