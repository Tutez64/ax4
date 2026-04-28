/**
 * Test case: String.replace should accept non-string replacement values.
 * Expected: replacement is coerced to string when using a string pattern.
 * Also covers regex replace/match/search/split and string API rewrites.
 */
package {
    public class TestFilterStringApi {
        public function TestFilterStringApi() {
            var replaceDict:Object = {};
            replaceDict["#NAME"] = "Hero";
            replaceDict["#LEVEL"] = 5;
            var text:String = "#NAME is level #LEVEL";
            var key:String;
            for (key in replaceDict) {
                text = text.replace(key, replaceDict[key]);
            }

            var lower:String = " TeSt ";
            var upper:String = lower.toLocaleUpperCase();
            lower = upper.toLocaleLowerCase();

            var sliceText:String = lower.slice(1, 3);
            var sliceAll:String = lower.slice();
            var concatText:String = "a".concat("b", 1, true);
            var compareValue:int = "a".localeCompare("b");
            var substrAll:String = lower.substr();
            var substringAll:String = lower.substring();

            var regText:String = "aa bb aa";
            var regMatch:Array = regText.match(/a+/g);
            var regSearch:int = regText.search(/b+/);
            var regSplit:Array = regText.split(/\s+/);
            regText = regText.replace(/a+/g, "x");
            regText = regText.replace(/b+/g, function(v:String):String { return v.toUpperCase(); });

            var strSearch:int = regText.search("bb");
            var strSplit:Array = regText.split(" ");
            regText = regText.replace("x", 42);
            regText = regText.replace("y", false);
            regText = regText.replace("z", null);

            // Calling string methods on ASAny/Object should be coerced to String to ensure Haxe
            // uses String methods instead of reflection/dynamic dispatch (which can return [OBJECT GLOBAL]).
            var anyObj:Object = { Name: "hero" };
            var upperAny:String = anyObj.Name.toUpperCase();
            var charAny:String = anyObj.Name.charAt(0);
            var replaceAny:String = anyObj.Name.replace("h", "z");
            var matchAny:Array = anyObj.Name.match(/h/);
            var splitAny:Array = anyObj.Name.split("");
            var searchAny:int = anyObj.Name.search("r");
            var concatAny:String = anyObj.Name.concat("es");
            var localeCompareAny:int = anyObj.Name.localeCompare("hero");

            // Calling string methods on typed objects should NOT be coerced.
            // URLRequestHeader.name is known as String.
            var header:flash.net.URLRequestHeader = new flash.net.URLRequestHeader("x-id", "val");
            var lowerTyped:String = header.name.toLowerCase();

            if (sliceAll == null || substrAll == null || substringAll == null || concatText == null || compareValue == 0 || upperAny == null || charAny == null || lowerTyped == null) {
                trace(sliceAll, substrAll, substringAll, concatText, compareValue);
            }
        }
    }
}
