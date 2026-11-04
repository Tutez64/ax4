package ax4;

import ax4.TypedTree;

/**
	The Haxe standard library types that code compiled with Haxe refers to (see Main.haxeCompiled).
	They are not converted: the Haxe output uses Haxe's own, which can be generic or live in
	another module than their compiled class.
**/
class HaxeStd {
	/** Type parameters of the generic Haxe std types, by compiled path: ASAny, or the constraint where there is one. **/
	static final typeParams = [
		"haxe.ds.StringMap" => ["ASAny"],
		"haxe.ds.IntMap" => ["ASAny"],
		"haxe.ds.ObjectMap" => ["{}", "ASAny"],
		"haxe.ds.WeakMap" => ["{}", "ASAny"],
		"haxe.ds.EnumValueMap" => ["EnumValue", "ASAny"],
		"haxe.ds.BalancedTree" => ["ASAny", "ASAny"],
		"haxe.ds.GenericStack" => ["ASAny"],
		"haxe.ds.List" => ["ASAny"],
		"haxe.ds.Vector" => ["ASAny"],
		"haxe.IMap" => ["ASAny", "ASAny"],
		"haxe.iterators.ArrayIterator" => ["ASAny"],
		"haxe.iterators.ArrayKeyValueIterator" => ["ASAny"],
		"haxe.iterators.MapKeyValueIterator" => ["ASAny", "ASAny"],
	];

	/** Haxe std types declared in another module than their compiled path. **/
	static final modulePaths = [
		"haxe.IMap" => "haxe.Constraints.IMap",
		"ValueType" => "Type.ValueType",
	];

	static function compiledPath(cls:TClassOrInterfaceDecl):Null<String> {
		if (!Main.haxeCompiled || cls.parentModule == null) {
			return null;
		}
		var pack = cls.parentModule.parentPack.name;
		return if (pack == "") cls.name else pack + "." + cls.name;
	}

	/** The `<ASAny, ...>` a generic Haxe std type needs, or "". **/
	public static function getTypeParams(cls:TClassOrInterfaceDecl):String {
		var path = compiledPath(cls);
		var params = path == null ? null : typeParams[path];
		return params == null ? "" : "<" + params.join(", ") + ">";
	}

	/** The full path of a Haxe std type declared in another module than its compiled path, or `otherwise`. **/
	public static function getModulePath(cls:TClassOrInterfaceDecl, otherwise:String):String {
		var path = compiledPath(cls);
		var modulePath = path == null ? null : modulePaths[path];
		return modulePath == null ? otherwise : modulePath;
	}
}
