package haxe.ds
{
   import flash.Boot;
   import flash.utils.Dictionary;
   import haxe.IMap;
   import haxe.ds._ObjectMap.NativePropertyIterator;
   
   public dynamic class ObjectMap extends Dictionary implements IMap
   {
      
      public function ObjectMap()
      {
         if(!Boot.skip_constructor)
         {
            super(false);
         }
      }
      
      public function keys() : Object
      {
         var result:NativePropertyIterator = new NativePropertyIterator();
         result.collection = this;
         return result;
      }
      
      public function get(_tmp_key:Object) : Object
      {
         var key:Object = _tmp_key;
         return this[key];
      }
   }
}

