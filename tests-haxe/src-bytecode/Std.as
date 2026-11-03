package
{
   import flash.Boot;
   
   public class Std
   {
      
      public function Std()
      {
      }
      
      public static function isOfType(v:*, t:*) : Boolean
      {
         return Boot.__instanceof(v,t);
      }
      
      public static function string(s:*) : String
      {
         return Boot.__string_rec(s,"");
      }
   }
}

