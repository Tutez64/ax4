/**
 * Test case: AS3 identifiers that collide with Haxe reserved keywords.
 * AS3 allows contextual keywords such as `override` as parameter/variable names;
 * Haxe does not. Expected: rename to a safe identifier (e.g. override -> override_)
 * and rewrite all references, including typed field access.
 */
package {
	public class TestFilterEscapeHaxeKeywords {
		public var inline:int = 1;

		public function tryRegister(override:Boolean = false):Boolean {
			if (!override) {
				return false;
			}
			var cast:Boolean = override;
			return cast;
		}

		public function useField():int {
			return this.inline + readInline(this);
		}

		public function catchCast():void {
			try {
				throw new Error("x");
			} catch (cast:Error) {
				trace(cast);
			}
		}
	}
}

function readInline(obj:TestFilterEscapeHaxeKeywords):int {
	return obj.inline;
}

var macro:int = 3;

function cast():int {
	return macro;
}
