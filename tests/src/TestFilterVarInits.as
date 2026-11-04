/**
 * VarInits: Haxe rejects a local read before it is surely assigned, so such a local gets a default
 * value. A local function is its own scope: a return in it (a sort comparator) does not end the
 * enclosing function, so `firstError`, only assigned in a branch, still gets its default value.
 */
package {
    public class TestFilterVarInits {
        public function restore(objects:Array):void {
            var firstError:*;
            var failed:Boolean = false;
            objects.sort(function(a:Object, b:Object):int {
                return 0;
            });
            for each (var object:Object in objects) {
                try {
                    object.restore();
                } catch (e:Error) {
                    if (!failed) {
                        failed = true;
                        firstError = e;
                    }
                }
            }
            if (failed) {
                throw firstError;
            }
        }
    }
}
