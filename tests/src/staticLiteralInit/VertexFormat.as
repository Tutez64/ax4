/**
 * Test case: helper of staticLiteralInit.Effect, reaches VertexAttribute from its constructor.
 */
package staticLiteralInit {
    public class VertexFormat {
        public var size:int;

        public function VertexFormat(format:String) {
            size = new VertexAttribute(format.split(":")[1]).size;
        }

        public static function fromString(format:String):VertexFormat {
            return new VertexFormat(format);
        }
    }
}
