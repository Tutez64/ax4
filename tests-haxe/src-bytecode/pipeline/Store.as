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
      
      public var anyMap:IMap;
      
      public function Store()
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         anyMap = new IntMap();
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
      
      public function total() : int
      {
         var _loc11_:* = null;
         var _loc12_:int = 0;
         var _loc13_:Boolean = false;
         var _loc14_:* = null as String;
         var _loc15_:* = null as String;
         var _loc16_:* = null as StringMap;
         var _loc1_:int = 0;
         var _loc2_:StringMap = byName;
         var _loc3_:* = _loc2_.h;
         var _loc4_:* = _loc2_.rh;
         var _loc5_:int = 0;
         var _loc6_:Boolean = false;
         var _loc7_:* = _loc3_;
         var _loc8_:int = _loc5_;
         var _loc9_:Boolean = §§hasnext(_loc7_,_loc8_);
         if(!_loc9_ && _loc4_ != null)
         {
            _loc3_ = _loc4_;
            _loc7_ = _loc3_;
            _loc5_ = 0;
            _loc8_ = _loc5_;
            _loc4_ = null;
            _loc6_ = true;
            _loc9_ = §§hasnext(_loc7_,_loc8_);
         }
         var _loc10_:int = _loc8_;
         while(true)
         {
            _loc11_ = _loc3_;
            _loc12_ = _loc5_;
            _loc13_ = §§hasnext(_loc11_,_loc12_);
            if(!_loc13_ && _loc4_ != null)
            {
               _loc3_ = _loc4_;
               _loc11_ = _loc3_;
               _loc5_ = 0;
               _loc12_ = _loc5_;
               _loc4_ = null;
               _loc6_ = true;
               _loc13_ = §§hasnext(_loc11_,_loc12_);
            }
            _loc10_ = _loc12_;
            if(!_loc13_)
            {
               break;
            }
            _loc14_ = §§nextname(_loc10_,_loc3_);
            _loc5_ = _loc10_;
            if(_loc6_)
            {
               _loc14_ = _loc14_.substr(1);
            }
            _loc15_ = _loc14_;
            _loc16_ = byName;
            _loc1_ += _loc15_ in StringMap.reserved ? _loc16_.getReserved(_loc15_) : _loc16_.h[_loc15_];
         }
         return _loc1_;
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
      
      public function putAny(k:int, v:String) : void
      {
         var m:IntMap = IntMap(anyMap);
         m.h[k] = v;
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
      
      public function joinedNames() : String
      {
         var _loc8_:* = null as Dictionary;
         var _loc9_:int = 0;
         var _loc10_:Boolean = false;
         var _loc11_:* = null as String;
         var _loc12_:* = null as String;
         var _loc1_:Array = [];
         var _loc2_:Dictionary = byId.h;
         var _loc3_:int = 0;
         var _loc4_:Dictionary = _loc2_;
         var _loc5_:int = _loc3_;
         var _loc6_:Boolean = §§hasnext(_loc4_,_loc5_);
         var _loc7_:int = _loc5_;
         while(true)
         {
            _loc8_ = _loc2_;
            _loc9_ = _loc3_;
            _loc10_ = §§hasnext(_loc8_,_loc9_);
            _loc7_ = _loc9_;
            if(!_loc10_)
            {
               break;
            }
            _loc11_ = §§nextvalue(_loc7_,_loc2_);
            _loc3_ = _loc7_;
            _loc12_ = _loc11_;
            _loc1_.push(_loc12_);
         }
         var _loc13_:Array = _loc1_;
         _loc13_.sort(Reflect.compare);
         return _loc13_.join("+");
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
      
      public function anyKeys() : String
      {
         var _loc8_:* = null as Dictionary;
         var _loc9_:int = 0;
         var _loc10_:Boolean = false;
         var _loc11_:int = 0;
         var _loc1_:Dictionary = IntMap(anyMap).h;
         var _loc2_:int = 0;
         var _loc3_:Dictionary = _loc1_;
         var _loc4_:int = _loc2_;
         var _loc5_:Boolean = §§hasnext(_loc3_,_loc4_);
         var _loc6_:int = _loc4_;
         var _loc7_:Array = [];
         while(true)
         {
            _loc8_ = _loc1_;
            _loc9_ = _loc2_;
            _loc10_ = §§hasnext(_loc8_,_loc9_);
            _loc6_ = _loc9_;
            if(!_loc10_)
            {
               break;
            }
            _loc11_ = §§nextname(_loc6_,_loc1_);
            _loc2_ = _loc6_;
            _loc7_.push(_loc11_);
         }
         _loc7_.sort(Reflect.compare);
         return _loc7_.join("+");
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

