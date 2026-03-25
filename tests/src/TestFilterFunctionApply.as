/**
 * Test case: exhaustive coverage for Function.apply / Function.call rewrites.
 * Expected behavior:
 * - cover all valid arities for apply (0, 1 and 2 args) and call (0, >=1 args)
 * - null/undefined/parens null thisArg handling in apply
 * - typed bound method closures rewrite to ASCompatMacro.applyBoundMethod
 * - apply(null|undefined, args) on non-bound closures rewrites to ASCompatMacro.applyClosure
 * - receivers that still resolve to typed methods through aliases keep ASCompatMacro.applyBoundMethod
 * - non-null thisArg keeps Reflect.callMethod fallback
 */
package {
	public class TestFilterFunctionApply {
		public var value:int = 0;

		public function TestFilterFunctionApply() {
			var f:Function = plain;

			// apply(): no args / one arg / two args
			f.apply();
			f.apply(null);
			f.apply(this);
			f.apply(null, [1, 2]);
			f.apply(undefined, [3, 4]);

			// call(): no args / null fast-path / fallback path
			f.call();
			f.call(null, 5, 6);
			f.call(this, 7, 8);
			f.call(undefined, 9, 10);

			// Typed bound method closure: should use ASCompatMacro.applyBoundMethod for apply(null|undefined, args)
			this.add.apply(null, [11]);
			this.add.apply(undefined, [12]);
			(this.add).apply((null), [13]);
			this.add.apply(null);
			this.add.call(null, 14);

			// Non-null thisArg keeps Reflect.callMethod path
			this.add.apply(this, [15]);
			this.add.call(this, 16);

			// Alias receiver: still resolves to the typed method and keeps the bound-method macro rewrite
			var dyn:* = this;
			dyn.add.apply(null, [17]);
			dyn.add.apply(undefined, [18]);
			dyn.add.call(null, 19);
			dyn.add.call(dyn, 20);

			// Non-bound function closure reference: apply(null|undefined, args) uses applyClosure
			var methodRef:Function = this.add;
			methodRef.apply(null, [21]);
			methodRef.apply(this, [22]);
			methodRef.call(null, 23);
			methodRef.call(this, 24);
		}

		public function add(v:int):void {
			value += v;
		}

		public static function plain(a:int = 0, b:int = 0):int {
			return a + b;
		}
	}
}
