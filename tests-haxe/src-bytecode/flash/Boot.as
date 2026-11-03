package flash
{
   import flash.display.MovieClip;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.filters.GlowFilter;
   import flash.text.TextField;
   import flash.text.TextFieldAutoSize;
   import flash.text.TextFormat;
   import flash.utils.ByteArray;
   import flash.utils.Endian;
   import flash.utils.getQualifiedClassName;
   import flash.utils.setTimeout;
   import haxe.Exception;
   import haxe.iterators.ArrayIterator;
   import haxe.iterators.ArrayKeyValueIterator;
   
   public class Boot extends MovieClip
   {
      
      public static var tf:TextField;
      
      public static var lines:Array;
      
      public static var lastError:Error;
      
      public static var skip_constructor:Boolean = false;
      
      public static var IN_E:int = 0;
      
      public function Boot()
      {
         if(!Boot.skip_constructor)
         {
            super();
         }
      }
      
      public static function enum_to_string(e:Object) : String
      {
         var _g:int = 0;
         var _g1:* = null as Array;
         var p:* = null;
         if(e.params == null)
         {
            return e.tag;
         }
         var pstr:Array = [];
         if(Boot.IN_E > 15)
         {
            pstr.push("...");
         }
         else
         {
            ++Boot.IN_E;
            _g = 0;
            _g1 = e.params;
            while(_g < int(_g1.length))
            {
               p = _g1[_g];
               _g++;
               pstr.push(Boot.__string_rec(p,""));
            }
            --Boot.IN_E;
         }
         return e.tag + "(" + pstr.join(",") + ")";
      }
      
      public static function __instanceof(v:*, t:*) : Boolean
      {
         var _g:* = null;
         try
         {
            if(t == Dynamic)
            {
               return v != null;
            }
            return v is t;
         }
         catch(_loc_e_:*)
         {
            _g = _loc_e_;
            return false;
         }
      }
      
      public static function __clear_trace() : void
      {
         if(Boot.tf == null)
         {
            return;
         }
         Boot.tf.parent.removeChild(Boot.tf);
         Boot.tf = null;
         Boot.lines = null;
      }
      
      public static function __set_trace_color(rgb:uint) : void
      {
         var tf:TextField = Boot.getTrace();
         tf.textColor = rgb;
         tf.filters = [];
      }
      
      public static function getTrace() : TextField
      {
         var color:int = 0;
         var glow:int = 0;
         var format:* = null as TextFormat;
         var mc:MovieClip = Lib.current;
         if(Boot.tf == null)
         {
            Boot.tf = new TextField();
            color = 16777215;
            glow = 0;
            if(mc.stage != null)
            {
               glow = int(mc.stage.color);
               color = 16777215 - glow;
            }
            Boot.tf.textColor = color;
            Boot.tf.filters = [new GlowFilter(glow,1,2,2,20)];
            format = Boot.tf.getTextFormat();
            format.font = "_sans";
            Boot.tf.defaultTextFormat = format;
            Boot.tf.selectable = false;
            Boot.tf.width = mc.stage == null ? 800 : mc.stage.stageWidth;
            Boot.tf.autoSize = TextFieldAutoSize.LEFT;
            Boot.tf.mouseEnabled = false;
         }
         if(mc.stage == null)
         {
            mc.addChild(Boot.tf);
         }
         else
         {
            mc.stage.addChild(Boot.tf);
         }
         return Boot.tf;
      }
      
      public static function __trace(v:*, pos:Object) : void
      {
         var _loc6_:int = 0;
         var _loc7_:* = null as Array;
         var _loc8_:* = null;
         var _loc3_:TextField = Boot.getTrace();
         var _loc4_:String = pos == null ? "(null)" : pos.fileName + ":" + int(pos.lineNumber);
         if(Boot.lines == null)
         {
            Boot.lines = [];
         }
         var _loc5_:String = _loc4_ + ": " + Boot.__string_rec(v,"");
         if(pos != null && pos.customParams != null)
         {
            _loc6_ = 0;
            _loc7_ = pos.customParams;
            while(_loc6_ < int(_loc7_.length))
            {
               _loc8_ = _loc7_[_loc6_];
               _loc6_++;
               _loc5_ += "," + Boot.__string_rec(_loc8_,"");
            }
         }
         Boot.lines = Boot.lines.concat(_loc5_.split("\n"));
         _loc3_.text = Boot.lines.join("\n");
         var _loc9_:Stage = Lib.current.stage;
         if(_loc9_ == null)
         {
            return;
         }
         while(int(Boot.lines.length) > 1 && _loc3_.height > _loc9_.stageHeight)
         {
            Boot.lines.shift();
            _loc3_.text = Boot.lines.join("\n");
         }
      }
      
      public static function __string_rec(v:*, str:String, maxRecursion:int = 5) : String
      {
         var _loc6_:* = null as String;
         var _loc7_:* = null as String;
         var _loc8_:* = null;
         var _loc9_:Boolean = false;
         var _loc10_:* = null as Array;
         var _loc11_:* = 0;
         var _loc12_:int = 0;
         var _loc13_:int = 0;
         var _loc14_:* = null as Array;
         var _loc15_:* = null as String;
         if(maxRecursion <= 0)
         {
            return "<...>";
         }
         var _loc5_:String = getQualifiedClassName(v);
         _loc6_ = _loc5_;
         if(_loc6_ == "Array")
         {
            if(v == Array)
            {
               return "#Array";
            }
            _loc7_ = "[";
            _loc9_ = true;
            _loc10_ = v;
            _loc11_ = 0;
            _loc12_ = int(_loc10_.length);
            while(_loc11_ < _loc12_)
            {
               _loc13_ = _loc11_++;
               if(_loc9_)
               {
                  _loc9_ = false;
               }
               else
               {
                  _loc7_ += ",";
               }
               _loc7_ += Boot.__string_rec(_loc10_[_loc13_],str,maxRecursion - 1);
            }
            return _loc7_ + "]";
         }
         if(_loc6_ == "Object")
         {
            _loc11_ = 0;
            _loc14_ = [];
            _loc8_ = v;
            for(_loc11_ in _loc8_)
            {
               _loc14_.push(_loc11_);
            }
            _loc10_ = _loc14_;
            _loc7_ = "{";
            _loc9_ = true;
            _loc11_ = 0;
            _loc12_ = int(_loc10_.length);
            while(_loc11_ < _loc12_)
            {
               _loc13_ = _loc11_++;
               _loc15_ = _loc10_[_loc13_];
               if(_loc15_ == "toString")
               {
                  try
                  {
                     return v.toString();
                  }
                  catch(_loc_e_:*)
                  {
                     _loc8_ = _loc_e_;
                  }
               }
               if(_loc9_)
               {
                  _loc9_ = false;
               }
               else
               {
                  _loc7_ += ",";
               }
               _loc7_ += " " + _loc15_ + " : " + Boot.__string_rec(v[_loc15_],str,maxRecursion - 1);
            }
            if(!_loc9_)
            {
               _loc7_ += " ";
            }
            return _loc7_ + "}";
         }
         _loc6_ = typeof v;
         if(_loc6_ == "function")
         {
            return "<function>";
         }
         if(_loc6_ == "undefined")
         {
            return "null";
         }
         return new String(v);
      }
      
      public static function fromCodePoint(code:int) : String
      {
         var o:ByteArray = new ByteArray();
         o.endian = Endian.LITTLE_ENDIAN;
         o.writeShort((code >> 10) + 55232);
         o.writeShort((code & 0x03FF) + 56320);
         o.position = 0;
         return o.readMultiByte(4,"unicode");
      }
      
      public static function __unprotect__(s:String) : String
      {
         return s;
      }
      
      public static function mapDynamic(d:*, f:*) : *
      {
         if(d is Array)
         {
            return d["mapHX"](f);
         }
         return d["map"](f);
      }
      
      public static function filterDynamic(d:*, f:*) : *
      {
         if(d is Array)
         {
            return d["filterHX"](f);
         }
         return d["filter"](f);
      }
      
      public function start() : void
      {
         var _g:* = null;
         var c:MovieClip = Lib.current;
         try
         {
            if(c == this && c.stage != null && c.stage.align == "")
            {
               c.stage.align = "TOP_LEFT";
            }
         }
         catch(_loc_e_:*)
         {
            _g = _loc_e_;
         }
         if(c.stage == null)
         {
            c.addEventListener(Event.ADDED_TO_STAGE,doInitDelay);
         }
         else if(c.stage.stageWidth == 0 || c.stage.stageHeight == 0)
         {
            setTimeout(start,1);
         }
         else
         {
            init();
         }
      }
      
      public function init() : void
      {
         throw Exception.thrown("assert");
      }
      
      public function doInitDelay(_:*) : void
      {
         Lib.current.removeEventListener(Event.ADDED_TO_STAGE,doInitDelay);
         start();
      }
   }
}

