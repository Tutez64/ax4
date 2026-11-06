/**
 * Test case: RewriteDictionaryPrimitiveRead, Dictionary reads with a key statically known as primitive.
 * Expected:
 * - a read with a String key: `ASDictionary.getString(dict, key)`;
 * - a read with an int or uint key: `ASDictionary.getInt(dict, key)`, in nested reads too;
 * - a read with an untyped or object key, a Number key, a write, an increment and a delete keep `dict[key]`,
 *   though a read in the key of a write is rewritten.
 */
package {
	import flash.utils.Dictionary;

	public class TestFilterRewriteDictionaryPrimitiveRead {
		public function TestFilterRewriteDictionaryPrimitiveRead(dict:Dictionary, name:String, index:int, count:uint, any:*, key:Object) {
			var byName:* = dict[name];
			var byIndex:* = dict[index];
			var byCount:String = dict[count];
			var nested:* = dict[name][index];
			var byAny:* = dict[any];
			var byObject:* = dict[key];
			dict[name] = 1;
			dict[index] = dict[name];
			dict[dict[name]] = 2;
			dict[name]++;
			delete dict[name];
			if (dict[name]) {
				trace(byName, byIndex, byCount, nested, byAny, byObject);
			}
		}
	}
}
