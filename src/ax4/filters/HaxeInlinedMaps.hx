package ax4.filters;

/**
	Rewrites the Haxe map methods that code compiled with Haxe (see Main.haxeCompiled) has inlined
	on flash back to calls: their bodies read the maps' flash storage, which Haxe's maps on other
	targets do not have.

	- `m.h[k]`, `m.h[k] = v` and `k in m.h` on a StringMap, IntMap or UnsafeStringMap call get, set
	  and exists; `m[k]` and `m[k] = v` on an ObjectMap (a flash Dictionary) call get and set.
	- StringMap's `k in StringMap.reserved` check, which sends the keys Object reserves (such as
	  "constructor") to setReserved, getReserved and existsReserved, is false: its other branch is
	  the whole method elsewhere.
	- `new StringMapKeysIterator(m.h, m.rh)` and the other keys and values iterators call keys and
	  iterator, and `m.h = {}` (`m.h = new Dictionary()`) with `m.rh = null` calls clear.
	- The imports of the std's module-private iterators are dropped.
**/
class HaxeInlinedMaps extends AbstractFilter {
	static final storageMaps = ["StringMap", "IntMap", "UnsafeStringMap"];
	static final internalFields = ["h", "rh", "setReserved", "getReserved", "existsReserved"];
	static final iteratorPacks = ["haxe.ds._StringMap", "haxe.ds._IntMap", "haxe.ds._UnsafeStringMap"];

	static function isStdMapClass(c:TClassOrInterfaceDecl, names:Array<String>):Bool {
		return c.parentModule != null && c.parentModule.parentPack.name == "haxe.ds" && names.contains(c.name);
	}

	static function isStdMap(e:TExpr, names:Array<String>):Bool {
		return switch e.type {
			case TTInst(c): isStdMapClass(c, names);
			case _: false;
		}
	}

	static function keyType(map:TExpr):TType {
		return switch map.type {
			case TTInst({name: "IntMap"}): TTInt;
			case TTInst({name: "ObjectMap"}): TTAny;
			case _: TTString;
		}
	}

	/** The map whose field `field` (`h` or `rh`) `e` reads, or null. **/
	static function getMapOfField(e:TExpr, field:String):Null<TExpr> {
		return switch skipParens(e).kind {
			case TEField({kind: TOExplicit(_, map)}, name, _) if (name == field && isStdMap(map, storageMaps)): map;
			case _: null;
		}
	}

	/** The map whose storage `e` is: `m.h`, or an ObjectMap itself. **/
	static function getMapOfStorage(e:TExpr):Null<TExpr> {
		var map = getMapOfField(e, "h");
		return if (map != null) map else if (isStdMap(e, ["ObjectMap"])) e else null;
	}

	static function isReservedField(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TEField({kind: TOExplicit(_, {kind: TEDeclRef(_, {kind: TDClassOrInterface(c)})})}, "reserved", _): isStdMapClass(c, ["StringMap"]);
			case _: false;
		}
	}

	static function isReservedCheck(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TEBinop(_, OpIn(_), r): isReservedField(r);
			case _: false;
		}
	}

	static function isClearRest(e:TExpr):Bool {
		return switch e.kind {
			case TEBinop(lhs, OpAssign(_), {kind: TELiteral(TLNull(_))}): getMapOfField(lhs, "rh") != null;
			case _: false;
		}
	}

	override function processImport(i:TImport):Bool {
		return switch i.kind {
			case TIDecl({kind: TDClassOrInterface(c)}) if (Main.haxeCompiled && c.parentModule != null && iteratorPacks.contains(c.parentModule.parentPack.name)): false;
			case _: true;
		}
	}

	override function processExpr(e:TExpr):TExpr {
		if (!Main.haxeCompiled) {
			return e;
		}
		switch e.kind {
			case TEBlock(block):
				var exprs = [];
				for (be in block.exprs) {
					switch be.expr.kind {
						case TEIf({econd: econd, eelse: null}) if (isReservedCheck(econd)):
						case _ if (isClearRest(be.expr)):
						case _: exprs.push(be);
					}
				}
				e = e.with(kind = TEBlock({syntax: block.syntax, exprs: exprs}));

			// the reserved branches are dropped before processing, which would report them
			case TEIf({econd: econd, eelse: eelse}) if (isReservedCheck(econd)):
				var lead = removeLeadingTrivia(e);
				var result = if (eelse != null) processExpr(eelse.expr) else mk(TEBlock({syntax: {openBrace: mkOpenBrace(), closeBrace: mkCloseBrace()}, exprs: []}), TTVoid, TTVoid);
				processLeadingToken(t -> t.leadTrivia = lead, result);
				return result;

			case TETernary({econd: econd, eelse: eelse}) if (isReservedCheck(econd)):
				var lead = removeLeadingTrivia(e);
				var result = processExpr(eelse);
				processLeadingToken(t -> t.leadTrivia = lead, result);
				return result;

			// the storage accesses are rewritten before processing their operands, which would report them
			case TEBinop({kind: TEArrayAccess(a)}, OpAssign(_), value) if (getMapOfStorage(a.eobj) != null):
				var map = getMapOfStorage(a.eobj);
				return mkMapCall(e, map, "set", [a.eindex, value], [keyType(map), TTAny], TTVoid);

			case TEArrayAccess(a) if (getMapOfStorage(a.eobj) != null):
				var map = getMapOfStorage(a.eobj);
				return mkMapCall(e, map, "get", [a.eindex], [keyType(map)], TTAny);

			case TEBinop(key, OpIn(_), storage) if (getMapOfField(storage, "h") != null):
				var map = getMapOfField(storage, "h");
				removeTrailingTrivia(key);
				return mkMapCall(e, map, "exists", [key], [keyType(map)], TTBoolean);

			case TEBinop(lhs, OpAssign(_), _) if (getMapOfField(lhs, "h") != null):
				return mkMapCall(e, getMapOfField(lhs, "h"), "clear", [], [], TTVoid);

			case TENew(_, TNType({type: TTInst(c)}), args) if (c.parentModule != null && iteratorPacks.contains(c.parentModule.parentPack.name)
				&& args != null && args.args.length > 0 && getMapOfField(args.args[0].expr, "h") != null):
				var method = if (StringTools.endsWith(c.name, "KeysIterator")) "keys" else "iterator";
				return mkMapCall(e, getMapOfField(args.args[0].expr, "h"), method, [], [], TTAny);

			case TEField({kind: TOExplicit(_, map)}, name, _) if (isStdMap(map, storageMaps) && internalFields.contains(name)):
				reportError(exprPos(e), "Unhandled access to a Haxe map's internal " + name);

			case _ if (isReservedField(e)):
				reportError(exprPos(e), "Unhandled access to StringMap.reserved");

			case _:
		}
		return mapExpr(processExpr, e);
	}

	/** Calls `map.method(args)` in place of `e`, with the map and the arguments processed. **/
	function mkMapCall(e:TExpr, map:TExpr, method:String, args:Array<TExpr>, argTypes:Array<TType>, ret:TType):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		map = processExpr(map);
		args = args.map(processExpr);
		var methodType = TTFun(argTypes, ret);
		var eMethod = mk(TEField({kind: TOExplicit(mkDot(), map), type: map.type}, method, mkIdent(method)), methodType, methodType);
		var call = mkCall(eMethod, args, ret, trail).with(expectedType = e.expectedType);
		processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), call);
		return call;
	}
}
