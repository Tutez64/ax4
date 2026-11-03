package haxe.ds
{
   import flash.Boot;
   import flash.utils.Dictionary;
   import haxe.IMap;
   import haxe.ds._IntMap.IntMapKeysIterator;
   
   public class IntMap implements IMap
   {
      
      public var h:Dictionary;
      
      public function IntMap()
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         h = new Dictionary();
      }
      
      public function keys() : Object
      {
         return new IntMapKeysIterator(h);
      }
      
      public function get(_tmp_key:Object) : Object
      {
         var key:int = int(_tmp_key);
         return h[key];
      }
   }
}

