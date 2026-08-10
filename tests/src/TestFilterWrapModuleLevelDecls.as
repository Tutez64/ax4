/**
 * Test case: WrapModuleLevelDecls must rewrite TEDeclRefs to wrapped
 * package-level vars/functions into ClassName.fieldName access.
 *
 * When the AS3 var name equals the Haxe wrapper class name (PascalCase),
 * the static field is renamed (RootLike -> RootLike_) because Haxe cannot
 * resolve ClassName.ClassName even with a fully qualified path.
 *
 * Expected:
 * - wrapModuleLevelDecls.RootLike.RootLike_ = ...
 * - wrapModuleLevelDecls.HelperFunc.helperFunc(...)
 * - inside helperFunc: RootLike.RootLike_
 */
package {
	public class TestFilterWrapModuleLevelDecls {
		public function run():int {
			wrapModuleLevelDecls.RootLike = 5;
			return wrapModuleLevelDecls.RootLike + wrapModuleLevelDecls.helperFunc(1);
		}
	}
}
