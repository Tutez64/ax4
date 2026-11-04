package pipeline
{
   import flash.Boot;
   
   public class Circle extends Shape
   {
      
      public var radius:Number;
      
      public function Circle(radius:Number = 0)
      {
         if(!Boot.skip_constructor)
         {
            super("circle");
            this.radius = radius;
         }
      }
      
      override public function get_label() : String
      {
         return "circle " + radius;
      }
      
      override public function area() : Number
      {
         return Math.PI * radius * radius;
      }
   }
}

