/**
 * A ternary with a null branch (`cond ? value : null`) has the type of its other branch when that
 * type can hold null: an instance, a String, an Array, a Vector, a Function...
 * Expected: assigning it to a variable or field of that type needs no runtime coercion
 * (no ASCompat.coerce/dynamicAs), and the ternary is passed as is to a typed parameter.
 * With a Boolean, int, uint or Number branch, AS3 turns the null into false or 0 on assignment,
 * so the ternary stays untyped and keeps its conversion.
 */
package {
    public class TestTernaryNullBranch {
        private var mNext:TestTernaryNullBranch;
        private var mName:String;
        private var mItems:Vector.<TestTernaryNullBranch> = new Vector.<TestTernaryNullBranch>();

        public function TestTernaryNullBranch(flag:Boolean) {
            var next:TestTernaryNullBranch = flag ? mNext : null;
            var previous:TestTernaryNullBranch = flag ? null : (mNext);
            mNext = flag ? next : null;
            var name:String = flag ? mName : null;
            var items:Vector.<TestTernaryNullBranch> = flag ? mItems : null;
            var last:TestTernaryNullBranch = mItems.length == 0 ? null : mItems[mItems.length - 1];
            var callback:Function = flag ? onDone : null;
            take(flag ? previous : null);
            var count:int = flag ? mItems.length : null;
            var ratio:Number = flag ? 0.5 : null;
            trace(next, previous, name, items, last, callback, count, ratio);
        }

        private function onDone():void {
        }

        private function take(value:TestTernaryNullBranch):void {
        }
    }
}
