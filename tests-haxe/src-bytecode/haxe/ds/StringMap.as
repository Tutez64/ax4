package haxe.ds
{
   import flash.Boot;
   import haxe.IMap;
   import haxe.ds._StringMap.StringMapKeysIterator;
   
   public class StringMap implements IMap
   {
      
      public static var reserved:Object = {};
      
      public var rh:*;
      
      public var h:*;
      
      public function StringMap()
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         h = {};
      }
      
      public function setReserved(key:String, value:Object) : void
      {
         if(rh == null)
         {
            rh = {};
         }
         rh["$" + key] = value;
      }
      
      public function keys() : Object
      {
         return new StringMapKeysIterator(h,rh);
      }
      
      public function getReserved(key:String) : Object
      {
         if(rh == null)
         {
            return null;
         }
         return rh["$" + key];
      }
      
      public function get(_tmp_key:Object) : Object
      {
         var key:String = _tmp_key;
         if(key in StringMap.reserved)
         {
            return getReserved(key);
         }
         return h[key];
      }
      
      public function existsReserved(key:String) : Boolean
      {
         if(rh == null)
         {
            return false;
         }
         return "$" + key in rh;
      }
   }
}

