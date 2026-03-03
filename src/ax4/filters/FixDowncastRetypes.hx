package ax4.filters;

class FixDowncastRetypes extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEHaxeRetype(inner):
				if (isNullLiteral(inner)) {
					return mkNullExpr(e.type, removeLeadingTrivia(e), removeTrailingTrivia(e));
				}
				switch e.type {
					case TTInst(toCls) if (isMovieClipClass(toCls) && isChildLookup(inner)):
						wrapCast(inner, toCls, e);
					case _:
						switch [inner.type, e.type] {
							case [TTInst(_), TTInst(toCls)]:
								switch determineCastKind(inner.type, toCls) {
									case CKDowncast:
										wrapCast(inner, toCls, e);
									case _ if (isMovieClipClass(toCls) && isDisplayObjectLike(inner.type)):
										wrapCast(inner, toCls, e);
									case _:
										e;
								}
							case _:
								e;
						}
				}
			case _:
				e;
		}
	}

	function isNullLiteral(e:TExpr):Bool {
		return switch e.kind {
			case TELiteral(TLNull(_)):
				true;
			case TEParens(_, inner, _):
				isNullLiteral(inner);
			case TEHaxeRetype(inner):
				isNullLiteral(inner);
			case _:
				false;
		}
	}

	function isDisplayObjectLike(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				isFlashDisplayClass(cls, "DisplayObject")
					|| isFlashDisplayClass(cls, "DisplayObjectContainer")
					|| isFlashDisplayClass(cls, "InteractiveObject");
			case _:
				false;
		}
	}

	function isChildLookup(e:TExpr):Bool {
		return switch e.kind {
			case TECall(eobj, _):
				switch eobj.kind {
					case TEField(_, fieldName, _):
						fieldName == "getChildByName" || fieldName == "getChildAt";
					case _:
						false;
				}
			case _:
				false;
		}
	}

	function isMovieClipClass(cls:TClassOrInterfaceDecl):Bool {
		return isFlashDisplayClass(cls, "MovieClip");
	}

	function isFlashDisplayClass(cls:TClassOrInterfaceDecl, name:String):Bool {
		if (cls.name != name) return false;
		var pack = cls.parentModule != null ? cls.parentModule.parentPack.name : "";
		return pack == "flash.display" || pack == "openfl.display";
	}

	function wrapCast(inner:TExpr, targetClass:TClassOrInterfaceDecl, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		var eMethod = mkBuiltin("cast", TTFunction, lead);
		var fullName = targetClass.parentModule != null && targetClass.parentModule.path == currentPath
			? targetClass.name
			: (targetClass.parentModule.parentPack.name == "" ? targetClass.name : targetClass.parentModule.parentPack.name + "." + targetClass.name);
		var path = dotPathFromString(fullName, []);
		var eType = mkDeclRef(path, {name: targetClass.name, kind: TDClassOrInterface(targetClass)}, null);
		var targetType = TTInst(targetClass);
		return mk(TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [
				{expr: inner, comma: commaWithSpace},
				{expr: eType, comma: null}
			],
			closeParen: mkCloseParen(trail)
		}), targetType, targetType);
	}

	function dotPathFromString(path:String, lead:Array<Trivia>):DotPath {
		var parts = path.split(".");
		var first = mkIdent(parts[0], lead, []);
		var rest = [];
		for (i in 1...parts.length) {
			rest.push({sep: mkDot(), element: mkIdent(parts[i])});
		}
		return {first: first, rest: rest};
	}
}
