package ax4.filters;

import ax4.TypedTree;
import ax4.Token;
import ax4.TokenTools;
import ax4.TypedTreeTools.*;

class CoerceFromAny extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		if (shouldRetypeUntypedArrayLiteral(e)) {
			return retypeUntypedArrayLiteral(e);
		}
		if (!shouldCoerce(e)) {
			return e;
		}
		return switch e.expectedType {
			case TTFunction | TTFun(_):
				wrapAsFunction(e);
			case TTInst(cls) if (isByteArrayClass(cls)):
				wrapAsByteArray(e);
			case TTInst(cls) if (cls.name != "String"):
				wrapDynamicAs(e, cls, e.expectedType);
			case TTObject(TTAny): // ASObject
				wrapDynamicAsType(e, "ASObject", e.expectedType);
			case TTArray(_):
				wrapDynamicAsType(e, "Array", e.expectedType);
			case TTVector(_):
				// Vector cast is tricky, leaving as retype for now
				e.with(kind = TEHaxeRetype(e), type = e.expectedType, expectedType = e.expectedType);
			case _:
				e.with(kind = TEHaxeRetype(e), type = e.expectedType, expectedType = e.expectedType);
		}
	}

	function wrapAsFunction(e:TExpr):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var eMethod = mkBuiltin("ASCompat.asFunction", TTFunction, lead);
		return mk(TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [{expr: e, comma: null}],
			closeParen: mkCloseParen(trail)
		}), e.expectedType, e.expectedType);
	}

	function wrapAsByteArray(e:TExpr):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var eMethod = mkBuiltin("ASCompat.asByteArray", TTFunction, lead);
		return mk(TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [{expr: e, comma: null}],
			closeParen: mkCloseParen(trail)
		}), e.expectedType, e.expectedType);
	}

	function wrapDynamicAs(inner:TExpr, targetClass:TClassOrInterfaceDecl, targetType:TType):TExpr {
		var lead = removeLeadingTrivia(inner);
		var trail = removeTrailingTrivia(inner);
		var eMethod = mkBuiltin("ASCompat.dynamicAs", TTFunction, lead);
		var fullName = targetClass.parentModule != null && targetClass.parentModule.path == currentPath
			? targetClass.name
			: (targetClass.parentModule.parentPack.name == "" ? targetClass.name : targetClass.parentModule.parentPack.name + "." + targetClass.name);
		var path = dotPathFromString(fullName, []);
		var eType = mkDeclRef(path, {name: targetClass.name, kind: TDClassOrInterface(targetClass)}, null);
		return mk(TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [
				{expr: inner, comma: commaWithSpace},
				{expr: eType, comma: null}
			],
			closeParen: mkCloseParen(trail)
		}), targetType, targetType);
	}

	function wrapDynamicAsType(inner:TExpr, typeName:String, targetType:TType):TExpr {
		var lead = removeLeadingTrivia(inner);
		var trail = removeTrailingTrivia(inner);
		var eMethod = mkBuiltin("ASCompat.dynamicAs", TTFunction, lead);
		var path = dotPathFromString(typeName, []);
		var eType = mkBuiltin(typeName, TTClass, [], []);
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

	static function shouldCoerce(e:TExpr):Bool {
		if (!e.type.match(TTAny | TTObject(TTAny) | TTArray(_) | TTVector(_))) {
			return false;
		}

		if (isLiteral(e)) {
			return false;
		}

		return switch [e.type, e.expectedType] {
			case [TTAny | TTObject(TTAny), TTVoid | TTAny | TTObject(TTAny) | TTBoolean | TTString | TTInt | TTUint | TTNumber]:
				false;
			case [TTAny | TTObject(TTAny), _]:
				true;

			case [TTArray(t1), TTArray(t2)] if (isAnyLike(t1) && !isAnyLike(t2)):
				true;
			case [TTVector(t1), TTVector(t2)] if (isAnyLike(t1) && !isAnyLike(t2)):
				true;
			case _:
				false;
		}
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}

	static function isByteArrayClass(cls:TClassOrInterfaceDecl):Bool {
		if (cls.name != "ByteArray") {
			return false;
		}
		var pack = cls.parentModule.parentPack.name;
		return pack == "" || pack == "flash.utils" || pack == "openfl.utils";
	}

	static function isLiteral(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TELiteral(_): true;
			case _: false;
		}
	}

	static function shouldRetypeUntypedArrayLiteral(e:TExpr):Bool {
		var ebase = skipParens(e);
		if (!ebase.type.match(TTArray(TTAny) | TTArray(TTObject(TTAny)))) {
			return false;
		}
		if (!ebase.expectedType.match(TTAny | TTObject(TTAny))) {
			return false;
		}
		return switch ebase.kind {
			case TEArrayDecl(arr):
				hasHeterogeneousElementTypes(arr);
			case _:
				false;
		}
	}

	static function hasHeterogeneousElementTypes(arr:TArrayDecl):Bool {
		if (arr.elements.length < 2) {
			return false;
		}
		var firstType = skipParens(arr.elements[0].expr).type;
		for (i in 1...arr.elements.length) {
			if (!typeEq(skipParens(arr.elements[i].expr).type, firstType)) {
				return true;
			}
		}
		return false;
	}

	static function retypeUntypedArrayLiteral(e:TExpr):TExpr {
		var inner = e.with(expectedType = e.type);
		return e.with(kind = TEHaxeRetype(inner));
	}
}
