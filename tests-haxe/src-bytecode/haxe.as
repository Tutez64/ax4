package
{
   import flash.Boot;
   import flash.Lib;
   import flash.display.MovieClip;
   
   [SWF(width="400", height="300", backgroundColor="#ffffff", frameRate="30")]
   public class haxe extends Boot
   {
      
      public function haxe()
      {
         if(!Boot.skip_constructor)
         {
            super();
         }
      }
      
      public static function initSwc(mc:MovieClip) : void
      {
         Lib.current = mc;
         new haxe().init();
      }
      
      override public function init() : void
      {
      }
   }
}

