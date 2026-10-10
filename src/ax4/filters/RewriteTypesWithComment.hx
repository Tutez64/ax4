package ax4.filters;

using StringTools;

/**
	A trailing `// Array<T>` comment types an untyped Array local, and `// Dictionary<K, V>` or `// Object<V>`
	types a `new Dictionary()`/`new Object()` and the local it initializes. Later reads of a retyped local
	take its new type, so the rest of the pipeline sees what the Haxe output declares.
**/
class RewriteTypesWithComment extends AbstractFilter {
	var retyped = new Map<TVar, Bool>();
	var retypedNews = new Map<TExpr, Bool>();

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		switch e.kind {
			case TELocal(_, v) if (retyped.exists(v)):
				return e.with(type = v.type);

			case TEVars(_, [decl]):
				var type = switch decl.v.type {
					case TTArray(_):
						commentType(decl.syntax.name.pos, ["Array<"]);
					case TTDictionary(_) | TTObject(_) if (decl.init != null && retypedNews.exists(decl.init.expr)):
						decl.init.expr.type;
					case _:
						null;
				}
				if (type != null && !typeEq(type, decl.v.type)) {
					decl.v.type = type;
					retyped[decl.v] = true;
					// The retyped `new` initializer now matches the local; an Array literal keeps its own type.
					if (decl.init != null && typeEq(decl.init.expr.type, type)) {
						decl.init.expr = decl.init.expr.with(expectedType = type);
					}
				}

			// A read from a retyped Dictionary/Object was typed before it: give it the value type.
			case TEArrayAccess({eobj: {type: TTDictionary(_, valueType) | TTObject(valueType)}}) if (typeEq(e.type, TTAny) && !typeEq(valueType, TTAny)):
				return e.with(type = valueType);

			case TENew(keyword, TNType({type: TTDictionary(_) | TTObject(_), syntax: syntax = TPath(path)}), args):
				var type = commentType(path.first.pos, ["Dictionary<", "Object<"]);
				if (type != null) {
					var eNew = e.with(kind = TENew(keyword, TNType({type: type, syntax: syntax}), args), type = type);
					retypedNews[eNew] = true;
					return eNew;
				}

			case _:
		}
		return e;
	}

	function commentType(pos:Int, prefixes:Array<String>):Null<TType> {
		var content = context.fileLoader.getContent(currentPath);
		var lineEnd = content.indexOf("\n", pos);
		if (lineEnd < 0) lineEnd = content.length;
		var commentStart = content.indexOf("//", pos);
		if (commentStart < 0 || commentStart > lineEnd) return null;
		var text = content.substring(commentStart + 2, lineEnd).trim();
		for (prefix in prefixes) {
			if (text.startsWith(prefix) && text.endsWith(">")) {
				return tree.getType(text);
			}
		}
		return null;
	}
}
