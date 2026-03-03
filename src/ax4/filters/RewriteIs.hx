package ax4.filters;

import ax4.ParseTree;
using StringTools;

class RewriteIs extends AbstractFilter {
	static final tStdIs = TTFun([TTAny, TTAny], TTBoolean);
	static final tIsFunction = TTFun([TTAny], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(a, OpIs(isToken), b):
				if (isByteArrayTypeExpr(b)) {
					final isByteArray = mkBuiltin("ASCompat.isByteArray", tIsFunction, removeLeadingTrivia(e));
					e.with(kind = TECall(isByteArray, {
						openParen: mkOpenParen(),
						args: [{expr: a, comma: null}],
						closeParen: mkCloseParen(removeTrailingTrivia(e)),
					}));
				} else switch b.kind {
					case TEBuiltin(_, "Function"):
						final isFunction = mkBuiltin("Reflect.isFunction", tIsFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(isFunction, {
							openParen: mkOpenParen(),
							args: [{expr: a, comma: null}],
							closeParen: mkCloseParen(removeTrailingTrivia(e)),
						}));

					case TEBuiltin(objectToken, "Object"):
						// only `null` is failing the `is object` check, so we can convert this to `!= null`
						var neqToken = new Token(isToken.pos, TkExclamationEquals, "!=", isToken.leadTrivia, isToken.trailTrivia);
						var nullToken = new Token(objectToken.pos, TkIdent, "null", objectToken.leadTrivia, objectToken.trailTrivia);
						var nullExpr = mk(TELiteral(TLNull(nullToken)), TTAny, TTAny);
						e.with(kind = TEBinop(a, OpNotEquals(neqToken), nullExpr));

					case TEVector(_, elemType):
						var eIsVectorMethod = mkBuiltin("ASCompat.isVector", TTFunction, removeLeadingTrivia(e));
						e.with(kind = TECall(eIsVectorMethod, {
							openParen: mkOpenParen(),
							args: [
								{expr: a, comma: commaWithSpace},
								{expr: RewriteAs.mkVectorTypeCheckMacroArg(elemType), comma: null}
							],
							closeParen: mkCloseParen(removeTrailingTrivia(e))
						}));

					case _:
						final stdIs = mkBuiltin("Std.isOfType", tStdIs, removeLeadingTrivia(e));
						e.with(kind = TECall(stdIs, {
							openParen: mkOpenParen(),
							args: [
								{expr: a, comma: commaWithSpace},
								{expr: b, comma: null},
							],
							closeParen: mkCloseParen(removeTrailingTrivia(e)),
						}));
				}
			case _:
				e;
		}
	}

	static function isByteArrayTypeExpr(e:TExpr):Bool {
		switch e.kind {
			case TEBuiltin(_, name):
				if (name == "ByteArray" || name.endsWith(".ByteArray")) {
					return true;
				}
			case TEDeclRef(path, c):
				switch c.kind {
					case TDClassOrInterface(cls):
						if (isByteArrayClass(cls)) {
							return true;
						}
					case _:
				}
				var name = ParseTree.dotPathToString(path);
				if (name == "ByteArray" || name.endsWith(".ByteArray")) {
					return true;
				}
			case _:
		}

		return switch e.type {
			case TTStatic(cls) | TTInst(cls):
				isByteArrayClass(cls);
			case _:
				false;
		}
	}

	static function isByteArrayClass(cls:TClassOrInterfaceDecl):Bool {
		if (cls.name != "ByteArray") {
			return false;
		}
		var pack = cls.parentModule.parentPack.name;
		return pack == "" || pack == "flash.utils" || pack == "openfl.utils";
	}
}
