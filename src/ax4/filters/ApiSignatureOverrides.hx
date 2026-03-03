package ax4.filters;

private enum CoerceKind {
	ToInt;
	ToUInt;
	ToNumber;
	Retype;
}

private typedef ArgOverride = {
	var index:Int;
	var target:TType;
	var coerce:CoerceKind;
	var allowNull:Bool;
}

private typedef CallOverride = {
	var owner:String;
	var name:String;
	var args:Array<ArgOverride>;
	var isCtor:Bool;
}

private typedef FieldOverride = {
	var owner:String;
	var name:String;
	var target:String;
}

class ApiSignatureOverrides extends AbstractFilter {
	static final overrides:Array<CallOverride> = [
		// TextFormat(color) accepts Object in SWC, but Haxe expects Int/Null<Int>
		{owner: "flash.text.TextFormat", name: "new", isCtor: true, args: [
			{index: 2, target: TTInt, coerce: ToInt, allowNull: true}
		]},
		{owner: "openfl.text.TextFormat", name: "new", isCtor: true, args: [
			{index: 2, target: TTInt, coerce: ToInt, allowNull: true}
		]},
		// Error(message, id) expects int for id in Haxe externs
		{owner: "flash.errors.Error", name: "new", isCtor: true, args: [
			{index: 1, target: TTInt, coerce: ToInt, allowNull: true}
		]},
		{owner: "openfl.errors.Error", name: "new", isCtor: true, args: [
			{index: 1, target: TTInt, coerce: ToInt, allowNull: true}
		]},
		{owner: "Error", name: "new", isCtor: true, args: [
			{index: 1, target: TTInt, coerce: ToInt, allowNull: true}
		]},
		{owner: "flash.display.DisplayObjectContainer", name: "setChildIndex", isCtor: false, args: [
			{index: 1, target: TTInt, coerce: ToInt, allowNull: false}
		]}
	];
	static final fieldOverrides:Array<FieldOverride> = [
		// Some externs expose `responseHeaders` as Array<Dynamic>, but runtime values are URLRequestHeader items.
		{owner: "flash.events.HTTPStatusEvent", name: "responseHeaders", target: "Array<flash.net.URLRequestHeader>"},
		{owner: "openfl.events.HTTPStatusEvent", name: "responseHeaders", target: "Array<flash.net.URLRequestHeader>"},
		// SWC types currentLabels as Array, but runtime values are FrameLabel items.
		{owner: "flash.display.MovieClip", name: "currentLabels", target: "Array<flash.display.FrameLabel>"},
		{owner: "openfl.display.MovieClip", name: "currentLabels", target: "Array<flash.display.FrameLabel>"}
	];

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TENew(keyword, obj, args):
				var nextArgs = applyCtorOverrides(obj, args);
				if (nextArgs == args) e else e.with(kind = TENew(keyword, obj, nextArgs));
			case TECall(eobj, args):
				var nextArgs = applyCallOverrides(eobj, args);
				if (nextArgs == args) e else e.with(kind = TECall(eobj, nextArgs));
			case TEField(obj, name, _):
				applyFieldOverride(e, obj, name);
			case _:
				e;
		}
	}

	function applyCtorOverrides(obj:TNewObject, args:Null<TCallArgs>):Null<TCallArgs> {
		if (args == null) return args;
		var cls = switch obj {
			case TNType(tref): typeToClass(tref.type);
			case TNExpr(e): typeToClass(e.type);
		};
		if (cls == null) return args;
		return applyOverrides(args, cls, "new", true);
	}

	function applyCallOverrides(eobj:TExpr, args:TCallArgs):TCallArgs {
		var info = extractCallTarget(eobj);
		if (info == null) return args;
		return applyOverrides(args, info.cls, info.name, false);
	}

	function applyOverrides(args:TCallArgs, cls:TClassOrInterfaceDecl, name:String, isCtor:Bool):TCallArgs {
		var fqn = classFqn(cls);
		var changed = false;
		var nextArgs = args.args.copy();
		for (rule in overrides) {
			if (rule.isCtor != isCtor || rule.name != name || !ownerMatches(cls, fqn, rule.owner)) continue;
			for (argRule in rule.args) {
				if (argRule.index >= args.args.length) continue;
				var current = args.args[argRule.index];
				var nextExpr = coerceArg(current.expr, argRule);
				if (nextExpr != current.expr) {
					nextArgs[argRule.index] = {expr: nextExpr, comma: current.comma};
					changed = true;
				}
			}
		}
		return changed ? args.with(args = nextArgs) : args;
	}

	function coerceArg(e:TExpr, rule:ArgOverride):TExpr {
		if (rule.allowNull && e.kind.match(TELiteral(TLNull(_)))) {
			return e;
		}
		return switch rule.coerce {
			case ToInt:
				coerceToInt(e);
			case ToUInt:
				coerceToUInt(e);
			case ToNumber:
				coerceToNumber(e);
			case Retype:
				wrapRetype(e, rule.target);
		}
	}

	function coerceToInt(e:TExpr):TExpr {
		return switch e.type {
			case TTInt:
				e;
			case _:
				wrapToInt(e);
		}
	}

	function coerceToUInt(e:TExpr):TExpr {
		return switch e.type {
			case TTUint:
				e;
			case _:
				wrapRetype(wrapToInt(e), TTUint);
		}
	}

	function coerceToNumber(e:TExpr):TExpr {
		return switch e.type {
			case TTNumber:
				e;
			case _:
				wrapToNumber(e);
		}
	}

	function wrapToInt(e:TExpr):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var toInt = mkBuiltin("ASCompat.toInt", TTFun([TTAny], TTInt), lead);
		return mkCall(toInt, [e.with(expectedType = e.type)], TTInt, trail);
	}

	function wrapToNumber(e:TExpr):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var toNumber = mkBuiltin("ASCompat.toNumber", TTFun([TTAny], TTNumber), lead);
		return mkCall(toNumber, [e.with(expectedType = e.type)], TTNumber, trail);
	}

	function wrapRetype(e:TExpr, t:TType):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var wrapped = mk(TEHaxeRetype(e), t, t);
		processLeadingToken(tok -> tok.leadTrivia = lead.concat(tok.leadTrivia), wrapped);
		processTrailingToken(tok -> tok.trailTrivia = tok.trailTrivia.concat(trail), wrapped);
		return wrapped;
	}

	function applyFieldOverride(e:TExpr, obj:TFieldObject, name:String):TExpr {
		var cls = typeToClass(obj.type);
		if (cls == null) return e;
		var fqn = classFqn(cls);
		for (rule in fieldOverrides) {
			if (rule.name != name || !ownerMatches(cls, fqn, rule.owner)) continue;
			var targetType = tree.getType(rule.target);
			if (e.type == targetType) return e;
			return e.with(type = targetType, expectedType = targetType);
		}
		return e;
	}

	static function extractCallTarget(eobj:TExpr):Null<{cls:TClassOrInterfaceDecl, name:String}> {
		return switch eobj.kind {
			case TEField(obj, name, _):
				var cls = typeToClass(obj.type);
				if (cls == null) null else {cls: cls, name: name};
			case _:
				null;
		}
	}

	static function typeToClass(t:TType):Null<TClassOrInterfaceDecl> {
		return switch t {
			case TTInst(c) | TTStatic(c):
				c;
			case _:
				null;
		}
	}

	static function classFqn(c:TClassOrInterfaceDecl):String {
		var pack = c.parentModule.parentPack.name;
		return pack == "" ? c.name : pack + "." + c.name;
	}

	static function ownerMatches(cls:TClassOrInterfaceDecl, fqn:String, owner:String):Bool {
		if (owner == fqn) return true;
		if (owner.indexOf(".") == -1) return owner == cls.name;
		return false;
	}
}
