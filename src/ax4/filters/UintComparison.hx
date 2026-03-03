package ax4.filters;

// Haxe forbids comparison between int and uint with `Comparison of Int and UInt might lead to unexpected results`
// so we cast int to uint where needed
// TODO: report a warning here so we can fix types in AS3?
class UintComparison extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBinop(a, op = OpEquals(_) | OpNotEquals(_) | OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_), b):
				var aType = inferExprType(a);
				var bType = inferExprType(b);
				if (aType == null) aType = a.type;
				if (bType == null) bType = b.type;
				switch [aType, bType] {
					case [TTInt, TTUint] if (!a.kind.match(TELiteral(_))):
						a = processExpr(a);
						b = processExpr(b);
						e.with(kind = TEBinop(a.with(kind = TEHaxeRetype(a), type = TTUint), op, b));

					case [TTUint, TTInt] if (!b.kind.match(TELiteral(_))):
						a = processExpr(a);
						b = processExpr(b);
						e.with(kind = TEBinop(a, op, b.with(kind = TEHaxeRetype(b), type = TTUint)));

					case [TTAny, TTUint] if (!a.kind.match(TELiteral(_))):
						a = processExpr(a);
						b = processExpr(b);
						e.with(kind = TEBinop(a.with(kind = TEHaxeRetype(a), type = TTUint), op, b));

					case [TTUint, TTAny] if (!b.kind.match(TELiteral(_))):
						a = processExpr(a);
						b = processExpr(b);
						e.with(kind = TEBinop(a, op, b.with(kind = TEHaxeRetype(b), type = TTUint)));

					case _:
						mapExpr(processExpr, e);
				}
			case _:
				mapExpr(processExpr, e);
		}
	}

	function inferExprType(e:TExpr):Null<TType> {
		if (e.type != TTAny) {
			return e.type;
		}
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
				fieldType;
			case TELocal(_, v):
				v.type;
			case TEHaxeRetype(inner):
				e.type != TTAny ? e.type : inferExprType(inner);
			case _:
				null;
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

}
