package ax3.filters;

import ax3.ParseTree.Binop;
import ax3.ParseTree.AssignOp;
import ax3.ParseTree.PreUnop;
import ax3.ParseTree.PostUnop;
import ax3.TypedTree.TType;
import ax3.TypedTreeTools;

private typedef VarInfo = {
	var decl:TVarDecl;
	var hint:TType;
	var incompatible:Bool;
}

private typedef MapValueInfo = {
	var hint:TType;
	var incompatible:Bool;
}

class InferLocalVarTypes extends AbstractFilter {
	var fieldMapValueHints:Map<String, MapValueInfo> = null;
	var currentClass:Null<TClassOrInterfaceDecl> = null;

	static final fieldOverrides:Array<{owner:String, name:String, target:String}> = [
		// Some externs expose `responseHeaders` as Array<Dynamic>, but runtime values are URLRequestHeader items.
		{owner: "flash.events.HTTPStatusEvent", name: "responseHeaders", target: "Array<flash.net.URLRequestHeader>"},
		{owner: "openfl.events.HTTPStatusEvent", name: "responseHeaders", target: "Array<flash.net.URLRequestHeader>"},
		// SWC types currentLabels as Array, but runtime values are FrameLabel items.
		{owner: "flash.display.MovieClip", name: "currentLabels", target: "Array<flash.display.FrameLabel>"},
		{owner: "openfl.display.MovieClip", name: "currentLabels", target: "Array<openfl.display.FrameLabel>"}
	];

	function getFieldOverrideType(obj:TFieldObject, fieldName:String):Null<TType> {
		var cls = switch obj.type {
			case TTInst(c) | TTStatic(c): c;
			case _: null;
		};
		if (cls == null) return null;

		var fqn = classFqn(cls);
		for (rule in fieldOverrides) {
			if (rule.name != fieldName) continue;
			if (!ownerMatches(cls, fqn, rule.owner)) continue;
			return tree.getType(rule.target);
		}
		return null;
	}

	function classFqn(c:TClassOrInterfaceDecl):String {
		var pack = c.parentModule.parentPack.name;
		return pack == "" ? c.name : pack + "." + c.name;
	}

	function ownerMatches(cls:TClassOrInterfaceDecl, fqn:String, owner:String):Bool {
		if (owner == fqn) return true;
		if (owner.indexOf(".") == -1) return owner == cls.name;
		return false;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		fieldMapValueHints = new Map();
		collectFieldMapValueHints(c, fieldMapValueHints);
		currentClass = c;
		super.processClass(c);
		currentClass = null;
		fieldMapValueHints = null;
	}

