package ax4.filters;

class AlignAccessorTypes extends AbstractFilter {
	override function processClass(c:TClassOrInterfaceDecl) {
		var props = collectProperties(c);
		if (props != null) {
			for (member in c.members) {
				switch member {
					case TMField(f):
						switch f.kind {
							case TFGetter(a):
								var prop = props[a.name];
								if (prop != null && isAnyLike(a.fun.sig.ret.type) && !isAnyLike(prop.type)) {
									a.fun.sig.ret.type = prop.type;
									a.propertyType = prop.type;
								}
							case TFSetter(a):
								var prop = props[a.name];
								if (prop != null && a.fun.sig.args.length > 0) {
									var arg = a.fun.sig.args[0];
									if (isAnyLike(arg.type) && !isAnyLike(prop.type)) {
										arg.type = prop.type;
										a.propertyType = prop.type;
										a.fun.sig.ret.type = prop.type;
									}
								}
							case _:
						}
					case _:
				}
			}
		}
		super.processClass(c);
	}

	function collectProperties(c:TClassOrInterfaceDecl):Null<Map<String, THaxePropDecl>> {
		var map:Map<String, THaxePropDecl> = null;
		for (member in c.members) {
			switch member {
				case TMField(f):
					switch f.kind {
						case TFGetter(a) | TFSetter(a):
							if (a.haxeProperty != null) {
								if (map == null) map = new Map();
								map[a.name] = a.haxeProperty;
							}
						case _:
					}
				case _:
			}
		}
		return map;
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}
}
