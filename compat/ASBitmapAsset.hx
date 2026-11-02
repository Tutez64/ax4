#if !macro
/**
	Base of an image [Embed] class, which AS3 makes a Bitmap (BitmapAsset).
	OpenFL embeds `@:bitmap` on a BitmapData subclass only, so each subclass gets
	a companion `Name__BitmapData` holding its `@:bitmap`, shown by this Bitmap.
**/
@:autoBuild(ASBitmapAssetMacro.build())
class ASBitmapAsset extends flash.display.Bitmap {
	public function new() {
		super();
		bitmapData = __createBitmapAssetData();
	}

	function __createBitmapAssetData():flash.display.BitmapData {
		return null;
	}
}
#end