	override function processFunction(fun:TFunction) {
		if (fun.expr == null) {
			return;
		}

		var infos = new Map<TVar, VarInfo>();
		var infoByName = new Map<String, VarInfo>();
		var mapValueHints = cloneMapValueHints(fieldMapValueHints);
		var mapIteratorHints = new Map<String, String>();
		var mapIteratorValueHints = new Map<String, TType>();
		var mapIteratorVarHints = new Map<TVar, String>();

		function inferredTypeForLocal(v:TVar):Null<TType> {
			var info = infos[v];
			if (info != null && !info.incompatible && info.hint != null && !typeEq(info.hint, TTAny)) {
				return info.hint;
			}
			if (!typeEq(v.type, TTAny)) {
				return v.type;
			}
			return null;
		}

		function syncLocalExprType(e:TExpr, v:TVar) {
			if (!typeEq(e.type, TTAny)) {
				return;
			}
			var inferred = inferredTypeForLocal(v);
			if (inferred != null) {
				e.type = inferred;
			}
		}

		function hintFromExprWithLocals(e:TExpr):Null<TType> {
			var hint = hintFromExpr(e, mapValueHints, mapIteratorHints);
			if (hint != null && !typeEq(hint, TTAny)) {
				return hint;
			}
			return switch e.kind {
				case TELocal(_, v):
					inferredTypeForLocal(v);
				case TEParens(_, inner, _):
					hintFromExprWithLocals(inner);
				case TECast(c):
					hintFromExprWithLocals(c.expr);
				case TEHaxeRetype(inner):
					hintFromExprWithLocals(inner);
				case _:
					hint;
			}
		}

		function addCandidate(decl:TVarDecl) {
			if (decl.v.type != TTAny) {
				return;
			}
			var hint:TType = null;
			if (decl.init != null) {
				hint = hintFromExprWithLocals(decl.init.expr);
				if (hint != null && typeEq(hint, TTAny)) {
					hint = null;
				}
			}
			var info = {decl: decl, hint: hint, incompatible: false};
			infos[decl.v] = info;
			infoByName[decl.v.name] = info;
		}

		function noteHint(info:VarInfo, hint:TType) {
			if (info.incompatible) return;

			if (info.hint == null) {
				info.hint = hint;
			} else {
				var merged = mergeTypes(info.hint, hint);
				if (merged == null) {
					info.incompatible = true;
				} else {
					info.hint = merged;
				}
			}
		}

		function noteAssignOp(info:VarInfo, op:AssignOp, rhs:TExpr) {
			if (info.incompatible) {
				return;
			}

			if (info.hint == null) {
				if (isNumericAssignOp(op)) {
					noteHint(info, TTNumber);
				} else {
					if (op.match(AOpAdd(_))) {
						var rhsHint = hintFromExprWithLocals(rhs);
						if (typeEq(rhsHint, TTString)) {
							noteHint(info, TTString);
						} else if (isNumericType(rhsHint)) {
							noteHint(info, TTNumber);
						} else {
							info.incompatible = true;
						}
					} else {
						info.incompatible = true;
					}
				}
				return;
			}

			// Check compatibility
			if (typeEq(info.hint, TTString)) {
				switch op {
					case AOpAdd(_):
					case _: info.incompatible = true;
				}
			} else if (isNumericType(info.hint)) {
				if (!isNumericAssignOp(op)) {
					info.incompatible = true;
					return;
				}
				var hint = hintFromExprWithLocals(rhs);
				if (hint == null) {
					// Keep current numeric hint when RHS is temporarily unresolved.
					return;
				}
				if (!isNumericType(hint)) {
					info.incompatible = true;
				} else {
					noteHint(info, hint);
				}
			} else {
				// Other types usually don't support assign ops
				info.incompatible = true;
			}
		}

		function extractLocalFromExpr(expr:TExpr):Null<TVar> {
			return switch expr.kind {
				case TELocal(_, v): v;
				case TEParens(_, e, _): extractLocalFromExpr(e);
				case TECast(c): extractLocalFromExpr(c.expr);
				case TEField(obj, _, _):
					switch obj.kind {
						case TOExplicit(_, e): extractLocalFromExpr(e);
						case _: null;
					}
				case _: null;
			}
		}

		function hintFromIteratorNext(expr:TExpr):Null<TType> {
			switch expr.kind {
				case TECall(eobj, _):
					switch eobj.kind {
						case TEField(obj, "next", _):
							var iteratorKey = mapKeyFromFieldObject(obj);
							if (iteratorKey != null) {
								var iterHint = mapIteratorValueHints[iteratorKey];
								if (iterHint != null) {
									return iterHint;
								}
								var iteratorVar = switch obj.kind {
									case TOExplicit(_, e): extractLocalFromExpr(e);
									case _: null;
								};
								if (iteratorVar != null) {
									var mapKey = mapIteratorVarHints[iteratorVar];
									if (mapKey != null) {
										var info = mapValueHints[mapKey];
										if (info != null && !info.incompatible) {
											return info.hint;
										}
									}
								}
								var mapKey = mapIteratorHints[iteratorKey];
								if (mapKey != null) {
									var info = mapValueHints[mapKey];
									if (info != null && !info.incompatible) {
										return info.hint;
									}
								}
							}
						case _:
					}
				case _:
			}
			return null;
		}

		function noteAssign(info:VarInfo, op:Binop, rhs:TExpr) {
			if (info.incompatible) {
				return;
			}

			switch op {
				case OpAssign(_):
					var hint = hintFromExprWithLocals(rhs);
					if (hint != null && typeEq(hint, TTAny)) {
						hint = null;
					}
					if (hint == null) {
						hint = hintFromIteratorNext(rhs);
					}
					if (hint == null) {
						info.incompatible = true;
					} else {
						noteHint(info, hint);
					}
				case OpAssignOp(aop):
					noteAssignOp(info, aop, rhs);
				case _:
			}
		}

		function noteUnary(info:VarInfo) {
			if (info.incompatible) return;

			if (info.hint == null) {
				noteHint(info, TTInt); // Assume Int for ++/--
			} else {
				if (!isNumericType(info.hint)) {
					info.incompatible = true;
				}
			}
		}

		function noteUsage(info:VarInfo, impliedHint:TType) {
			if (info.incompatible) return;

			if (info.hint == null) {
				info.hint = impliedHint;
			} else {
				var merged = mergeTypes(info.hint, impliedHint);
				if (merged == null) {
					info.incompatible = true;
				}
			}
		}

		function checkUsage(e:TExpr, implied:TType) {
			switch e.kind {
				case TELocal(_, v):
					var info = infos[v];
					if (info != null) {
						noteUsage(info, implied);
					}
				case _:
			}
		}

		function mapKeyFromIteratorExpr(expr:TExpr):Null<String> {
			return switch expr.kind {
				case TECast(c): mapKeyFromIteratorExpr(c.expr);
				case TECall(eobj, _):
					switch eobj.kind {
						case TEField(obj, "iterator", _):
							if (isAs3CommonsMap(obj.type)) {
								mapKeyFromFieldObject(obj);
							} else {
								null;
							}
						case _: null;
					}
				case _: null;
			}
		}

		function noteMapIteratorBinding(v:TVar, expr:TExpr) {
			var mapKey = mapKeyFromIteratorExpr(expr);
			if (mapKey != null) {
				var localKey = "local:" + v.name;
				var fieldKey = "field:" + v.name;
				mapIteratorHints[localKey] = mapKey;
				mapIteratorHints[fieldKey] = mapKey;
				mapIteratorVarHints[v] = mapKey;
				var mapInfo = mapValueHints[mapKey];
				if (mapInfo != null && !mapInfo.incompatible) {
					mapIteratorValueHints[localKey] = mapInfo.hint;
					mapIteratorValueHints[fieldKey] = mapInfo.hint;
				}
			}
		}

		function localVarFromFieldObject(obj:TFieldObject):Null<TVar> {
			return switch obj.kind {
				case TOExplicit(_, e): extractLocalFromExpr(e);
				case _: null;
			}
		}

		function infoFromFieldObject(obj:TFieldObject):Null<VarInfo> {
			var localVar = localVarFromFieldObject(obj);
			if (localVar != null) {
				return infos[localVar];
			}
			var mapKey = mapKeyFromFieldObject(obj);
			if (mapKey != null) {
				if (mapKey.length > 6 && mapKey.substr(0, 6) == "local:") {
					return infoByName[mapKey.substr(6)];
				}
				if (mapKey.length > 6 && mapKey.substr(0, 6) == "field:") {
					return infoByName[mapKey.substr(6)];
				}
			}
			return null;
		}

		function findFunctionTypeByName(name:String):Null<TType> {
			if (currentClass == null) return null;
			for (member in currentClass.members) {
				switch member {
					case TMField(field):
						switch field.kind {
							case TFFun(f):
								if (f.name == name) return f.type;
							case TFGetter(f):
								if (f.name == name) return f.fun.sig.ret.type;
							case TFSetter(f):
								if (f.name == name) return f.fun.sig.ret.type;
							case TFVar(_):
						}
					case _:
				}
			}
			return null;
		}

		function inferSortElementType(args:TCallArgs):Null<TType> {
			if (args.args.length == 0) return null;
			var firstArg = args.args[0].expr;
			switch firstArg.type {
				case TTFun(funArgs, _):
					if (funArgs.length >= 2 && funArgs[0] != null && typeEq(funArgs[0], funArgs[1])) {
						return funArgs[0];
					}
				case _:
			}
			switch firstArg.kind {
				case TEField(_, fieldName, _):
					var type = findFunctionTypeByName(fieldName);
					switch type {
						case TTFun(funArgs, _):
							if (funArgs.length >= 2 && funArgs[0] != null && typeEq(funArgs[0], funArgs[1])) {
								return funArgs[0];
							}
						case _:
					}
				case _:
			}
			return null;
		}

		function loop(e:TExpr) {
			switch e.kind {
				case TEVars(_, vars):
					for (decl in vars) {
						if (decl.init != null) {
							noteMapIteratorBinding(decl.v, decl.init.expr);
						}
						addCandidate(decl);
						if (decl.init != null) {
							loop(decl.init.expr);
						}
					}

				case TEBinop(a, op = OpAssign(_) | OpAssignOp(_), b):
					var isLocalAssign = false;
					switch a.kind {
						case TELocal(_, v):
							isLocalAssign = true;
							var info = infos[v];
							if (info != null) {
								noteAssign(info, op, b);
							}
							noteMapIteratorBinding(v, b);
						case _:
					}
					if (!isLocalAssign) loop(a);
					loop(b);

				case TEPreUnop(PreIncr(_) | PreDecr(_), {kind: TELocal(_, v)})
				   | TEPostUnop({kind: TELocal(_, v)}, PostIncr(_) | PostDecr(_)):
					var info = infos[v];
					if (info != null) {
						noteUnary(info);
					}

				case TEBinop(a, op, b):
					if (isBitwiseOp(op)) {
						checkUsage(a, TTInt);
						checkUsage(b, TTInt);
					}
					else if (isArithmeticOp(op)) {
						checkUsage(a, TTNumber);
						checkUsage(b, TTNumber);
					}
					loop(a);
					loop(b);

				case TEArrayAccess(a):
					// Index usage implies Int only for Array/Vector/XMLList/ByteArray.
					// For Object/Any, avoid forcing Int (keys are usually strings).
					switch a.eobj.type {
						case TTArray(_) | TTVector(_) | TTXMLList:
							checkUsage(a.eindex, TTInt);
						case TTInst({name: "ByteArray", parentModule: {parentPack: {name: "flash.utils"}}}):
							checkUsage(a.eindex, TTInt);
						case TTDictionary(keyType, _):
							if (!keyType.match(TTAny | TTObject(TTAny))) {
								checkUsage(a.eindex, keyType);
							}
						case _:
					}
					loop(a.eobj);
					loop(a.eindex);

				case TELocal(_, v):
					syncLocalExprType(e, v);
					var info = infos[v];
					if (info != null) {
						if (info.hint == null) {
							info.incompatible = true;
						}
					}

				case TEHaxeFor(f):
					loop(f.iter);
					if (typeEq(f.vit.type, TTAny)) {
						var iterHint = hintFromExprWithLocals(f.iter);
						var elemType = elementTypeFromIterableHint(iterHint);
						if (elemType != null && !typeEq(elemType, TTAny)) {
							f.vit.type = elemType;
						}
					}
					loop(f.body);

				case TEForEach(f):
					// First process the loop variable declaration (to add candidates)
					switch f.iter.eit.kind {
						case TEVars(_, vars):
							for (decl in vars) {
								if (decl.init != null) {
									noteMapIteratorBinding(decl.v, decl.init.expr);
								}
								addCandidate(decl);
								if (decl.init != null) {
									loop(decl.init.expr);
								}
							}
						case TELocal(_, _):
							// Skip marking shared loop vars as incompatible.
						case _:
							loop(f.iter.eit);
					}
					// Then process the iterable expression
					loop(f.iter.eobj);
					// Now infer loop variable type from array element type
					// Handle both "for each (var item in ...)" (TEVars) and "for each (item in ...)" (TELocal)
					var loopVar:Null<TVar> = switch f.iter.eit.kind {
						case TELocal(_, v): v;
						case TEVars(_, [varDecl]): varDecl.v;
						case _: null;
					}
					if (loopVar != null) {
						var info = infos[loopVar];
						if (info != null) {
							// Try to infer from the iterable expression
							var objHint = hintFromExprWithLocals(f.iter.eobj);
							var elemType = elementTypeFromIterableHint(objHint);
							if (elemType != null) {
								noteHint(info, elemType);
							}
						}
					}
					loop(f.body);

				case TECall(eobj, args):
					switch eobj.kind {
						case TEField(obj, "sort", _):
							var info = infoFromFieldObject(obj);
							if (info != null) {
								var elemType = inferSortElementType(args);
								if (elemType != null) {
									info.hint = TTVector(elemType);
									info.incompatible = false;
								}
							}
						case TEField(obj, "add", _):
							if (isAs3CommonsMap(obj.type)) {
								var mapKey = mapKeyFromFieldObject(obj);
								if (mapKey != null && args.args.length >= 2) {
									var valueHint = hintFromExprWithLocals(args.args[1].expr);
									noteMapValue(mapValueHints, mapKey, valueHint);
								}
							}
						case _:
					}
					loop(eobj);
					for (arg in args.args) {
						loop(arg.expr);
					}

				default:
					iterExpr(loop, e);
			}
		}

		loop(fun.expr);

		for (info in infos) {
			if (info.incompatible || info.hint == null) {
				continue;
			}
			// info.hint IS the TType now.
			var newType = info.hint;
			if (!typeEq(info.decl.v.type, newType)) {
				info.decl.v.type = newType;
				reportError(info.decl.syntax.name.pos, 'Inferred local var type "${info.decl.v.name}" as ${typeToString(newType)} (was ASAny)');
			}
		}
	}

