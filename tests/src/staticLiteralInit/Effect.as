/**
 * Test case: a static read through a constructor while another class boots (Starling's rendering).
 * Effect.VERTEX_FORMAT calls VertexFormat.fromString, whose constructor reads
 * VertexAttribute.FORMAT_SIZES. hxcpp boots statics in an order that only follows direct
 * references, so FORMAT_SIZES was still null; AS3 initializes a class on first use.
 * Expected: array and object literal statics (FORMAT_SIZES, NAMES, EMPTY) are set in `static function __init__()`,
 * VERTEX_FORMAT and the inlined LIMIT keep their initializers.
 */
package staticLiteralInit {
    public class Effect {
        public static const VERTEX_FORMAT:VertexFormat = VertexFormat.fromString("position:float2");
        private static var NAMES:Array = ["position", "color"];
        private static var EMPTY:Array = [];
        public static const LIMIT:Number = -1.5;
    }
}
