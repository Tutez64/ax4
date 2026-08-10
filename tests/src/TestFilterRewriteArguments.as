/**
 * Test case for RewriteArguments filter.
 * Covers:
 * - arguments in a basic function (single decl, multiple uses).
 * - arguments with rest args (concat).
 * - nested functions get their own arguments.
 * - a parameter literally named `arguments` must stay a normal parameter
 *   (shadows the AS3 arguments object; must not inject var arguments = [...]).
 */
package {
public class TestFilterRewriteArguments {
    public function testBasic(a:int, b:String):void {
        trace(arguments.length);
        var args:Array = arguments;
        trace(args[0]);
    }

    public function testRest(a:int, ...rest):void {
        trace(arguments.length);
    }

    public function testNested(a:int):void {
        var outerArgs:Array = arguments;
        var f:Function = function(b:int):void {
            trace(arguments.length);
        };
        trace(outerArgs.length);
    }

    public function processArguments(arguments:Array):void {
        trace(arguments.length);
        var first:* = arguments[0];
        trace(first);
    }
}
}
