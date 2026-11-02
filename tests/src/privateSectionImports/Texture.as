/**
 * Test case: a module type shadowing an import of the same name.
 * starling.textures.Texture imports flash.display3D.textures.Texture and writes it in full.
 * Expected: the imported type is printed with its full path, `Texture` alone being this class.
 */
package privateSectionImports {
    import flash.display3D.textures.Texture;

    public class Texture {
        public var base:flash.display3D.textures.Texture;

        public function Texture(base:flash.display3D.textures.Texture) {
            this.base = base;
        }
    }
}
