package ax4.filters;

/**
	Rewrites what code compiled with Haxe uses of flash.Boot, which only exists on the flash
	target (see Main.haxeCompiled):

	- `if (Boot.skip_constructor) return;` at the start of a constructor is removed, and
	  `if (!Boot.skip_constructor) { ... }` (JPEXS's form when super() follows) is replaced by its
	  body: skip_constructor is only true inside Type.createEmptyInstance, which does not run the
	  constructor on other targets.
	- `Boot.enum_to_string(e)`, the toString of a Haxe enum compiled to a class, calls
	  ASCompat.haxeEnumToString.
	- `Boot.fromCodePoint(c)` calls ASCompat.fromCodePoint (String.fromCharCode, which takes any code point in Haxe).

	The flash.Boot import is dropped.
**/
class HaxeCompiledCode extends AbstractFilter {
	static function isBoot(c:TClassOrInterfaceDecl):Bool {
		return c.name == "Boot" && c.parentModule != null && c.parentModule.parentPack.name == "flash";
	}

	static function isBootObject(obj:TFieldObject):Bool {
		return switch obj.kind {
			case TOExplicit(_, {kind: TEDeclRef(_, {kind: TDClassOrInterface(c)})}): isBoot(c);
			case _: false;
		}
	}

	static function getBootField(e:TExpr):Null<String> {
		return switch e.kind {
			case TEParens(_, inner, _): getBootField(inner);
			case TEField(obj, name, _) if (isBootObject(obj)): name;
			case _: null;
		}
	}

	static function isSkipConstructor(e:TExpr):Bool {
		return getBootField(e) == "skip_constructor";
	}

	static function isNotSkipConstructor(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): isNotSkipConstructor(inner);
			case TEPreUnop(PreNot(_), inner): isSkipConstructor(inner);
			case _: false;
		}
	}

	static function isReturnOnly(e:TExpr):Bool {
		return switch e.kind {
			case TEReturn(_, null): true;
			case TEBlock(b): b.exprs.length == 1 && isReturnOnly(b.exprs[0].expr);
			case _: false;
		}
	}

	override function processImport(i:TImport):Bool {
		return switch i.kind {
			case TIDecl({kind: TDClassOrInterface(c)}) if (isBoot(c)): false;
			case _: true;
		}
	}

	override function processExpr(e:TExpr):TExpr {
		if (!Main.haxeCompiled) {
			return e;
		}
		switch e.kind {
			case TEBlock(block):
				// drop the skip_constructor checks before processing the statements, which would report them
				var exprs = [];
				for (be in block.exprs) {
					switch be.expr.kind {
						case TEIf({econd: econd, ethen: ethen, eelse: null}) if (isSkipConstructor(econd) && isReturnOnly(ethen)):
						case TEIf({econd: econd, ethen: {kind: TEBlock(body)}, eelse: null}) if (isNotSkipConstructor(econd)):
							for (inner in body.exprs) exprs.push(inner);
						case _:
							exprs.push(be);
					}
				}
				e = e.with(kind = TEBlock({syntax: block.syntax, exprs: exprs}));
			// rewrite the calls before processing their method, which would report it
			case TECall({kind: TEField(obj, "enum_to_string", _)}, args) if (isBootObject(obj)):
				var eMethod = mkBuiltin("ASCompat.haxeEnumToString", TTFun([TTAny], TTString), removeLeadingTrivia(e));
				return e.with(kind = TECall(eMethod, mapCallArgs(processExpr, args)));

			case TECall({kind: TEField(obj, "fromCodePoint", _)}, args) if (isBootObject(obj)):
				var eMethod = mkBuiltin("ASCompat.fromCodePoint", TTFun([TTInt], TTString), removeLeadingTrivia(e));
				return e.with(kind = TECall(eMethod, mapCallArgs(processExpr, args)));

			case _:
		}
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case _:
				if (getBootField(e) != null) {
					reportError(exprPos(e), "Unhandled flash.Boot member: " + getBootField(e));
				}
				e;
		}
	}
}
