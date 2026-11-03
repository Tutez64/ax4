#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

/** Builds the companion BitmapData of an ASBitmapAsset subclass, see ASBitmapAsset. */
class ASBitmapAssetMacro {
	public static function build():Array<Field> {
		var cls = Context.getLocalClass().get();
		var meta = cls.meta.extract(":bitmap");
		if (meta.length == 0) return null;
		var pos = Context.currentPos();
		var dataName = cls.name + "__BitmapData";
		var dataClass = macro class $dataName extends flash.display.BitmapData {};
		dataClass.pack = cls.pack;
		dataClass.meta = [{name: ":bitmap", params: meta[0].params, pos: pos}];
		Context.defineType(dataClass);
		var dataPath:TypePath = {pack: cls.pack, name: dataName};
		var fields = Context.getBuildFields();
		fields.push({
			name: "__createBitmapAssetData",
			access: [AOverride],
			pos: pos,
			kind: FFun({args: [], ret: macro :flash.display.BitmapData, expr: macro return new $dataPath(0, 0)})
		});
		return fields;
	}
}
#end
