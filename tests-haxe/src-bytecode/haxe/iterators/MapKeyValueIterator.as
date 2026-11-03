package haxe.iterators
{
   import flash.Boot;
   import haxe.IMap;
   
   public class MapKeyValueIterator
   {
      
      public var map:IMap;
      
      public var keys:Object;
      
      public function MapKeyValueIterator(map:IMap = undefined)
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         this.map = map;
         keys = map.keys();
      }
      
      public function next() : Object
      {
         var key:Object = keys.next();
         return {
            "value":map.get(key),
            "key":key
         };
      }
      
      public function hasNext() : Boolean
      {
         return Boolean(keys.hasNext());
      }
   }
}

