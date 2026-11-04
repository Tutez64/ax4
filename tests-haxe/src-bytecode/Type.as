package
{
   import flash.Boot;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;
   import haxe.Exception;
   
   public class Type
   {
      
      public function Type()
      {
      }
      
      public static function createEmptyInstance(cl:Class) : Object
      {
         var i:* = null as Object;
         var _g:* = null;
         var e:* = null;
         try
         {
            Boot.skip_constructor = true;
            i = new cl();
            Boot.skip_constructor = false;
            return i;
         }
         catch(_loc_e_:*)
         {
            e = Exception.caught(_g).unwrap();
            Boot.skip_constructor = false;
            throw Exception.thrown(e);
         }
      }
      
      public static function §typeof§(v:*) : ValueType
      {
         var c:* = null;
         var _g:* = null;
         var cname:String = getQualifiedClassName(v);
         var _loc4_:String = cname;
         if(_loc4_ == "Boolean")
         {
            return ValueType.TBool;
         }
         if(_loc4_ == "Function")
         {
            return ValueType.TFunction;
         }
         if(_loc4_ == "Number")
         {
            if((v < -268435456 || v >= 268435456) && int(Number(v)) == v)
            {
               return ValueType.TInt;
            }
            return ValueType.TFloat;
         }
         if(_loc4_ == "Object")
         {
            return ValueType.TObject;
         }
         if(_loc4_ == "int")
         {
            return ValueType.TInt;
         }
         if(_loc4_ == "null")
         {
            return ValueType.TNull;
         }
         if(_loc4_ == "void")
         {
            return ValueType.TNull;
         }
         c = null;
         try
         {
            c = getDefinitionByName(cname);
            if(v.hasOwnProperty("prototype"))
            {
               return ValueType.TObject;
            }
            if(c.__isenum)
            {
               return ValueType.TEnum(c);
            }
            return ValueType.TClass(c);
         }
         catch(_loc_e_:*)
         {
            _g = _loc_e_;
            if(cname == "builtin.as$0::MethodClosure" || cname.indexOf("-") != -1)
            {
               return ValueType.TFunction;
            }
            if(c == null)
            {
               return ValueType.TFunction;
            }
            return ValueType.TClass(c);
         }
      }
   }
}

