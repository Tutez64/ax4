/**
 * Helper for RewriteRedefinedPrivate: redefines Cell's internal key in another package,
 * which AS3 allows. Its own key keeps its name.
 */
package TestFilterRewriteRedefinedPrivate.other {
    import TestFilterRewriteRedefinedPrivate.Cell;

    public class HudCell extends Cell {
        internal var key:String = "hud";

        public function own():String {
            return key;
        }
    }
}
