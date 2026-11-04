package
{
   import flash.Boot;
   
   public final class ValueType
   {
      
      public static const __isenum:Boolean = true;
      
      public static var TBool:ValueType = new ValueType("TBool",3,null);
      
      public static var TFloat:ValueType = new ValueType("TFloat",2,null);
      
      public static var TFunction:ValueType = new ValueType("TFunction",5,null);
      
      public static var TInt:ValueType = new ValueType("TInt",1,null);
      
      public static var TNull:ValueType = new ValueType("TNull",0,null);
      
      public static var TObject:ValueType = new ValueType("TObject",4,null);
      
      public static var TUnknown:ValueType = new ValueType("TUnknown",8,null);
      
      public static var __constructs__:Array = ["TNull","TInt","TFloat","TBool","TObject","TFunction","TClass","TEnum","TUnknown"];
      
      public var tag:String;
      
      public var index:int;
      
      public var params:Array;
      
      public const __enum__:Boolean = true;
      
      public function ValueType(tag:String, index:int, params:Array)
      {
         this.tag = tag;
         this.index = index;
         this.params = params;
      }
      
      public static function TClass(c:Class) : ValueType
      {
         return new ValueType("TClass",6,[c]);
      }
      
      public static function TEnum(e:Class) : ValueType
      {
         return new ValueType("TEnum",7,[e]);
      }
      
      final public function toString() : String
      {
         return Boot.enum_to_string(this);
      }
   }
}

