/**
 * Test case: AS3 XML literals fail by default; with skipXmlLiterals they become
 * a preserved block comment plus `null` (typical for unused Flash/Facebook JS bridges).
 * Expected: conversion succeeds and the Haxe output contains commented XML then `null`.
 */
package {
    public class TestSkipXmlLiterals {
        private const script_js:XML = <script>
				<![CDATA[
					function() {
						return 1;
					}
				]]>
			</script>;

        public function TestSkipXmlLiterals() {
            var localXml:XML = <root attr="x"><child/></root>;
            trace(script_js, localXml);
        }
    }
}
