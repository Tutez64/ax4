#if flash
class ASByteArrayBase extends flash.utils.ByteArray {
	public function new() {
		super();
	}
}
#else
class ASByteArrayBase extends openfl.utils.ByteArray.ByteArrayData {
	public function new() {
		super();
		// a converted [Embed] class keeps its own new(), which replaces the one Lime's @:file macro adds,
		// so load the resource that macro embedded for it
		var name = Type.getClassName(Type.getClass(this));
		var bytes = haxe.Resource.getBytes("__ASSET__:file_" + name.split(".").join("_"));
		if (bytes != null) {
			__fromBytes(bytes);
		}
	}
}
#end