	static function elementTypeFromIterableHint(hint:Null<TType>):Null<TType> {
		return switch hint {
			case TTArray(elemType):
				elemType;
			case TTVector(elemType):
				elemType;
			case TTDictionary(_, valueType):
				valueType;
			case TTObject(valueType):
				valueType;
			case TTXMLList:
				TTXML;
			case _:
				null;
		}
	}

	function hintFromExpr(e:TExpr, mapValueHints:Map<String, MapValueInfo>, mapIteratorHints:Map<String, String>):Null<TType> {
		// Check for field overrides first
		switch e.kind {
			case TEField(obj, name, _):
				var overrideType = getFieldOverrideType(obj, name);
				if (overrideType != null) return overrideType;
			case _:
		}

		// For array declarations, try to find common type even if elements have known types
		switch e.kind {
			case TEArrayDecl(arr):
				// Try to find a common type among all elements
				var commonType:TType = null;
				for (elem in arr.elements) {
					var elemType = hintFromExpr(elem.expr, mapValueHints, mapIteratorHints);
					if (elemType == null) {
						commonType = null;
						break;
					}
					if (commonType == null) {
						commonType = elemType;
					} else if (!typeEq(commonType, elemType)) {
						// Types don't match, fall back to untyped array
						commonType = null;
						break;
					}
				}
				if (commonType != null) {
					return TTArray(commonType);
				}
				return TypedTreeTools.tUntypedArray; // Array<Any>
			case _:
		}

		var mapHint = hintFromMapCall(e, mapValueHints, mapIteratorHints);
		if (mapHint != null) {
			return mapHint;
		}

		if (e.type != TTAny) {
			return e.type;
		}

		// Structural inference for untyped expressions
		switch e.kind {
			case TEBinop(a, op, b):
				if (isBitwiseOp(op)) return TTInt;
				if (isArithmeticOp(op)) return TTNumber;
				if (isComparisonOp(op)) return TTBoolean;
				if (isBoolOp(op)) return TTBoolean;

				if (op.match(OpAdd(_))) {
					var ha = hintFromExpr(a, mapValueHints, mapIteratorHints);
					var hb = hintFromExpr(b, mapValueHints, mapIteratorHints);
					// If any is String, result is String
					if ((ha != null && typeEq(ha, TTString)) || (hb != null && typeEq(hb, TTString))) return TTString;

					// Refined numeric logic:
					// If either is explicitly Number, result is Number
					if ((ha != null && ha.match(TTNumber)) || (hb != null && hb.match(TTNumber))) return TTNumber;
					// If either is Int (and other is not Number/String), result is Int (Int + Unknown -> Int)
					if (isNumericType(ha) || isNumericType(hb)) return TTInt;
				}

			case TECast(c):
				return hintFromExpr(c.expr, mapValueHints, mapIteratorHints);

			case TEPreUnop(op, _):
				if (op.match(PreBitNeg(_))) return TTInt;
				if (op.match(PreNeg(_))) return TTNumber;
				if (op.match(PreNot(_))) return TTBoolean;
				if (op.match(PreIncr(_) | PreDecr(_))) return TTNumber;

			case TEPostUnop(_, op):
				return TTNumber;

			case TEArrayDecl(_):
				return TypedTreeTools.tUntypedArray; // Array<Any>

			case TENew(_, cls, _):
				switch cls {
					case TNType(t): return t.type;
					case _:
				}

			case TECall(eobj, args):
				switch eobj.kind {
					case TEField(o, "round" | "floor" | "ceil", _):
						return TTInt;
					case TEField(o, "fround" | "acos" | "asin" | "atan" | "atan2" | "cos" | "exp" | "log" | "pow" | "random" | "sin" | "sqrt" | "tan", _):
						return TTNumber;
					case TEField(o, "abs" | "max" | "min", _):
						// Check args for these polymorphic functions
						var hasFloat = false;
						var hasInt = false;
						for (arg in args.args) {
							var h = hintFromExpr(arg.expr, mapValueHints, mapIteratorHints);
							if (h != null) {
								if (h.match(TTNumber)) hasFloat = true;
								else if (isNumericType(h)) hasInt = true;
							}
						}
						if (hasFloat) return TTNumber;
						if (hasInt) return TTInt;
						return null; // Unknown args
					case _:
				}

			case _:
		}

		return null;
	}

