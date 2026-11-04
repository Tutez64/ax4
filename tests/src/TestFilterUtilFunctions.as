/**
 * Test case: exhaustive coverage for UtilFunctions rewrites.
 * Expect rewrites for:
 * - flash.utils.getDefinitionByName -> ASCompat.getDefinitionByName (takes the AS3 pkg::Name form too)
 * - flash.utils.getTimer -> flash.Lib.getTimer
 * - flash.utils.describeType -> ASCompat.describeType
 * - flash.utils.getQualifiedClassName / avmplus.getQualifiedClassName -> ASCompat.getQualifiedClassName
 * - flash.profiler.showRedrawRegions -> ASCompat.showRedrawRegions
 * - flash.utils set/clear timeout/interval -> ASCompat helpers
 * - flash.net.navigateToURL -> flash.Lib.getURL
 */
package {
    import flash.utils.getDefinitionByName;
    import flash.utils.getTimer;
    import flash.utils.describeType;
    import flash.utils.getQualifiedClassName;
    import flash.utils.setTimeout;
    import flash.utils.clearTimeout;
    import flash.utils.setInterval;
    import flash.utils.clearInterval;
    import flash.net.navigateToURL;
    import flash.net.URLRequest;
    import flash.profiler.showRedrawRegions;

    public class TestFilterUtilFunctions {
        public function TestFilterUtilFunctions() {
        }

        public function check(value:*):String {
            var cls:Class = getDefinitionByName("flash.display.Sprite");
            var desktop:Object = getDefinitionByName("flash.desktop::NativeApplication");
            var now:int = getTimer();
            var xml:XML = describeType(value);
            var q1:String = getQualifiedClassName(value);
            var q2:String = avmplus.getQualifiedClassName(value);
            var timeoutId:uint = setTimeout(function():void {}, 1);
            var intervalId:uint = setInterval(function():void {}, 1);
            clearTimeout(timeoutId);
            clearInterval(intervalId);
            navigateToURL(new URLRequest("https://example.com"), "_self");
            showRedrawRegions(false, 0);
            return q1 + ":" + q2 + ":" + now + ":" + (cls != null) + ":" + xml.name();
        }
    }
}
