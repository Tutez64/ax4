/**
 * for each over an untyped value (a * returned by a method, a field read through an Object): the
 * value may be a Vector, an Array, a Dictionary or an Object, so the loop must not assume an Array.
 * Expected: the iteratee keeps an untyped type (ASAny/ASObject), iterated with ASCompat's dynamic
 * iterators, also when the loop variable is declared before the loop with a class type. (With the
 * checkNullIteratee setting, the iteratee goes in a temporary var that stays untyped: see Case 18 of
 * TestFilterInferLocalVarTypes.)
 */
package {
    public class TestForEachUntypedIteratee {
        private var mItems:TestForEachUntypedIterateeStore = new TestForEachUntypedIterateeStore();

        public function TestForEachUntypedIteratee() {
            var total:int = 0;
            var offer:TestForEachUntypedIterateeStore = null;
            for each(offer in mItems.itemFor("SPECIAL")) {
                if (!offer.name) {
                    total++;
                }
            }
            var entry:Object = null;
            var source:Object = mItems;
            for each(entry in source.Stackables) {
                if (entry.UsageAttack != null && entry.UsageAttack.length > 0) {
                    total++;
                }
            }
        }
    }
}

class TestForEachUntypedIterateeStore {
    public var name:String;
    public var Stackables:Vector.<Object> = new Vector.<Object>();

    public function itemFor(key:*):* {
        return null;
    }
}