	function hintFromMapCall(e:TExpr, mapValueHints:Map<String, MapValueInfo>, mapIteratorHints:Map<String, String>):Null<TType> {
		switch e.kind {
			case TECall(eobj, _):
				switch eobj.kind {
					case TEField(obj, "itemFor", _):
						if (mapValueHints != null && isAs3CommonsMap(obj.type)) {
							var mapKey = mapKeyFromFieldObject(obj);
							if (mapKey != null) {
								var info = mapValueHints[mapKey];
								if (info != null && !info.incompatible) {
									return info.hint;
								}
							}
						}
					case TEField(obj, "next", _):
						if (mapIteratorHints != null && mapValueHints != null) {
							var iteratorKey = mapKeyFromFieldObject(obj);
							if (iteratorKey != null) {
								var mapKey = mapIteratorHints[iteratorKey];
								if (mapKey != null) {
									var info = mapValueHints[mapKey];
									if (info != null && !info.incompatible) {
										return info.hint;
									}
								}
							}
						}
					case _:
				}
			case _:
		}
		return null;
	}

	function collectFieldMapValueHints(c:TClassOrInterfaceDecl, mapValueHints:Map<String, MapValueInfo>) {
		function loopExpr(e:TExpr) {
			switch e.kind {
				case TECall(eobj, args):
					switch eobj.kind {
						case TEField(obj, "add", _):
							if (isAs3CommonsMap(obj.type)) {
								var mapKey = mapKeyFromFieldObject(obj);
								if (mapKey != null && args.args.length >= 2) {
									var valueHint = hintFromExpr(args.args[1].expr, null, null);
									noteMapValue(mapValueHints, mapKey, valueHint);
								}
							}
						case _:
					}
					loopExpr(eobj);
					for (arg in args.args) {
						loopExpr(arg.expr);
					}
				default:
					iterExpr(loopExpr, e);
			}
		}

		for (m in c.members) {
			switch m {
				case TMField(field):
					switch field.kind {
						case TFVar(v):
							if (v.init != null) {
								loopExpr(v.init.expr);
							}
						case TFFun(f):
							if (f.fun.expr != null) loopExpr(f.fun.expr);
						case TFGetter(f):
							if (f.fun.expr != null) loopExpr(f.fun.expr);
						case TFSetter(f):
							if (f.fun.expr != null) loopExpr(f.fun.expr);
					}
				case TMStaticInit(i):
					loopExpr(i.expr);
				case TMUseNamespace(_):
				case TMCondCompBegin(_):
				case TMCondCompEnd(_):
			}
		}
	}

