/**
 * Test case: `finally`, which Haxe does not have.
 * `try { A } catch (e:T) { B } finally { F }` is lowered to
 * `{ try { try { A } catch (e:T) { B } } catch (e:Dynamic) { F; throw e; } F; }`:
 * - a `try` with only a `finally` gets no inner `try`;
 * - `F` also runs before a `return`, `break` or `continue` that leaves the `try` or a `catch`,
 *   and a returned value is computed before `F` runs;
 * - a `break` or `continue` whose loop (or a `break` whose switch) is inside the `try`,
 *   and a `return` in a local function, are left alone;
 * - a nested `finally` runs before the outer one.
 */
package {
    public class TestTryFinally {
        private var busy:Boolean;
        private var log:Array = [];

        public function onlyFinally():void {
            busy = true;
            try {
                log.push("body");
            } finally {
                busy = false;
            }
        }

        public function returnFromCatch(f:Function):int {
            busy = true;
            try {
                f();
            } catch (error:Error) {
                log.push(error.message);
                return -1;
            } finally {
                busy = false;
            }
            return log.length;
        }

        public function returnValue():String {
            try {
                return String(log.length);
            } finally {
                log.push("after");
            }
        }

        public function loops(items:Array):void {
            for each (var item:Object in items) {
                try {
                    if (item == null) continue;
                    if (item == "stop") break;
                    for (var i:int = 0; i < 3; i++) {
                        if (i == 1) break;
                    }
                    switch (item) {
                        case "a":
                            break;
                    }
                    var later:Function = function():int {
                        return 1;
                    };
                } finally {
                    log.push("item");
                }
            }
        }

        public function nested():void {
            try {
                try {
                    return;
                } finally {
                    log.push("inner");
                }
            } finally {
                log.push("outer");
            }
        }
    }
}
