package haxe.iterators
{
   import flash.Boot;
   
   public class ArrayIterator
   {
      
      public var array:Array;
      
      public function ArrayIterator(array:Array = undefined)
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         this.array = array;
      }
   }
}

