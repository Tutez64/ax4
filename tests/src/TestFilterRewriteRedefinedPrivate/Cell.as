/**
 * RewriteRedefinedPrivate: an internal field redefined by a subclass in another package.
 * AS3 keeps each package's internal fields apart, Haxe does not: Cell's key is renamed, in Cell and
 * in the classes of its package that read it (Pages), while the subclass's own key keeps its name.
 */
package TestFilterRewriteRedefinedPrivate {
    public class Cell {
        internal var key:String = "cell";

        public function describe():String {
            return key;
        }
    }
}
