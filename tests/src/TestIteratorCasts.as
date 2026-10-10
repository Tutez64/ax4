/**
 * Test case: untyped iterators assigned to IIterator.
 * Assigning an untyped iterator to IIterator should be wrapped with a cast.
 */
package {
    import org.as3commons.collections.framework.IIterator;

    public class TestIteratorCasts {
        public function TestIteratorCasts() {
            var list:DummyList = new DummyList();
            var it:IIterator = list.iterator();
            if (it != null && it.hasNext()) {
                trace(it);
            }
        }
    }
}

class DummyList {
    public function iterator():* {
        return new DummyIterator();
    }
}

class DummyIterator {
    public function hasNext():Boolean {
        return false;
    }
}
