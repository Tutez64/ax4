package
{
   import flash.Boot;
   import haxe.Exception;
   
   public class Type
   {
      
      public function Type()
      {
      }
      
      public static function createEmptyInstance(cl:Class) : Object
      {
         var i:* = null as Object;
         var _g:* = null;
         var e:* = null;
         try
         {
            Boot.skip_constructor = true;
            i = new cl();
            Boot.skip_constructor = false;
            return i;
         }
         catch(_loc_e_:*)
         {
            e = Exception.caught(_g).unwrap();
            Boot.skip_constructor = false;
            throw Exception.thrown(e);
         }
      }
   }
}

