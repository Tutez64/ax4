package ax4.filters;

import ax4.TypedTreeTools;

private typedef Modifiers = {
	final isPublic:Bool;
	final isStatic:Bool;
	final isOverride:Bool;
}

// TODO: cleanup visibility handling because HandleVisibilityModifiers makes it messy for this filter
class HaxeProperties extends AbstractFilter {
	var currentClass:TClassOrInterfaceDecl;
	var currentProperties:Null<Map<String,THaxePropDecl>>;

	override function processClass(c:TClassOrInterfaceDecl) {
		currentClass = c;
		super.processClass(c);
		currentClass = null;
		currentProperties = null;
	}

	override function processClassField(f:TClassField) {
		switch f.kind {
			case TFGetter(field): processGetter(f, field, getMods(f), getFieldLeadingToken(f));
			case TFSetter(field): processSetter(f, field, getMods(f), getFieldLeadingToken(f));
			case TFVar(_) | TFFun(_):
		}
	}

	function addProperty(name:String, set:Bool, type:TType, mods:Modifiers, leadToken:Token, metadata:Array<TMetadata>):Null<THaxePropDecl> {
		// TODO: determine indentation and add it to the accessor method
		var leadTrivia = leadToken.leadTrivia;
		leadToken.leadTrivia = [];

		if (currentProperties == null) currentProperties = new Map();

		var prop = currentProperties[name];
		var isNewProperty = (prop == null);
		if (isNewProperty) {
			prop = {syntax: {leadTrivia: leadTrivia}, name: name, get: false, set: false, type: type, isPublic: mods.isPublic, isStatic: mods.isStatic, isFlashProperty: false, metadata: metadata};
			currentProperties.set(name, prop);
		} else {
			prop.syntax.leadTrivia = prop.syntax.leadTrivia.concat(leadTrivia);
			prop.metadata = prop.metadata.concat(metadata);
			if (isAnyLike(prop.type) && !isAnyLike(type)) {
				prop.type = type;
			}
		}

		if (set) prop.set = true else prop.get = true;

		for (m in metadata) {
			switch m {
				case MetaFlash({name: {text: 'HxForceProp'}}):
					isNewProperty = false;
				case _:
			}
		}

		return if (isNewProperty) prop else null;
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}

	function getMods(f:TClassField):Modifiers {
		// TODO: properly migrate @:allow metadata from the accessor to the property
		var isPublic = false, isStatic = false, isOverride = false;
		for (m in f.modifiers) {
			switch m {
				case FMInternal(_) | FMPublic(_): isPublic = true;
				case FMOverride(_): isOverride = true;
				case FMStatic(_): isStatic = true;
				case FMPrivate(_) | FMProtected(_) | FMFinal(_):
			}
		}
		return {
			isPublic: isPublic || f.namespace != null,
			isStatic: isStatic,
			isOverride: isOverride
		};
	}

	function isImplementingExternProperty(cls:TClassOrInterfaceDecl, name:String, getter:Bool):Bool {
		switch cls.kind {
			case TInterface(_):
				return false;

			case TClass(info):
				function loop(i:Null<TClassImplement>) {
					if (i == null) {
						return false;
					}
					for (entry in i.interfaces) {
						if (!entry.iface.decl.parentModule.isExtern) {
							continue;
						}

						for (m in entry.iface.decl.members) {
							switch m {
								case TMField(f) if (!isFieldStatic(f)):
									switch f.kind {
										case TFGetter(a) if (getter && a.name == name):
											return true;
										case TFSetter(a) if (!getter && a.name == name):
											return true;
										case _:
									}
								case _:
							}
						}

						var info = switch entry.iface.decl.kind { case TInterface(info): info; case TClass(_): throw "assert"; };
						if (loop(info.extend)) {
							return true;
						}
					}
					return false;
				}
				return loop(info.implement);
		}
	}

	function removePublicModifier(field:TClassField) {
		// TODO: handle trivia (if `public` or namespace is the first modifier we probably have an indent whitespace before it)
		field.modifiers = [for (m in field.modifiers) if (!m.match(FMPublic(_))) m];
		field.namespace = null;
	}

	function processGetter(field:TClassField, accessor:TAccessorField, mods:Modifiers, leadToken:Token) {
		var hasSuperSetter = hasSetterInSuper(accessor.name);
		var shouldCreateProperty = !hasAnyAccessorInSuper(accessor.name);
		if (shouldCreateProperty) {
			removePublicModifier(field);
			var prop = addProperty(accessor.name, false, accessor.fun.sig.ret.type, mods, leadToken, removeMetadata(field));
			if (prop != null) {
				accessor.haxeProperty = prop;
				if (hasSuperSetter) {
					prop.set = true;
				}
				if (isImplementingExternProperty(currentClass, accessor.name, true)) {
					// if we implement a property from an swc, we gotta mark with with @:flash.property metadata
					// so actual Flash accessor is generated for it by Haxe
					prop.isFlashProperty = true;
				}
			}
		}
	}

