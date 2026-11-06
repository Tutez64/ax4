/**
 * undefined as the value of an untyped (*) return, variable or assignment, as a map returns for a
 * missing key so that its caller can tell it from a stored null with typeof.
 * Expected: those become ASCompat.UNDEFINED, AS3's undefined outside flash and JS. The comparison
 * with undefined, the typed variable, the typed return and the default argument keep null.
 */
package {
    public class TestFilterRewriteUndefinedValues {
        private var mNodes:Object = {};

        public function TestFilterRewriteUndefinedValues() {
            var untyped:* = undefined;
            var typed:String = undefined;
            untyped = undefined;
            if (nodeFor("a") != undefined && typeof nodeFor("b") == "undefined") {
                trace(untyped, typed, name());
            }
        }

        public function nodeFor(key:*):* {
            if (mNodes.hasOwnProperty(key)) {
                return mNodes[key];
            }
            return undefined;
        }

        public function name():String {
            return undefined;
        }

        public function find(key:* = undefined):* {
            return key;
        }
    }
}
