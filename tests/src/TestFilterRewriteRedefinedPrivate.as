/**
 * RewriteRedefinedPrivate: a private field redefined by a subclass is renamed in its declaring
 * class (Haxe has no separate private namespaces). For an internal field redefined in another
 * package, see TestFilterRewriteRedefinedPrivate/.
 */
package {
    public class TestFilterRewriteRedefinedPrivate {
        private var value:int = 1;

        public function get():int {
            return value;
        }
    }
}

class RedefinedPrivateChild extends TestFilterRewriteRedefinedPrivate {
    private var value:int = 2;

    public function own():int {
        return value;
    }
}
