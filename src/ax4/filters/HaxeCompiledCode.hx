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

	A property `x(get, set)` compiles to its get_x and set_x methods plus a flash getter
	`get x() { return get_x(); }` and setter `set x(v) { set_x(v); }` for AS3 code: those accessors
	take the methods' functions and the methods are removed, so the Haxe property calls get_x and
	set_x as Haxe declared them (calls to them keep working).

	`flash.Lib.describeType(v)`, from Haxe's flash-only flash.Lib (which other targets remap to
	openfl.Lib, whose describeType returns a Haxe Xml), calls ASCompat.describeType.

	It also calls the private haxe.Exception members that Haxe's throw and catch compile to
	through ASCompat: `Exception.thrown(v)`, `Exception.caught(v)` and `e.unwrap()`.

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

	static function isFlashLibObject(obj:TFieldObject):Bool {
		return switch obj.kind {
			case TOExplicit(_, {kind: TEDeclRef(_, {kind: TDClassOrInterface(c)})}): c.name == "Lib" && c.parentModule != null && c.parentModule.parentPack.name == "flash";
			case _: false;
		}
	}

	static function isException(c:TClassOrInterfaceDecl):Bool {
		return c.name == "Exception" && c.parentModule != null && c.parentModule.parentPack.name == "haxe";
	}

	static function isExceptionObject(obj:TFieldObject):Bool {
		return switch obj.kind {
			case TOExplicit(_, {kind: TEDeclRef(_, {kind: TDClassOrInterface(c)})}): isException(c);
			case _: false;
		}
	}

	static function isExceptionInstance(obj:TFieldObject):Bool {
		return switch obj {
			case {kind: TOExplicit(_, _), type: TTInst(c)}: isException(c) || (c.parentModule != null && c.parentModule.parentPack.name == "haxe" && c.name == "ValueException");
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

	override function processClass(c:TClassOrInterfaceDecl) {
		if (Main.haxeCompiled) {
			mergePropertyAccessors(c);
		}
		super.processClass(c);
	}

	static function mergePropertyAccessors(c:TClassOrInterfaceDecl) {
		var methods = new Map<String, {member:TClassMember, field:TFunctionField}>();
		for (m in c.members) {
			switch m {
				case TMField({kind: TFFun(f)}): methods[f.name] = {member: m, field: f};
				case _:
			}
		}
		var removed = [];
		for (m in c.members) {
			switch m {
				case TMField({kind: TFGetter(a)}):
					var method = methods["get_" + a.name];
					if (method != null && method.field.fun.sig.args.length == 0 && isAccessorStub(a.fun.expr, method.field.name, null)) {
						a.fun = method.field.fun;
						a.isPublicFunction = isPublicMember(method.member);
						removed.push(method.member);
					}
				case TMField({kind: TFSetter(a)}) if (a.fun.sig.args.length == 1):
					var method = methods["set_" + a.name];
					if (method != null && method.field.fun.sig.args.length == 1 && isAccessorStub(a.fun.expr, method.field.name, a.fun.sig.args[0].v)) {
						a.fun = method.field.fun;
						a.isPublicFunction = isPublicMember(method.member);
						removed.push(method.member);
					}
				case _:
			}
		}
		if (removed.length > 0) {
			c.members = [for (m in c.members) if (!removed.contains(m)) m];
		}
	}

	static function isPublicMember(m:TClassMember):Bool {
		return switch m {
			case TMField(f): Lambda.exists(f.modifiers, m -> m.match(FMPublic(_)));
			case _: false;
		}
	}

	/** Whether `e` is `{ return method(); }` (`arg` null) or `{ method(arg); }`, on this or the class. **/
	static function isAccessorStub(e:Null<TExpr>, method:String, arg:Null<TVar>):Bool {
		if (e == null) {
			return false;
		}
		var exprs = switch e.kind {
			case TEBlock(b) if (b.exprs.length == 1): b.exprs[0].expr;
			case _: return false;
		}
		var call = switch exprs.kind {
			case TEReturn(_, call) if (arg == null && call != null): call;
			case _ if (arg != null): exprs;
			case _: return false;
		}
		return switch call.kind {
			case TECall({kind: TEField({kind: TOImplicitThis(_) | TOImplicitClass(_) | TOExplicit(_, {kind: TELiteral(TLThis(_)) | TEDeclRef(_, _)})}, name, _)}, {args: args}) if (name == method):
				if (arg == null) args.length == 0 else args.length == 1 && switch args[0].expr.kind {
					case TELocal(_, v): v == arg;
					case _: false;
				};
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

			case TECall({kind: TEField(obj, "describeType", _)}, args) if (isFlashLibObject(obj)):
				var eMethod = mkBuiltin("ASCompat.describeType", TTFun([TTAny], TTXML), removeLeadingTrivia(e));
				return e.with(kind = TECall(eMethod, mapCallArgs(processExpr, args)), type = TTXML);

			case TECall({kind: TEField(obj, name = "thrown" | "caught", _)}, args) if (isExceptionObject(obj)):
				var method = if (name == "thrown") "ASCompat.haxeThrown" else "ASCompat.haxeCaught";
				var eMethod = mkBuiltin(method, TTFun([TTAny], e.type), removeLeadingTrivia(e));
				return e.with(kind = TECall(eMethod, mapCallArgs(processExpr, args)));

			case TECall({kind: TEField(obj = {kind: TOExplicit(_, eException)}, "unwrap", _)}, {args: []}) if (isExceptionInstance(obj)):
				var lead = removeLeadingTrivia(eException);
				var eMethod = mkBuiltin("ASCompat.haxeUnwrap", TTFun([obj.type], TTAny), lead);
				return mkCall(eMethod, [processExpr(eException)], TTAny, removeTrailingTrivia(e)).with(expectedType = e.expectedType);

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
