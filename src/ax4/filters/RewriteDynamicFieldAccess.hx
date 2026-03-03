package ax4.filters;

class RewriteDynamicFieldAccess extends AbstractFilter {
	static final tSetProperty = TTFun([TTAny, TTString, TTAny], TTAny);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEBinop(lhs = {kind: TEField(obj, fieldName, fieldToken)}, OpAssign(_), rhs)
				if (shouldRewriteDynamicFieldAssign(obj)):
				rewriteFieldAssign(e, lhs, obj, fieldName, fieldToken, rhs);

			case TEField(obj, fieldName, fieldToken):
				var updatedObj = rewriteFieldObject(obj, fieldName, fieldToken);
				if (updatedObj == obj) e else e.with(kind = TEField(updatedObj, fieldName, fieldToken));
			case _:
				e;
		}
	}

	static inline function shouldRewriteDynamicFieldAssign(obj:TFieldObject):Bool {
		return switch obj.type {
			case TTAny | TTObject(_) | TTBuiltin:
				true;
			case _:
				false;
		}
	}

	function rewriteFieldAssign(original:TExpr, lhs:TExpr, obj:TFieldObject, fieldName:String, fieldToken:Token, rhs:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		var eSetField = mkBuiltin("ASCompat.setProperty", tSetProperty, lead);
		var objectExpr:TExpr;
		var extraLead:Array<Trivia> = [];

		switch obj.kind {
			case TOExplicit(dot, eobj):
				objectExpr = stripAnyRetype(eobj);
				extraLead = dot.leadTrivia.concat(dot.trailTrivia);

			case TOImplicitThis(_):
				objectExpr = mk(TELiteral(TLThis(mkIdent("this", fieldToken.leadTrivia, []))), obj.type, obj.type);
				fieldToken.leadTrivia = [];

			case TOImplicitClass(cls):
				objectExpr = mkDeclRef({first: mkIdent(cls.name, fieldToken.leadTrivia, []), rest: []}, {name: cls.name, kind: TDClassOrInterface(cls)}, null);
				fieldToken.leadTrivia = [];
		}

		var nameToken = new Token(
			fieldToken.pos,
			TkStringDouble,
			haxe.Json.stringify(fieldName),
			extraLead.concat(fieldToken.leadTrivia),
			stripWhitespaceTrivia(fieldToken.trailTrivia)
		);
		fieldToken.leadTrivia = [];
		fieldToken.trailTrivia = [];
		var eName = mk(TELiteral(TLString(nameToken)), TTString, TTString);

		return mk(TECall(eSetField, {
			openParen: mkOpenParen(),
			args: [{expr: objectExpr, comma: commaWithSpace}, {expr: eName, comma: commaWithSpace}, {expr: rhs, comma: null}],
			closeParen: mkCloseParen(trail)
		}), lhs.type, original.expectedType);
	}

	static function stripAnyRetype(e:TExpr):TExpr {
		return switch e.kind {
			case TEHaxeRetype(inner) if (e.type == TTAny):
				stripAnyRetype(inner);
			case TEParens(_, inner = {kind: TEHaxeRetype(_), type: TTAny}, _):
				stripAnyRetype(inner);
			case _:
				e;
		}
	}

	static function stripWhitespaceTrivia(trivia:Array<Trivia>):Array<Trivia> {
		var result:Array<Trivia> = [];
		for (item in trivia) {
			switch item.kind {
				case TrWhitespace | TrNewline:
				case _:
					result.push(item);
			}
		}
		return result;
	}

	function rewriteFieldObject(obj:TFieldObject, fieldName:String, fieldToken:Token):TFieldObject {
		return switch obj.kind {
			case TOExplicit(dot, eobj):
				var updatedExpr = processExpr(eobj);
				var inferred = inferExprType(updatedExpr);
				var objType = inferred != null ? inferred : (updatedExpr.type != TTAny ? updatedExpr.type : obj.type);
				if (needsDynamicFieldAccess(objType, fieldName)) {
					updatedExpr = retypeToAny(updatedExpr);
					obj.with(kind = TOExplicit(dot, updatedExpr), type = TTAny);
				} else if (updatedExpr == eobj) {
					obj;
				} else {
					obj.with(kind = TOExplicit(dot, updatedExpr));
				}

			case TOImplicitThis(cls):
				if (!needsDynamicFieldAccess(TTInst(cls), fieldName)) {
					obj;
				} else {
					var eThis = mk(TELiteral(TLThis(mkIdent("this", fieldToken.leadTrivia, []))), obj.type, obj.type);
					fieldToken.leadTrivia = [];
					{kind: TOExplicit(mkDot(), retypeToAny(eThis)), type: TTAny};
				}

			case TOImplicitClass(_):
				obj;
		}
	}

	function retypeToAny(e:TExpr):TExpr {
		return switch e.kind {
			case TEHaxeRetype(_):
				if (e.type == TTAny) e else e.with(kind = TEHaxeRetype(e), type = TTAny);
			case _:
				e.with(kind = TEHaxeRetype(e), type = TTAny);
		}
	}

	function inferExprType(e:TExpr):Null<TType> {
		return switch e.kind {
			case TEField(obj, name, _):
				var baseType = obj.type;
				if (baseType == TTAny) {
					baseType = switch obj.kind {
						case TOExplicit(_, inner): inferExprType(inner);
						case TOImplicitThis(cls): TTInst(cls);
						case TOImplicitClass(cls): TTStatic(cls);
					};
				}
				var fieldType = if (baseType == null) {
					null;
				} else {
					switch baseType {
						case TTInst(cls): getFieldType(cls, name, false);
						case TTStatic(cls): getFieldType(cls, name, true);
						case _: null;
					}
				};
				if (fieldType != null) fieldType else (e.type != TTAny ? e.type : null);
			case TELocal(_, v):
				v.type;
			case TEHaxeRetype(inner):
				e.type != TTAny ? e.type : inferExprType(inner);
			case _:
				e.type != TTAny ? e.type : null;
		}
	}

	function getFieldType(cls:TClassOrInterfaceDecl, name:String, isStatic:Bool):Null<TType> {
		var found = cls.findFieldInHierarchy(name, isStatic);
		if (found == null) {
			return null;
		}
		return switch found.field.kind {
			case TFVar(v): v.type;
			case TFFun(f): f.type;
			case TFGetter(f): f.propertyType;
			case TFSetter(f): f.propertyType;
		}
	}

	function needsDynamicFieldAccess(t:TType, fieldName:String):Bool {
		if (fieldName == "constructor") return true;
		return switch t {
			case TTInst(cls):
				if (!isAs3DynamicClass(cls)) false else cls.findFieldInHierarchy(fieldName, false) == null;
			case TTStatic(cls):
				if (!isAs3DynamicClass(cls)) false else cls.findFieldInHierarchy(fieldName, true) == null;
			case _:
				false;
		}
	}

	function fieldExistsOnType(t:TType, fieldName:String):Bool {
		return switch t {
			case TTInst(cls):
				cls.findFieldInHierarchy(fieldName, false) != null;
			case TTStatic(cls):
				cls.findFieldInHierarchy(fieldName, true) != null;
			case _:
				false;
		}
	}

	static function isAs3DynamicClass(cls:TClassOrInterfaceDecl):Bool {
		if (isDynamicClass(cls)) return true;
		return extendsFlashMovieClip(cls);
	}

	static function isDynamicClass(cls:TClassOrInterfaceDecl):Bool {
		for (m in cls.modifiers) {
			switch m {
				case DMDynamic(_):
					return true;
				case _:
			}
		}
		return false;
	}

	static function extendsFlashMovieClip(cls:TClassOrInterfaceDecl):Bool {
		if (cls.name == "MovieClip" && cls.parentModule.parentPack.name == "flash.display") {
			return true;
		}
		return switch cls.kind {
			case TClass(info):
				if (info.extend == null) {
					false;
				} else {
					var parent = info.extend.superClass;
					if (parent.name == "MovieClip" && parent.parentModule.parentPack.name == "flash.display") {
						true;
					} else {
						extendsFlashMovieClip(parent);
					}
				}
			case _:
				false;
		}
	}
}
