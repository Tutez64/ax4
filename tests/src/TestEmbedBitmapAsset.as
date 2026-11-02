/**
 * Test case: an image [Embed] class, as JPEXS decompiles one (Starling atlas PNG).
 * AS3 makes it a Bitmap, but OpenFL embeds @:bitmap on a BitmapData subclass only.
 * Expected: `@:bitmap("_assets/1_atlas_png.png") class TestEmbedBitmapAsset extends ASBitmapAsset`,
 * the source made relative to the classpath (AS3's leading `/` is the source root).
 */
package {
    import flash.display.Bitmap;

    [Embed(source="/_assets/1_atlas_png.png")]
    public class TestEmbedBitmapAsset extends Bitmap {
        public function TestEmbedBitmapAsset() {
            super();
        }
    }
}
