package haxe
{
   import flash.Boot;
   
   public class ValueException extends Exception
   {
      
      public var value:*;
      
      public function ValueException(value:* = undefined, previous:Exception = undefined, native:* = undefined)
      {
         if(!Boot.skip_constructor)
         {
            super(value == null ? "null" : Std.string(value),previous,native);
            this.value = value;
         }
      }
      
      override public function unwrap() : *
      {
         return value;
      }
   }
}

