package pipeline
{
   import haxe.ds.StringMap;

   /**
    * Written by hand in FFDec's form, which Haxe produces only for some register allocations: a
    * local whose register holds several types is declared untyped, `var m:* = null as StringMap`,
    * and the map methods Haxe inlined read its storage (`m.h[k]`). Checked by the harness.
    */
   public class UntypedMaps
   {
      public function UntypedMaps()
      {
         super();
      }

      public static function run(byName:StringMap) : String
      {
         var _loc2_:* = null as StringMap;
         var _loc3_:* = 0;
         if(byName == null)
         {
            _loc2_ = "none";
            return _loc2_;
         }
         _loc2_ = byName;
         _loc2_.h["untyped"] = 7;
         _loc3_ = "untyped" in _loc2_.h ? _loc2_.h["untyped"] : -1;
         return "untyped=" + _loc3_ + "," + ("missing" in _loc2_.h);
      }
   }
}
