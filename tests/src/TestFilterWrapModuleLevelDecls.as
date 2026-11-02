/**
 * Test case: WrapModuleLevelDecls must rewrite TEDeclRefs to wrapped
 * package-level vars/functions into ClassName.fieldName access.
 *
 * When the AS3 var name equals the Haxe wrapper class name (PascalCase),
 * the static field is renamed (SharedState -> SharedState_) because Haxe cannot
 * resolve ClassName.ClassName even with a fully qualified path.
 *
 * Expected:
 * - wrapModuleLevelDecls.SharedState.SharedState_ = ...
 * - wrapModuleLevelDecls.HelperFunc.helperFunc(...)
 * - inside helperFunc: SharedState.SharedState_
 * - `import wrapModuleLevelDecls.helperFunc` imports the wrapper class (`import wrapModuleLevelDecls.HelperFunc`),
 *   so an unqualified `helperFunc(2)` resolves as HelperFunc.helperFunc(2) (Starling imports starling.utils.execute).
 */
package {
	import wrapModuleLevelDecls.helperFunc;

	public class TestFilterWrapModuleLevelDecls {
		public function run():int {
			wrapModuleLevelDecls.SharedState = 5;
			return wrapModuleLevelDecls.SharedState + wrapModuleLevelDecls.helperFunc(1) + helperFunc(2);
		}
	}
}
