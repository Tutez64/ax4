package haxe.ds._StringMap
{
   import flash.Boot;
   
   public class StringMapKeysIterator
   {
      
      public var rh:*;
      
      public var nextIndex:int;
      
      public var isReserved:Boolean;
      
      public var index:int;
      
      public var h:*;
      
      public function StringMapKeysIterator(h:* = undefined, rh:* = undefined)
      {
         var _loc6_:* = null;
         var _loc7_:int = 0;
         if(Boot.skip_constructor)
         {
            return;
         }
         this.h = h;
         this.rh = rh;
         index = 0;
         isReserved = false;
         var _loc3_:* = this.h;
         var _loc4_:int = index;
         var _loc5_:Boolean = §§hasnext(_loc3_,_loc4_);
         if(!_loc5_ && this.rh != null)
         {
            _loc3_ = this.h = this.rh;
            _loc4_ = index = 0;
            this.rh = null;
            isReserved = true;
            _loc5_ = §§hasnext(_loc3_,_loc4_);
         }
         nextIndex = _loc4_;
      }
      
      public function next() : String
      {
         var r:String = §§nextname(nextIndex,h);
         index = nextIndex;
         if(isReserved)
         {
            r = r.substr(1);
         }
         return r;
      }
      
      public function hasNext() : Boolean
      {
         var _loc4_:* = null;
         var _loc5_:int = 0;
         var h:* = this.h;
         var index:int = this.index;
         var n:Boolean = §§hasnext(h,index);
         if(!n && rh != null)
         {
            h = this.h = rh;
            index = this.index = 0;
            rh = null;
            isReserved = true;
            n = §§hasnext(h,index);
         }
         nextIndex = index;
         return n;
      }
   }
}

