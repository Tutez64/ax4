/**
 * Package-level function (camelCase).
 * Wrapped as: final class HelperFunc { public static function helperFunc(...); }
 * Same-package ref to SharedState must become SharedState.SharedState_.
 */
package wrapModuleLevelDecls {
	public function helperFunc(value:int):int {
		return value + SharedState;
	}
}
