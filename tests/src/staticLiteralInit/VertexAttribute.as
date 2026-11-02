/**
 * Test case: helper of staticLiteralInit.Effect, the literal static read at boot.
 */
package staticLiteralInit {
    public class VertexAttribute {
        private static const FORMAT_SIZES:Object = {
            "float1": 4,
            "float2": 8
        };

        public var size:int;

        public function VertexAttribute(format:String) {
            size = FORMAT_SIZES[format];
        }
    }
}
