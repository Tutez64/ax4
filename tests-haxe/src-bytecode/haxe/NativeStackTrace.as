package haxe
{
   public class NativeStackTrace
   {
      
      public function NativeStackTrace()
      {
      }
      
      public static function normalize(stack:String, skipItems:int = 0) : String
      {
         var _loc3_:String = stack.substring(0,6);
         while(true)
         {
            if(_loc3_ != "Error\n")
            {
               if(_loc3_ != "Error:")
               {
                  break;
               }
            }
            skipItems++;
            break;
         }
         return NativeStackTrace.skipLines(stack,skipItems);
      }
      
      public static function skipLines(stack:String, skip:int, pos:int = 0) : String
      {
         if(skip > 0)
         {
            pos = stack.indexOf("\n",pos);
            if(pos < 0)
            {
               return "";
            }
            return NativeStackTrace.skipLines(stack,--skip,pos + 1);
         }
         return stack.substring(pos);
      }
   }
}

