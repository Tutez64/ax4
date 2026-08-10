/**
 * Package-level function (camelCase).
 * Wrapped as: final class HelperFunc { public static function helperFunc(...); }
 * Same-package ref to RootLike must become RootLike.RootLike_.
 */
package wrapModuleLevelDecls {
	public function helperFunc(value:int):int {
		return value + RootLike;
	}
}
