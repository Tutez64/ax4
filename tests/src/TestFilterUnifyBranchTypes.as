/**
 * UnifyBranchTypes: AS3 mixes any types in the branches of c ? a : b and a ?? b, which Haxe must
 * unify. Branches of different kinds (a class instance and a Boolean) are retyped to the expected
 * type, or ASAny; the left side of ?? reading a String field of an API class (OpenFL types
 * TextFormat.align as a TextFormatAlign) is retyped (x : String). Branches of the same kind, or an
 * untyped one, are left alone.
 */
package {
    import flash.text.TextFormat;
    import flash.utils.Dictionary;

    public class TestFilterUnifyBranchTypes {
        private var cache:Dictionary = new Dictionary();
        private var folders:Object = {};

        public function store(key:String, found:TestFilterUnifyBranchTypes, ok:Boolean, format:TextFormat):String {
            cache[key] = found ?? false;
            folders[key] = ok ? found : false;
            var same:TestFilterUnifyBranchTypes = found ?? this;
            var count:Number = ok ? 1 : 2.5;
            var align:String = format.align ?? "left";
            return align + same + count;
        }
    }
}
