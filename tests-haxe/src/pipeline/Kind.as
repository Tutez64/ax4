package pipeline
{
   import flash.Boot;
   
   public final class Kind
   {
      
      public static const __isenum:Boolean = true;
      
      public static var Small:Kind = new Kind("Small",0,null);
      
      public static var __constructs__:Array = ["Small","Big"];
      
      public var tag:String;
      
      public var index:int;
      
      public var params:Array;
      
      public const __enum__:Boolean = true;
      
      public function Kind(tag:String, index:int, params:Array)
      {
         this.tag = tag;
         this.index = index;
         this.params = params;
      }
      
      public static function Big(size:int) : Kind
      {
         return new Kind("Big",1,[size]);
      }
      
      final public function toString() : String
      {
         return Boot.enum_to_string(this);
      }
   }
}

