/**
 * Test case: type of a local variable should be inferred from its usage.
 * This test case verifies that local variable types are correctly inferred
 * based on their usage within the code. It covers various scenarios including
 * basic literal inference, uninitialized variables, and complex expressions.
 */
package {
    import flash.filters.ColorMatrixFilter;
    import flash.display.Sprite;
    import org.as3commons.collections.Map;

    public class TestFilterInferLocalVarTypes {
        public function TestFilterInferLocalVarTypes() {
            // Case 0: Basic literal inference
            var i = 0;
            i++; // Int

            var n = 1.5;
            n = 2.5; // Number

            var flag = true;
            flag = false; // Bool

            var text = "hello";
            text += "!"; // String

            var mixed = 0;
            mixed = "oops"; // ASAny (incompatible)

            // Case 1: Uninitialized var, inferred from usage (Bitwise)
            var bitVar:*; // ASAny
            var res1 = bitVar >> 5; // Implies bitVar is Int
            // bitVar should be Int

            // Case 2: Uninitialized var, inferred from usage (Arithmetic)
            var numVar:*;
            var res2 = numVar - 15; // Implies numVar is Number (or Int)
            // numVar should be Number (or Int)

            // Case 3: Assignment from complex expression
            var complexInt:*;
            complexInt = (i << 2) ^ (i >>> 3); // Implies Int
            // complexInt should be Int

            // Case 4: Assignment with increment embedded
            var loopVar:*;
            var other:*;
            var arr:Array = [];
            other = arr[loopVar++]; // loopVar++ implies numeric.
            // loopVar should be Int (or Number)
            
            // Case 5: Inferred from first assignment
            var assignedLater:*;
            assignedLater = 10;
            // assignedLater should be Int

            // Case 6: Read before write (Unsafe)
            var unsafe:*;
            var val = unsafe; // Read!
            unsafe = 10;
            // unsafe should remain ASAny because it was read before type was known.
            
            // Case 7: Math call inference
            var mathVal:*;
            mathVal = Math.round(1.5); // Should imply Number
            // mathVal should be Number
            
            // Case 8: Array Access Index Inference
            var idx:*;
            var arr2:Array = [];
            var val2 = arr2[idx]; // idx used as index
            // idx should be Int

            // Case 8b: Object key access should not force Int
            var key:*;
            var obj:Object = {};
            var valObj = obj[key];
            // key should remain ASAny/String-like
            
            // Case 9: Array Literal Inference
            var arrVar:*;
            arrVar = [1, 2, 3];
            // arrVar should be Array (or Array<Any>)
            
            // Case 10: OpAdd inference
            var sum:*;
            sum = 1 + 2; // Number/Int
            // sum should be Number
            
            var strSum:*;
            strSum = "a" + "b"; // String
            // strSum should be String
            
            var mixedSum:*;
            mixedSum = "a" + 1; // String
            // mixedSum should be String
            
            // Case 11: ColorMatrixFilter matrix
            var matrixVar:*;
            matrixVar = [1,0,0,0,0, 0,1,0,0,0, 0,0,1,0,0, 0,0,0,1,0];
            var cmf:ColorMatrixFilter = new ColorMatrixFilter(matrixVar);
            cmf.matrix = matrixVar;
            // matrixVar should be Array
            
            // Case 12: Class Instantiation Inference
            var spriteVar:*;
            spriteVar = new Sprite();
            // spriteVar should be Sprite
            
            var filterVar:*;
            filterVar = new ColorMatrixFilter();
            // filterVar should be ColorMatrixFilter
            
            // Case 13: Loop variable type inference from array elements
            var arr1:Array = [1, 2, 3];
            var arr2:Array = [4, 5, 6];
            var arr3:Array = [7, 8, 9];

            // The loop variable 'item' should be inferred as Array, not ASAny
            // because all elements in the array are Arrays
            for each (var item in [arr1, arr2, arr3]) {
                // item should be typed as Array, allowing Array methods
                var len:int = item.length;
                var first:int = item[0];
            }

            // Case 14: Loop variable type inference from Vector elements
            var helpers:Vector.<LocalVarTypeHelper> = new Vector.<LocalVarTypeHelper>();
            helpers.push(new LocalVarTypeHelper());
            for each (var helper in helpers) {
                var helperValue:int = helper.value;
            }

            var sharedHelper:*;
            for each (sharedHelper in helpers) {
                var sharedValue:int = sharedHelper.value;
            }

            // Case 15: Untyped map item iteration should infer typed iteratee values
            // m.itemFor(...) returns *, but values added into this key are Vector.<LocalVarTypeHelper>.
            var helpersByCategory:Map = new Map();
            helpersByCategory.add("helpers", helpers);
            for each (var helperFromMap in helpersByCategory.itemFor("helpers")) {
                var mapHelperValue:int = helperFromMap.value;
            }

            // Case 16: Same map iteration pattern, but with a shared loop variable.
            var sharedHelperFromMap:*;
            for each (sharedHelperFromMap in helpersByCategory.itemFor("helpers")) {
                var sharedMapHelperValue:int = sharedHelperFromMap.value;
            }

            // Case 17: Cyclical numeric flow over * vars should still infer Int when possible.
            // Note: hashB is expected to potentially stay ASAny because it is read before
            // a stable hint exists (hashCarry = hashB). The filter keeps this conservative
            // behavior to avoid incorrect inference.
            var words:Array = [1, 2, 3, 4];
            var hashA:* = words[0];
            var hashB:* = words[1];
            var hashC:* = words[2];
            var hashD:* = words[3];
            var hashCarry:*;
            hashCarry = hashB;
            var hashMix:int = (hashA & hashB) ^ (hashC & hashD) ^ (hashA & hashD);
            hashB = hashA;
            hashA += hashCarry;

            // Case 18: Simulate RewriteForIn generated iteratee temp var naming.
            // A synthetic "__ax3_iter_*" iteratee local should prefer Array<Any> over ASAny.
            var data:* = {"attacks":[{"attackName":"A"}]};
            var __ax3_iter_999:* = data.attacks;
            for each (var attackEntry in __ax3_iter_999) {
                var attackName:String = attackEntry.attackName;
            }
        }
    }
}

class LocalVarTypeHelper {
    public var value:int = 1;
}
