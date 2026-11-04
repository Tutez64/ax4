package
{
   public class Reflect
   {
      
      public function Reflect()
      {
      }
      
      public static function compare(a:Object, b:Object) : int
      {
         var a1:* = a;
         var b1:* = b;
         if(a1 == b1)
         {
            return 0;
         }
         if(a1 > b1)
         {
            return 1;
         }
         return -1;
      }
   }
}

