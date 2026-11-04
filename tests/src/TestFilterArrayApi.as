/**
 * Test case: ArrayApi filter rewrites.
 * sortOn defaults to options = 0 and routes to ASCompat.ASArray.sortOn.
 * sort uses Reflect.compare for statements and ASCompat.ASArray.sort for value usage.
 * sort options route to ASCompat.ASArray.sortWithOptions.
 * concat/join/push/unshift/length/insertAt/splice are rewritten as needed.
 * removeAt becomes splice(i, 1)[0] (Haxe's Array has none), and Vector.<Object>, an Array<Dynamic>
 * in Haxe, gets the Array rewrites (Starling's sHoveringTouchData.length = 0).
 * Every item of a multiple push/unshift is coerced to the element type (Number items in a Vector.<uint>).
 * Vector.filter/every/some/forEach with an (item, index, vector) callback go through ASCompat.ASVectorTools
 * (Starling's AssetManager.dequeue); a one-argument callback stays a Vector method call.
 * reverse/map/some route to compat helpers for Array/Vector.
 * concat of untyped values (an Array or one item, known at runtime), or of several values, calls
 * ASCompat.ASArray.concat.
 * Vector sort/splice paths are covered.
 * Array methods on TTAny/ASAny objects are transformed to ASCompat.dyn* calls.
 */
package {
    public class TestFilterArrayApi {
        public function TestFilterArrayApi() {
            var items:Array = [{n: "b"}, {n: "a"}];
            items = items.sortOn("n");
            items = items.sortOn("n", Array.CASEINSENSITIVE | Array.DESCENDING);
            var items2:Array = [{a: 1, b: "b"}, {a: 1, b: "a"}];
            items2 = items2.sortOn(["a", "b"], [Array.NUMERIC, Array.CASEINSENSITIVE]);

            items.sort();
            items = items.sort();

            var sorter:Function = function(a:*, b:*):int {
                return 0;
            };
            items.sort(sorter);
            items = items.sort(sorter);
            items = items.sort(Array.NUMERIC);

            var copy:Array = items.concat();
            var merged:Array = items.concat([1, 2]);
            var withOne:Array = items.concat(3);
            var any:* = {};
            items.concat(any);
            var several:Array = items.concat([1], 2, any);

            var joined:String = items.join();

            items.reverse();
            items = items.reverse();

            var anyFound:Boolean = items.some(function(item:*, index:int, array:Array):Boolean {
                return item != null;
            }, this);

            var mapped:Array = items.map(function(item:*, index:int, array:Array):* {
                return item;
            }, this);

            // map with void callback should be rewritten to forEach
            items.map(function(item:*, index:int, array:Array):void {
                items2[0] = item;
            }, this);

            var newLen:int = items.push(1, 2);
            items.unshift(3, 4);
            items.push();
            items.unshift();

            items.length = 1;
            var len:int = (items.length = 2);

            items.insertAt(1, 9);
            items.removeAt(0);
            var removedAt:* = items.removeAt(0);

            var objects:Vector.<Object> = new Vector.<Object>();
            objects.length = 0;
            objects.insertAt(0, {});
            var removedObject:Object = objects.removeAt(0);

            var indices:Vector.<uint> = new Vector.<uint>();
            var a:Number = 1, b:Number = 2;
            indices.push(a, b, 3);
            var big:Vector.<uint> = indices.filter(function(item:uint, index:int, vector:Vector.<uint>):Boolean {
                return item > 1;
            });
            indices.forEach(function(item:uint, index:int, vector:Vector.<uint>):void {
            });

            items.splice(1, 0, 7);
            var removed:Array = items.splice(1, 2);
            items.splice(1);
            var removed2:Array = items.splice(1, 2, 3, 4);

            var vec:Vector.<int> = new Vector.<int>();
            vec.push(1);
            vec.sort(function(a:int, b:int):int {
                return a - b;
            });
            vec = vec.sort(function(a:int, b:int):int {
                return a - b;
            });
            vec = vec.sort(Array.DESCENDING);
            vec.splice(0, 0, 5);
            vec.splice(1);
            vec.splice(1, 2, 3, 4);

            var vec2:Vector.<int> = new Vector.<int>();
            vec2.push(1);
            vec2.reverse();
            vec2 = vec2.reverse();
            var mappedVec:Vector.<int> = vec2.map(function(item:int, index:int, vector:Vector.<int>):int {
                return item + 1;
            }, this);

            // vector map with void callback should be rewritten to forEach
            vec2.map(function(item:int, index:int, vector:Vector.<int>):void {
                vec2.push(item);
            }, this);

            // Test array methods on TTAny/ASAny objects (dynamic array access)
            // These should be transformed to ASCompat.dyn* calls
            testAnyArrayMethods();
        }

        // Test calling array methods on dynamically-typed arrays (TTAny)
        private function testAnyArrayMethods():void {
            var arr:* = [];
            arr.push(1);  // Should be transformed to ASCompat.dynPush(arr, 1)
            arr.push(2, 3);  // Should be transformed to ASCompat.dynPushMultiple(arr, 2, [3])

            var arr2:* = [1, 2, 3];
            var popped:* = arr2.pop();  // Should be transformed to ASCompat.dynPop(arr2)
            var shifted:* = arr2.shift();  // Should be transformed to ASCompat.dynShift(arr2)

            var arr3:* = [];
            arr3.unshift(1);  // Should be transformed to ASCompat.dynUnshift(arr3, 1)
            arr3.unshift(2, 3);  // Should be transformed to ASCompat.dynUnshiftMultiple(arr3, 2, [3])

            var arr4:* = [1, 2, 3];
            arr4.reverse();  // Should be transformed to ASCompat.dynReverse(arr4)

            var arr5:* = [1, 2, 3, 4, 5];
            arr5.splice(1, 2);  // Should be transformed to ASCompat.dynSplice(arr5, 1, 2)
            arr5.splice(1, 0, 10);  // Should be transformed to ASCompat.dynSplice(arr5, 1, 0, [10])

            var arr6:* = [1, 2];
            var concatResult:* = arr6.concat([3, 4]);  // Should be transformed to ASCompat.dynConcat(arr6, [3, 4])

            var arr7:* = [1, 2, 3];
            var joined:String = arr7.join(",");  // Should be transformed to ASCompat.dynJoin(arr7, ",")

            var arr8:* = [1, 2, 3, 4, 5];
            var sliced:* = arr8.slice(1, 3);  // Should be transformed to ASCompat.dynSlice(arr8, 1, 3)

            // Test accessing array from a multi-dimensional array with any type
            var matrix:Array = [];
            matrix[0] = [];
            matrix[0].push(new Object());  // matrix[0] is TTAny, should use dynPush

            // Test with array retrieved from an Object (which is TTObject(TTAny))
            var obj:Object = {arr: []};
            obj.arr.push(1);  // obj.arr is TTObject(TTAny), should use dynPush
        }
    }
}
