package pipeline
{
   import flash.Boot;
   
   public class Shape
   {
      
      public var storedSize:int;
      
      public var name:String;
      
      public function Shape(name:String = undefined)
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         storedSize = 1;
         this.name = name;
      }
      
      public function set_size(v:int) : int
      {
         storedSize = v * 10;
         return v;
      }
      
      public function set size(value:int) : void
      {
         set_size(value);
      }
      
      public function get_size() : int
      {
         return storedSize;
      }
      
      public function get size() : int
      {
         return get_size();
      }
      
      public function get_label() : String
      {
         return "shape";
      }
      
      public function get label() : String
      {
         return get_label();
      }
      
      public function area() : Number
      {
         return 0;
      }
   }
}

