/**
 * Test case: AS3 top-level errors that Haxe takes from `flash.errors`.
 * `RangeError`, `TypeError` and `SecurityError` need an import like `ArgumentError`
 * (Starling throws `new RangeError("Invalid child index")`).
 * Expected: `import flash.errors.RangeError;` etc. in the module.
 */
package {
    public class TestFilterFixImports {
        public function TestFilterFixImports(index:int) {
            if (index < 0) throw new RangeError("Invalid child index");
            if (index == 0) throw new TypeError("No zero");
            if (index == 1) throw new SecurityError("No one");
            try {
                throw new ArgumentError("Bad");
            } catch (e:RangeError) {
            }
        }
    }
}
