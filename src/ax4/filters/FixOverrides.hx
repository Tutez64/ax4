package ax4.filters;

class FixOverrides extends AbstractFilter {
	static inline final proxyNs = "http://www.adobe.com/2006/actionscript/flash/proxy";

	override function processDecl(decl:TDecl) {
		switch decl.kind {
			case TDClassOrInterface(c):
				switch c.kind {
					case TClass(info):
						if (info.extend == null) return;
						var superClass = info.extend.superClass;
						var extendsArray = ParseTree.dotPathToString(info.extend.syntax.path) == "Array";
						var extendsProxy = superClass.parentModule.parentPack.name == "flash.utils" && superClass.name == "Proxy";

						for (member in c.members) {
							switch member {
								case TMField(field):
									processField(field, superClass, extendsArray, extendsProxy);
								case _:
							}
						}
					case _:
				}
			case _:
		}
	}

	function processField(field:TClassField, superClass:TClassOrInterfaceDecl, extendsArray:Bool, extendsProxy:Bool) {
		switch field.kind {
			case TFFun(f):
				var isStatic = Lambda.exists(field.modifiers, m -> m.match(FMStatic(_)));
				if (isStatic) {
					removeOverride(field);
					return;
				}
				var base = superClass.findFieldInHierarchy(f.name, isStatic);
				if (base != null) {
					switch base.field.kind {
						case TFFun(baseFun):
							ensureOverride(field);
							alignSignature(f.fun.sig, baseFun.fun.sig);
						case _:
					}
				}

				if (extendsArray && f.name == "push") {
					ensureOverride(field);
					ensureRestAny(f.fun.sig);
				}

				if (extendsProxy && isProxyMethod(f.name)) {
					ensureOverride(field);
					ensureProxyNamespace(field);
					applyProxySignature(f.fun.sig, f.name);
				}

			case TFGetter(a):
				var isStatic = Lambda.exists(field.modifiers, m -> m.match(FMStatic(_)));
				if (isStatic) {
					removeOverride(field);
					return;
				}
				var base = findAccessorInHierarchy(superClass, a.name, isStatic, true);
				if (base != null) {
					ensureOverride(field);
					alignSignature(a.fun.sig, base.fun.sig);
				}

			case TFSetter(a):
				var isStatic = Lambda.exists(field.modifiers, m -> m.match(FMStatic(_)));
				if (isStatic) {
					removeOverride(field);
					return;
				}
				var base = findAccessorInHierarchy(superClass, a.name, isStatic, false);
				if (base != null) {
					ensureOverride(field);
					alignSignature(a.fun.sig, base.fun.sig);
				}

			case _:
		}
	}

	function findAccessorInHierarchy(cls:TClassOrInterfaceDecl, name:String, isStatic:Bool, wantGetter:Bool):Null<TAccessorField> {
		function matches(field:TClassField):Null<TAccessorField> {
			var fieldIsStatic = Lambda.exists(field.modifiers, m -> m.match(FMStatic(_)));
			if (fieldIsStatic != isStatic) return null;
			return switch field.kind {
				case TFGetter(a) if (wantGetter && a.name == name):
					a;
				case TFSetter(a) if (!wantGetter && a.name == name):
					a;
				case _:
					null;
			}
		}

		function loop(c:TClassOrInterfaceDecl):Null<TAccessorField> {
			for (member in c.members) {
				switch member {
					case TMField(f):
						var found = matches(f);
						if (found != null) return found;
					case _:
				}
			}
			switch c.kind {
				case TInterface(info):
					if (info.extend != null) {
						for (h in info.extend.interfaces) {
							var found = loop(h.iface.decl);
							if (found != null) return found;
						}
					}
				case TClass(info):
					if (info.extend != null) {
						return loop(info.extend.superClass);
					}
			}
			return null;
		}
		return loop(cls);
	}

	function ensureOverride(field:TClassField) {
		for (m in field.modifiers) {
			if (m.match(FMOverride(_))) return;
		}
		field.modifiers.push(FMOverride(mkIdent("override", [], [whitespace])));
	}

