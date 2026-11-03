/**
 * Helper for RewriteRedefinedPrivate: reads Cell's internal key from its package,
 * on a Cell (renamed) and on a subclass in the same package that does not redefine it (renamed too).
 */
package TestFilterRewriteRedefinedPrivate {
    public class Pages {
        public function keyOf(c:Cell, p:PlainCell):String {
            return c.key + p.key;
        }
    }
}
