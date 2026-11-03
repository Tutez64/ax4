package pipeline._Tools
{
   import flash.Boot;
   
   public class Counter
   {
      
      public var n:int;
      
      public function Counter()
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         n = 0;
      }
   }
}

