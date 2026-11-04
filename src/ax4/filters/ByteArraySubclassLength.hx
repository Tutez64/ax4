package ax4.filters;

/**
	Sets `length` on an instance of a ByteArray subclass through the ByteArray abstract:
	`(packet : ByteArray).length = n`. A subclass extends ASByteArrayBase, an OpenFL ByteArrayData
	whose own `length` (from haxe.io.Bytes) cannot be written; the abstract's setter resizes it.
**/
class ByteArraySubclassLength extends AbstractFilter {
	static function findByteArrayClass(cls:TClassOrInterfaceDecl):Null<TClassOrInterfaceDecl> {
		var c = cls;
		while (c != null) {
			switch c.kind {
				case TClass({extend: extend}) if (extend != null):
					var superClass = extend.superClass;
					if (superClass.name == "ByteArray" && superClass.parentModule != null
						&& ["flash.utils", "openfl.utils"].contains(superClass.parentModule.parentPack.name)) {
						return superClass;
					}
					c = superClass;
				case _:
					return null;
			}
		}
		return null;
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(lhs = {kind: TEField(obj = {kind: TOExplicit(dot, eobj), type: TTInst(cls)}, "length", token)}, op = OpAssign(_) | OpAssignOp(_), value)
				if (findByteArrayClass(cls) != null):
				var byteArrayType = TTInst(findByteArrayClass(cls));
				// GenHaxe prints the retype as (eobj : ByteArray), with eobj's leading trivia before it
				var retyped = mk(TEHaxeRetype(eobj), byteArrayType, byteArrayType);
				e.with(kind = TEBinop(lhs.with(kind = TEField({kind: TOExplicit(dot, retyped), type: byteArrayType}, "length", token)), op, value));
			case _:
				e;
		}
	}
}
