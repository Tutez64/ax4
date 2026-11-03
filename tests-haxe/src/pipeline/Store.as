package pipeline
{
   import flash.Boot;
   import flash.utils.Dictionary;
   import haxe.IMap;
   import haxe.ds.IntMap;
   import haxe.ds.ObjectMap;
   import haxe.ds.StringMap;
   import haxe.ds._StringMap.StringMapKeysIterator;
   
   public class Store
   {
      
      public var tags:ObjectMap;
      
      public var byName:StringMap;
      
      public var byId:IntMap;
      
      public function Store()
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         tags = new ObjectMap();
         byId = new IntMap();
         byName = new StringMap();
      }
      
      public static function first(it:Object) : String
      {
         if(Boolean(it.hasNext()))
         {
            return it.next();
         }
         return "-";
      }
      
      public function tagOf(c:Circle) : String
      {
         if(tags[c] != null)
         {
            return tags[c];
         }
         return "none";
      }
      
      public function tag(c:Circle, s:String) : void
      {
         tags[c] = s;
      }
      
      public function sumMap(m:IMap) : int
      {
         var k1:* = null as String;
         var t:int = 0;
         var k:* = m.keys();
         while(Boolean(k.hasNext()))
         {
            k1 = k.next();
            t += m.get(k1);
         }
         return t;
      }
      
      public function reset() : void
      {
         var _this:StringMap = byName;
         _this.h = {};
         _this.rh = null;
         byId.h = new Dictionary();
      }
      
      public function nameOf(id:int) : String
      {
         var _this:IntMap = byId;
         if(id in _this.h)
         {
            return byId.h[id];
         }
         return "?";
      }
      
      public function idOf(name:String) : int
      {
         var _loc3_:* = null as StringMap;
         var _loc2_:StringMap = byName;
         if(name in StringMap.reserved ? _loc2_.existsReserved(name) : name in _loc2_.h)
         {
            _loc3_ = byName;
            if(name in StringMap.reserved)
            {
               return _loc3_.getReserved(name);
            }
            return _loc3_.h[name];
         }
         return -1;
      }
      
      public function firstName() : String
      {
         var _this:StringMap = byName;
         return Store.first(new StringMapKeysIterator(_this.h,_this.rh));
      }
      
      public function add(name:String, id:int) : void
      {
         var _this:StringMap = byName;
         if(name in StringMap.reserved)
         {
            _this.setReserved(name,id);
         }
         else
         {
            _this.h[name] = id;
         }
         byId.h[id] = name;
      }
   }
}

