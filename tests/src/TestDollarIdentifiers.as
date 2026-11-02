/**
 * Test case: `$` in AS3 identifiers.
 * ASC names a binary [Embed] class `stem$<sha1>` (`atlas_xml$110c...`), which JPEXS decompiles as is.
 * Expected: the scanner reads `$` as an identifier character, and the Haxe type
 * and module are named with `_` instead (`Embed_xml_0a1b2c3d`), at the declaration and at every use.
 */
package {
    public class TestDollarIdentifiers {
        public static const embedded:Class = embed_xml$0a1b2c3d;

        public function TestDollarIdentifiers() {
            var bytes:embed_xml$0a1b2c3d = new embed_xml$0a1b2c3d();
        }
    }
}
