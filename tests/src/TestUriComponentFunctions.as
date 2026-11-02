/**
 * Test case: AS3 top-level encodeURIComponent/decodeURIComponent
 * (Starling's AssetManager decodes asset URLs).
 * Expected: ASCompat.encodeURIComponent / ASCompat.decodeURIComponent, which keep `+` as is.
 */
package {
    public class TestUriComponentFunctions {
        public function TestUriComponentFunctions() {
            var encoded:String = encodeURIComponent("a b+c");
            var decoded:String = decodeURIComponent(encoded);
        }
    }
}
