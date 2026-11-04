package pipeline
{
   import flash.Boot;
   import haxe.Exception;
   import pipeline._Tools.Counter;
   
   public class Tools
   {
      
      public function Tools()
      {
      }
      
      public static function scale(x:Number, factor:Object = undefined) : Number
      {
         if(factor == null)
         {
            factor = 2;
         }
         return x * factor;
      }
      
      public static function kindName(k:Kind) : String
      {
         var size:int = 0;
         switch(k.index)
         {
            case 0:
               return "small";
            case 1:
               size = int(k.params[0]);
               return "big" + size;
            default:
               return undefined;
         }
      }
      
      public static function radiusOf(s:Shape) : Number
      {
         var c:Circle = Circle(s);
         return c.radius;
      }
      
      public static function safeParse(s:String) : String
      {
         var _g:* = null;
         var _g1:* = null;
         var e:* = null as String;
         try
         {
            if(s == "")
            {
               throw Exception.thrown("empty");
            }
            return "ok " + s;
         }
         catch(_loc_e_:*)
         {
            _g = _loc_e_;
            _g1 = Exception.caught(_g).unwrap();
            if(_g1 is String)
            {
               e = _g1;
               return "caught " + e;
            }
            throw _g;
         }
      }
      
      public static function count(times:int) : int
      {
         var i:int = 0;
         var c:Counter = new Counter();
         var _g:int = 0;
         var _g1:int = times;
         while(_g < _g1)
         {
            i = _g++;
            ++c.n;
         }
         return c.n;
      }
      
      public static function isFunction(x:*) : Boolean
      {
         return Type.§typeof§(x) == ValueType.TFunction;
      }
      
      public static function emoji() : String
      {
         if(Boot.fromCodePoint(128512).length > 0)
         {
            return "yes";
         }
         return "no";
      }
   }
}

