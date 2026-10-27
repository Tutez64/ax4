/**
 * Test case: nullish coalescing `??` and optional chaining `?.`, from the AIR 50 compiler.
 * Both map to the Haxe operators of the same spelling.
 * - `a ?? b` is printed as is; parentheses are added where Haxe's `??`, which binds tighter than
 *   a comparison, would otherwise read the expression differently (`a == b ?? c`).
 * - `a?.b` keeps the question mark through field access and calls.
 * - `flag?.5:1` stays a ternary on a number: a digit after `?.` is not a field.
 */
package {
    public class TestNullishOperators {
        public var next:TestNullishOperators;
        public var name:String;

        public function TestNullishOperators() {
            var json:Object = {x: 1};
            var x:Number = json.x ?? 0;
            var layer:String = name ?? "sorted";
            var sum:Number = 1 + (json.y ?? 2);
            var chained:Object = json.a ?? json.b ?? 3;
            var cmp:Object = x == 1 ?? false;

            var nextName:String = next?.name;
            var deep:String = next?.next?.name;
            var str:String = next?.toString();
            var arr:Array = null;
            var len:int = int(arr?.length);

            var flag:Boolean = true;
            var half:Number = flag?.5:1;
        }

        public function toString():String {
            return name;
        }
    }
}
