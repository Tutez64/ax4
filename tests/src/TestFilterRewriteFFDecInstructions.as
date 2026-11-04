/**
 * RewriteFFDecInstructions: JPEXS FFDec prints an AVM2 instruction ActionScript cannot express as
 * §§name(...), and a name it cannot print as is between § (a member named typeof).
 * - §§hasnext(o, i) with locals (hasnext2, which moves i to the next property) is
 *   (i = ASCompat.nextIndex(o, i)) != 0.
 * - §§nextname(i, o) and §§nextvalue(i, o) call ASCompat.nextName and nextValue.
 * - §typeof§ reads the member typeof.
 */
package {
    public class TestFilterRewriteFFDecInstructions {
        public var typeof:int = 1;

        public function names(o:Object):Array {
            var result:Array = [];
            var obj:* = o;
            var index:int = 0;
            while (§§hasnext(obj, index)) {
                result.push(§§nextname(index, obj));
                result.push(§§nextvalue(index, obj));
            }
            return result;
        }

        public function escapedName():int {
            return this.§typeof§;
        }
    }
}