	function removeOverride(field:TClassField) {
		field.modifiers = [for (m in field.modifiers) if (!m.match(FMOverride(_))) m];
	}

	function alignSignature(sig:TFunctionSignature, baseSig:TFunctionSignature) {
		if (sig.args.length != baseSig.args.length) {
			return;
		}

		for (i in 0...sig.args.length) {
			var arg = sig.args[i];
			var baseArg = baseSig.args[i];
			arg.type = baseArg.type;

			switch [arg.kind, baseArg.kind] {
				case [TArgNormal(hint, init), TArgNormal(_, baseInit)]:
					if (baseInit == null) {
						arg.kind = TArgNormal(hint, null);
					} else if (init == null) {
						arg.kind = TArgNormal(hint, cloneInit(baseInit));
					}

				case [TArgRest(dots, _, hint), TArgRest(_, baseKind, _)]:
					arg.kind = TArgRest(dots, baseKind, hint);

				case _:
			}
		}

		sig.ret.type = baseSig.ret.type;
	}

	function ensureRestAny(sig:TFunctionSignature) {
		if (sig.args.length == 0) return;
		var last = sig.args[sig.args.length - 1];
		switch last.kind {
			case TArgRest(dots, kind, hint):
				last.type = TTAny;
				last.kind = TArgRest(dots, kind, hint);
			case _:
		}
	}

	function applyProxySignature(sig:TFunctionSignature, name:String) {
		var argsAreDynamic = switch name {
			case "getProperty" | "setProperty" | "callProperty" | "deleteProperty" | "getDescendants" | "hasProperty" | "isAttribute":
				true;
			case _:
				false;
		}

		if (argsAreDynamic) {
			for (arg in sig.args) {
				switch arg.kind {
					case TArgNormal(_, init):
						arg.type = TTAny;
						arg.kind = TArgNormal(dynamicTypeHint(fromArgKind(arg.kind)), init);
					case TArgRest(dots, kind, _):
						arg.type = TTAny;
						arg.kind = TArgRest(dots, kind, dynamicTypeHint(fromArgKind(arg.kind)));
				}
			}
		}

		switch name {
			case "getProperty" | "callProperty" | "getDescendants" | "nextValue":
				sig.ret.type = TTAny;
				sig.ret.syntax = dynamicTypeHint(sig.ret.syntax);
			case _:
		}
	}

	function fromArgKind(kind:TFunctionArgKind):Null<TypeHint> {
		return switch kind {
			case TArgNormal(hint, _): hint;
			case TArgRest(_, _, hint): hint;
		}
	}

	function dynamicTypeHint(hint:Null<TypeHint>):TypeHint {
		var lead = hint != null ? ParseTree.getSyntaxTypeLeadingTrivia(hint.type) : [];
		var trail = hint != null ? ParseTree.getSyntaxTypeTrailingTrivia(hint.type) : [];
		return {
			colon: hint != null ? hint.colon.clone() : new Token(0, TkColon, ":", [], [whitespace]),
			type: TPath({first: mkIdent("Dynamic", lead, trail), rest: []})
		};
	}

	function ensureProxyNamespace(field:TClassField) {
		for (m in field.metadata) {
			switch m {
				case MetaHaxe(t, _):
					if (t.text == "@:ns") return;
				case _:
			}
		}

		var lead = removeFieldLeadingTrivia(field);
		field.metadata.push(MetaHaxe(
			mkIdent("@:ns", lead, []),
			{
				openParen: mkOpenParen(),
				args: {
					first: ELiteral(LString(mkString(proxyNs))),
					rest: []
				},
				closeParen: mkCloseParen([whitespace])
			}
		));
	}

	function cloneInit(init:TVarInit):TVarInit {
		return {equalsToken: init.equalsToken.clone(), expr: cloneExpr(init.expr)};
	}

	static function isProxyMethod(name:String):Bool {
		return switch name {
			case "getProperty" | "setProperty" | "callProperty" | "deleteProperty" | "getDescendants" | "hasProperty" | "isAttribute" | "nextName" | "nextNameIndex" | "nextValue":
				true;
			case _:
				false;
		}
	}
}
