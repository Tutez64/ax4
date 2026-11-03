package haxe
{
   import flash.Boot;
   
   public class Exception extends Error
   {
      
      public var __skipStack:int;
      
      public var __previousException:Exception;
      
      public var __nativeStack:String;
      
      public var __nativeException:Error;
      
      public function Exception(message:String = undefined, previous:Exception = undefined, native:* = undefined)
      {
         if(!Boot.skip_constructor)
         {
            super(message);
            __previousException = previous;
            if(native != null && native is Error)
            {
               __nativeException = native;
               __nativeStack = NativeStackTrace.normalize(native.getStackTrace());
            }
            else
            {
               __nativeException = this;
               __nativeStack = NativeStackTrace.normalize(new Error().getStackTrace(),1);
            }
         }
      }
      
      public static function caught(value:*) : Exception
      {
         if(value is Exception)
         {
            return value;
         }
         if(value is Error)
         {
            return new Exception(value.message,null,value);
         }
         return new ValueException(value,null,value);
      }
      
      public static function thrown(value:*) : *
      {
         var e:* = null as ValueException;
         if(value is Exception)
         {
            return value.get_native();
         }
         if(value is Error)
         {
            return value;
         }
         e = new ValueException(value);
         ++e.__skipStack;
         return e;
      }
      
      public function unwrap() : *
      {
         return __nativeException;
      }
      
      final public function get_native() : *
      {
         return __nativeException;
      }
   }
}

