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
 */
package {
	public class TestFilterWrapModuleLevelDecls {
		public function run():int {
			wrapModuleLevelDecls.SharedState = 5;
			return wrapModuleLevelDecls.SharedState + wrapModuleLevelDecls.helperFunc(1);
		}
	}
}