	function processSetter(field:TClassField, accessor:TAccessorField, mods:Modifiers, leadToken:Token) {
		var sig = accessor.fun.sig;
		var arg = sig.args[0];
		var type = arg.type;
		sig.ret = {
			type: type,
			syntax: null
		};

		var hasSuperGetter = hasGetterInSuper(accessor.name);
		var shouldCreateProperty = !hasAnyAccessorInSuper(accessor.name);
		if (shouldCreateProperty) {
			removePublicModifier(field);
		}

		if (accessor.fun.expr != null) {
			// TODO: I think we should ensure that argument local var is never modified, because
			// otherwise the returned value will be different from Flash.

			var argLocal = mk(TELocal(mkIdent(arg.name, [whitespace]), arg.v), arg.v.type, arg.v.type);

			var funExpr = {
				function rewriteReturns(e:TExpr):TExpr {
					return switch e.kind {
						case TELocalFunction(_): e;
						case TEReturn(keyword, null): e.with(kind = TEReturn(keyword, argLocal));
						case _: mapExpr(rewriteReturns, e);
					}
				}
				rewriteReturns(accessor.fun.expr);
			};

			var needsFinalReturn = true;
			// here is an optimization for the majority of setters in AS3/Flash projects:
			// instead of just always adding `return value` to the end of a function,
			// we check if the last expression is an assignment of `value` that preserves the type
			// so instead of `_x = value; return value;` we generate `return _x = value;`
			// which is shorter and nicer :) the code below is stupid and ideally we should also handle
			// this also in rewriteReturns for early returns that contain such assignment just above them,
			// but oh well
			switch funExpr.kind {
				case TEBlock({exprs: exprs}) if (exprs.length > 0):
					var lastBlockExpr = exprs[exprs.length - 1];
					var lastExpr = lastBlockExpr.expr;
					switch lastExpr.kind {
						case TEBinop(_, OpAssign(_), {kind: TELocal(_, v)}) if (v == arg.v && typeEq(lastExpr.type, arg.v.type)):
							needsFinalReturn = false;
							var leadTrivia = removeLeadingTrivia(lastExpr);
							exprs[exprs.length - 1] = {
								expr: lastExpr.with(kind = TEReturn(mkIdent("return", leadTrivia, [whitespace]), lastExpr)),
								semicolon: lastBlockExpr.semicolon
							};
						case _:
					}
				case _:
			}

			if (needsFinalReturn) {
				var finalReturnExpr = mk(TEReturn(mkIdent("return"), argLocal), TTVoid, TTVoid);
				funExpr = concatExprs(funExpr, finalReturnExpr);
			}
			accessor.fun.expr = funExpr;
		}

		if (shouldCreateProperty) {
			var prop = addProperty(accessor.name, true, type, mods, leadToken, removeMetadata(field));
			if (prop != null) {
				accessor.haxeProperty = prop;
				if (hasSuperGetter) {
					prop.get = true;
				}
				if (isImplementingExternProperty(currentClass, accessor.name, false)) {
					// if we implement a property from an swc, we gotta mark with with @:flash.property metadata
					// so actual Flash accessor is generated for it by Haxe
					prop.isFlashProperty = true;
				}
			}
		}
	}

	static function removeMetadata(field:TClassField):Array<TMetadata> {
		var result = field.metadata;
		field.metadata = [];
		return result;
	}

	function hasGetterInSuper(name:String):Bool {
		return hasAccessorInSuper(name, false);
	}

	function hasSetterInSuper(name:String):Bool {
		return hasAccessorInSuper(name, true);
	}

	function hasAnyAccessorInSuper(name:String):Bool {
		return hasGetterInSuper(name) || hasSetterInSuper(name);
	}

	function hasAccessorInSuper(name:String, wantSetter:Bool):Bool {
		var superClass = getSuperClass(currentClass);
		while (superClass != null) {
			for (member in superClass.members) {
				switch member {
					case TMField(f) if (!TypedTreeTools.isFieldStatic(f)):
						switch f.kind {
							case TFGetter(a) if (!wantSetter && a.name == name):
								return true;
							case TFSetter(a) if (wantSetter && a.name == name):
								return true;
							case _:
						}
					case _:
				}
			}
			superClass = getSuperClass(superClass);
		}
		return false;
	}

	static function getSuperClass(c:TClassOrInterfaceDecl):Null<TClassOrInterfaceDecl> {
		if (c == null) return null;
		return switch c.kind {
			case TClass(info):
				info.extend != null ? info.extend.superClass : null;
			case _:
				null;
		}
	}
}
