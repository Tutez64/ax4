package haxe.ds._IntMap
{
   import flash.Boot;
   import flash.utils.Dictionary;
   
   public class IntMapKeysIterator
   {
      
      public var nextIndex:int;
      
      public var index:int;
      
      public var h:Dictionary;
      
      public function IntMapKeysIterator(h:Dictionary = undefined)
      {
         if(Boot.skip_constructor)
         {
            return;
         }
         this.h = h;
         index = 0;
         var _loc2_:Dictionary = this.h;
         var _loc3_:int = index;
         var _loc4_:Boolean = §§hasnext(_loc2_,_loc3_);
         nextIndex = _loc3_;
      }
      
      public function next() : int
      {
         var r:int = §§nextname(nextIndex,h);
         index = nextIndex;
         return r;
      }
      
      public function hasNext() : Boolean
      {
         var h:Dictionary = this.h;
         var index:int = this.index;
         var n:Boolean = §§hasnext(h,index);
         nextIndex = index;
         return n;
      }
   }
}