	static function mapKeyFromFieldObject(obj:TFieldObject):Null<String> {
		return switch obj.kind {
			case TOExplicit(_, e): mapKeyFromExpr(e);
			case TOImplicitThis(_): null;
			case TOImplicitClass(_): null;
		}
	}

	static function mapKeyFromExpr(e:TExpr):Null<String> {
		return switch e.kind {
			case TELocal(_, v): "local:" + v.name;
			case TEField(obj, fieldName, _):
				switch obj.kind {
					case TOImplicitThis(_): "field:" + fieldName;
					case TOImplicitClass(_): "static:" + fieldName;
					case TOExplicit(_, inner):
						var innerKey = mapKeyFromExpr(inner);
						innerKey != null ? innerKey + "." + fieldName : null;
				}
			case _: null;
		}
	}

	static function isAs3CommonsMap(t:TType):Bool {
		return switch t {
			case TTInst({name: "Map", parentModule: {parentPack: {name: "org.as3commons.collections"}}}): true;
			case _: false;
		}
	}

	static function noteMapValue(mapValueHints:Map<String, MapValueInfo>, mapKey:String, hint:TType) {
		if (mapValueHints == null) return;
		if (hint == null || typeEq(hint, TTAny)) return;
		var info = mapValueHints[mapKey];
		if (info == null) {
			mapValueHints[mapKey] = {hint: hint, incompatible: false};
			return;
		}
		if (info.incompatible) return;
		var merged = mergeTypes(info.hint, hint);
		if (merged == null) {
			info.incompatible = true;
		} else {
			info.hint = merged;
		}
	}

