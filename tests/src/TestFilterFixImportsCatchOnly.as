/**
 * Test case: a top-level error named only by a catch (`catch (e:RangeError)`, a fixed Vector's
 * push) needs its import too.
 * Expected: `import flash.errors.RangeError;` in the module.
 */
package {
    public class TestFilterFixImportsCatchOnly {
        public function TestFilterFixImportsCatchOnly(values:Vector.<int>) {
            try {
                values.push(1);
            } catch (e:RangeError) {
                trace(e.message);
            }
        }
    }
}
