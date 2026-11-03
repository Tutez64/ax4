package haxe.ds._ObjectMap
{
   import flash.Boot;
   
   public class NativePropertyIterator
   {
      
      public var index:int;
      
      public var collection:*;
      
      public function NativePropertyIterator()
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         index = 0;
      }
      
      public function next() : *
      {
         var i:int = index;
         var result:* = §§nextname(i,collection);
         index = i;
         return result;
      }
      
      public function hasNext() : Boolean
      {
         var c:* = collection;
         var i:int = index;
         var result:Boolean = §§hasnext(c,i);
         collection = c;
         index = i;
         return result;
      }
   }
}