	static function cloneMapValueHints(mapValueHints:Map<String, MapValueInfo>):Map<String, MapValueInfo> {
		var cloned = new Map<String, MapValueInfo>();
		if (mapValueHints == null) return cloned;
		for (key in mapValueHints.keys()) {
			var info = mapValueHints[key];
			cloned[key] = {hint: info.hint, incompatible: info.incompatible};
		}
		return cloned;
	}

	static function isNumericType(t:TType):Bool {
		if (t == null) return false;
		return switch t {
			case TTInt | TTUint | TTNumber: true;
			case _: false;
		}
	}

	static function mergeTypes(current:TType, next:TType):Null<TType> {
		if (typeEq(current, next)) return current;

		// Int/UInt upgrade to Number
		if (isNumericType(current) && isNumericType(next)) {
			// If either is Number, result is Number.
			// If both are Int/UInt, result is Int/UInt (prefer Int?).
			// Simplification: Always Number if mixed?
			if (current.match(TTNumber) || next.match(TTNumber)) return TTNumber;
			return TTInt; // Both are Int-like
		}

		// Unification for classes?
		// e.g. Sprite and Sprite -> Sprite (handled by typeEq)
		// Sprite and MovieClip -> Incompatible for now (requires class hierarchy)

		return null;
	}

