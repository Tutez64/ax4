/**
 * Test case: Vector literals.
 * `new <T>[...]` should become `Vector.ofArray([...])`.
 * `new <T>[]` should become `new Vector<T>()`.
 * `Vector.<Object>` should become `Array<Dynamic>`.
 * Redundant Vector casts should report a non-blocking error.
 */
package {
    public class TestFilterRewriteVectorDecl {
        private var _items:Vector.<Object>;

        public function TestFilterRewriteVectorDecl() {
            var numbers:Vector.<int> = new <int>[1, 2, 3];
            var empty:Vector.<String> = new <String>[];
            var objectEmpty:Vector.<Object> = new Vector.<Object>();
            var objectValues:Vector.<Object> = new <Object>[{type: 16003}];
            objectValues.push({type: 16003});
            var first:Object = objectValues[0];
            var copy:Vector.<int> = Vector.<int>(numbers);
            _items = objectValues;
        }

        public function passthrough(values:Vector.<Object>) : Vector.<Object> {
            return values;
        }

        public function get items() : Vector.<Object> {
            return _items;
        }
    }
}