import haxe.Exception;
import haxe.iterators.ArrayIterator;
import haxe.iterators.ArrayKeyValueIterator;

Date;
d.prototype["toString"] = function():String
{
   var date:Date = this;
   var m:int = int(date.getMonth()) + 1;
   var d:int = int(date.getDate());
   var h:int = int(date.getHours());
   var mi:int = int(date.getMinutes());
   var s:int = int(date.getSeconds());
   return int(date.getFullYear()) + "-" + (m < 10 ? "0" + m : "" + m) + "-" + (d < 10 ? "0" + d : "" + d) + " " + (h < 10 ? "0" + h : "" + h) + ":" + (mi < 10 ? "0" + mi : "" + mi) + ":" + (s < 10 ? "0" + s : "" + s);
};
Array.prototype;
aproto.setPropertyIsEnumerable("copy",false);
aproto.setPropertyIsEnumerable("insert",false);
aproto.setPropertyIsEnumerable("contains",false);
aproto.setPropertyIsEnumerable("remove",false);
aproto.setPropertyIsEnumerable("iterator",false);
aproto.setPropertyIsEnumerable("keyValueIterator",false);
aproto.setPropertyIsEnumerable("resize",false);
aproto["filter"] = function(f:Function):Array
{
   var ret:Array = [];
   var i:int = 0;
   var l:int = int(this.length);
   while(i < l)
   {
      if(Boolean(f(this[i])))
      {
         ret.push(this[i]);
      }
      i++;
   }
   return ret;
};
aproto["map"] = function(f:Function):Array
{
   var ret:Array = [];
   var i:int = 0;
   var l:int = int(this.length);
   while(i < l)
   {
      ret.push(f(this[i]));
      i++;
   }
   return ret;
};
aproto.setPropertyIsEnumerable("map",false);
aproto.setPropertyIsEnumerable("filter",false);