	static function typeToString(t:TType):String {
		// Simple stringifier for logging
		return switch t {
			case TTInt: "Int";
			case TTNumber: "Number";
			case TTBoolean: "Bool";
			case TTString: "String";
			case TTArray(_): "Array";
			case TTInst(c): c.name;
			case _: Std.string(t);
		}
	}

	static function isNumericAssignOp(op:AssignOp):Bool {
		return switch op {
			case AOpAdd(_) | AOpSub(_) | AOpMul(_) | AOpDiv(_) | AOpMod(_)
			   | AOpBitAnd(_) | AOpBitOr(_) | AOpBitXor(_)
			   | AOpShl(_) | AOpShr(_) | AOpUshr(_):
				true;
			case AOpAnd(_) | AOpOr(_):
				false;
		}
	}

	static function isBitwiseOp(op:Binop):Bool {
		return switch op {
			case OpShl(_) | OpShr(_) | OpUshr(_) | OpBitAnd(_) | OpBitOr(_) | OpBitXor(_): true;
			case _: false;
		}
	}

	static function isArithmeticOp(op:Binop):Bool {
		return switch op {
			case OpSub(_) | OpMul(_) | OpDiv(_) | OpMod(_): true;
			// OpAdd is ambiguous
			case _: false;
		}
	}

	static function isComparisonOp(op:Binop):Bool {
		return switch op {
			case OpEquals(_) | OpNotEquals(_) | OpStrictEquals(_) | OpNotStrictEquals(_) | OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_): true;
			case _: false;
		}
	}

	static function isBoolOp(op:Binop):Bool {
		return switch op {
			case OpAnd(_) | OpOr(_): true;
			case _: false;
		}
	}
}
