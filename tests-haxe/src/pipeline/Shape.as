package pipeline
{
   import flash.Boot;
   
   public class Shape
   {
      
      public var name:String;
      
      public function Shape(name:String = undefined)
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         this.name = name;
      }
      
      public function area() : Number
      {
         return 0;
      }
   }
}

