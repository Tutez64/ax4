package ax3.filters;

class CoerceToNumber extends AbstractFilter {
	static final tToInt = TTFun([TTAny], TTInt);
	static final tToNumber = TTFun([TTAny], TTNumber);
	static final tToNumberField = TTFun([TTAny, TTString], TTNumber);
	static final tStdInt = TTFun([TTNumber], TTInt);
	var tempId:Int = 0;

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBinop(a, op = OpBitAnd(_) | OpBitOr(_) | OpBitXor(_) | OpShl(_) | OpShr(_) | OpUshr(_), b):
				var a2 = processExpr(a);
				var b2 = processExpr(b);
				a2 = coerceBitwiseOperand(a2);
				b2 = coerceBitwiseOperand(b2);
				applyExpectedCoercion(e.with(kind = TEBinop(a2, op, b2)));

			case TEBinop(a, op = OpGt(_) | OpGte(_) | OpLt(_) | OpLte(_), b):
				var a2 = processExpr(a);
				var b2 = processExpr(b);
				if (a2.type == TTBoolean && isNumeric(b2.type)) {
					a2 = mkToNumberCall(a2);
				}
				if (b2.type == TTBoolean && isNumeric(a2.type)) {
					b2 = mkToNumberCall(b2);
				}
				if (isAnyLike(a2.type) && isNumeric(b2.type)) {
					a2 = mkToNumberCall(a2);
				}
				if (isAnyLike(b2.type) && isNumeric(a2.type)) {
					b2 = mkToNumberCall(b2);
				}
				applyExpectedCoercion(e.with(kind = TEBinop(a2, op, b2)));

			case TEBinop(a, op = OpEquals(_) | OpNotEquals(_), b):
				var a2 = processExpr(a);
				var b2 = processExpr(b);
				if (a2.type == TTBoolean && isNumeric(b2.type)) {
					a2 = coerceBoolForEquality(a2, b2.type);
				}
				if (b2.type == TTBoolean && isNumeric(a2.type)) {
					b2 = coerceBoolForEquality(b2, a2.type);
				}
				if (isAnyLike(a2.type) && isNumeric(b2.type)) {
					a2 = coerceAnyForEquality(a2, b2.type);
				}
				if (isAnyLike(b2.type) && isNumeric(a2.type)) {
					b2 = coerceAnyForEquality(b2, a2.type);
				}
				applyExpectedCoercion(e.with(kind = TEBinop(a2, op, b2)));

			case TEPreUnop(op = PreIncr(_) | PreDecr(_), inner):
				var mappedInner = mapExpr(processExpr, inner);
				if (e.expectedType == TTVoid && isAnyLike(mappedInner.type) && mappedInner.kind.match(TELocal(_))) {
					return rewriteAnyIncDec(mappedInner, op.match(PreIncr(_)));
				} else if (e.expectedType == TTVoid && !canBeRepeated(mappedInner)) {
					var rewritten = rewriteIncDecUnsafe(mappedInner, op.match(PreIncr(_)), e);
					if (rewritten != null) return rewritten;
				} else {
					return applyExpectedCoercion(e.with(kind = TEPreUnop(getPreUnopToken(e), mappedInner)));
				}
				return applyExpectedCoercion(e.with(kind = TEPreUnop(getPreUnopToken(e), mappedInner)));
			case TEPostUnop(inner, op = PostIncr(_) | PostDecr(_)):
				var mappedInner = mapExpr(processExpr, inner);
				if (e.expectedType == TTVoid && isAnyLike(mappedInner.type) && mappedInner.kind.match(TELocal(_))) {
					return rewriteAnyIncDec(mappedInner, op.match(PostIncr(_)));
				} else if (e.expectedType == TTVoid && !canBeRepeated(mappedInner)) {
					var rewritten = rewriteIncDecUnsafe(mappedInner, op.match(PostIncr(_)), e);
					if (rewritten != null) return rewritten;
				} else {
					return applyExpectedCoercion(e.with(kind = TEPostUnop(mappedInner, getPostUnopToken(e))));
				}
				return applyExpectedCoercion(e.with(kind = TEPostUnop(mappedInner, getPostUnopToken(e))));

			// Handle assignment to Int/Uint local variables - force coercion to match the target type
			case TEBinop(a, op = OpAssign(_), b):
				var b2 = processExpr(b);
				// Check if we're assigning to a local variable with Int/Uint type
				switch a.kind {
					case TELocal(_, v) if (v.type.match(TTInt | TTUint)):
						// Force coercion of the RHS to match the variable's type
						b2 = if (v.type == TTInt) coerceToInt(b2) else coerceToUInt(b2);
					case _:
				}
				var a2 = processExpr(a);
				applyExpectedCoercion(e.with(kind = TEBinop(a2, op, b2)));

			case _:
				applyExpectedCoercion(mapExpr(processExpr, e));
		}
	}

	static function getPreUnopToken(e:TExpr):PreUnop {
		return switch e.kind {
			case TEPreUnop(op, _): op;
			case _: throw "assert";
		}
	}

	static function getPostUnopToken(e:TExpr):PostUnop {
		return switch e.kind {
			case TEPostUnop(_, op): op;
			case _: throw "assert";
		}
	}

	function applyExpectedCoercion(e:TExpr):TExpr {
		return switch e.expectedType {
			case TTInt:
				coerceToInt(e);
			case TTUint:
				coerceToUInt(e);
			case TTNumber:
				coerceToFloat(e);
			case _:
				e;
		}
	}

	function coerceToInt(e:TExpr):TExpr {
		return switch e.type {
			case TTInt:
				e;
			case TTUint:
				mk(TEHaxeRetype(e), TTInt, TTInt);
			case TTNumber:
				mkStdIntCall(e);
			case _:
				mkToIntCall(e);
		}
	}

	function coerceToUInt(e:TExpr):TExpr {
		return switch e.type {
			case TTUint:
				e;
			case TTInt:
				retypeToUInt(e);
			case TTNumber:
				retypeToUInt(mkStdIntCall(e));
			case _:
				retypeToUInt(mkToIntCall(e));
		}
	}

	function coerceToFloat(e:TExpr):TExpr {
		return switch e.type {
			case TTNumber:
				e;
			case TTInt | TTUint:
				e;
			case _:
				mkToNumberCall(e);
		}
	}

	static function mkStdIntCall(e:TExpr):TExpr {
		var stdInt = mkBuiltin("Std.int", tStdInt, removeLeadingTrivia(e));
		return mkCall(stdInt, [e.with(expectedType = TTNumber)], TTInt, removeTrailingTrivia(e));
	}

	static function mkToIntCall(e:TExpr):TExpr {
		var eToInt = mkBuiltin("ASCompat.toInt", tToInt, removeLeadingTrivia(e));
		return mkCall(eToInt, [e.with(expectedType = e.type)], TTInt, removeTrailingTrivia(e));
	}

	static function mkToNumberCall(e:TExpr):TExpr {
		// Check if this is a field access on a Dynamic/Any object
		// In such cases, we need to use toNumberField to handle undefined correctly
		switch e.kind {
			case TEField(fieldObj, fieldName, _):
				switch fieldObj.kind {
					case TOExplicit(dot, eobj):
						// For field access on Dynamic objects, use toNumberField
						// to properly handle undefined values (which Haxe converts to null)
						var objExpr = eobj.with(expectedType = eobj.type);
						var fieldNameExpr = mk(TELiteral(TLString(new Token(0, TkStringDouble, '"' + fieldName + '"', [], []))), TTString, TTString);
						var eToNumberField = mkBuiltin("ASCompat.toNumberField", tToNumberField, removeLeadingTrivia(e));
						return mkCall(eToNumberField, [objExpr, fieldNameExpr], TTNumber, removeTrailingTrivia(e));
					case _:
						// Fall through to default
				}
			case _:
				// Fall through to default
		}
		var eToNumber = mkBuiltin("ASCompat.toNumber", tToNumber, removeLeadingTrivia(e));
		return mkCall(eToNumber, [e.with(expectedType = e.type)], TTNumber, removeTrailingTrivia(e));
	}

	static function rewriteAnyIncDec(target:TExpr, isInc:Bool):TExpr {
		var targetForValue = cloneExpr(target);
		removeLeadingTrivia(targetForValue);
		removeTrailingTrivia(targetForValue);

		var opToken = if (isInc) mkTokenWithSpaces(TkPlus, "+") else mkTokenWithSpaces(TkMinus, "-");
		var op = if (isInc) OpAdd(opToken) else OpSub(opToken);
		var oneExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "1", [], []))), TTInt, TTInt);

		var value = mk(TEBinop(mkToIntCall(targetForValue), op, oneExpr), TTInt, TTInt);
		return mk(TEBinop(target, OpAssign(mkTokenWithSpaces(TkEquals, "=")), value), TTVoid, TTVoid);
	}

	static function retypeToUInt(e:TExpr):TExpr {
		return mk(TEHaxeRetype(e), TTUint, TTUint);
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(TTAny));
	}

	static inline function isNumeric(t:TType):Bool {
		return t.match(TTInt | TTUint | TTNumber);
	}

	static function coerceBitwiseOperand(e:TExpr):TExpr {
		switch e.kind {
			case TELocal(_, v) if (isAnyLike(v.type)):
				return mkToIntCall(e);
			case _:
		}
		return switch e.type {
			case TTInt | TTUint:
				e;
			case _:
				mkToIntCall(e);
		}
	}

	static function coerceBoolForEquality(e:TExpr, otherType:TType):TExpr {
		return switch otherType {
			case TTInt | TTUint:
				mkToIntCall(e);
			case _:
				mkToNumberCall(e);
		}
	}

	static function coerceAnyForEquality(e:TExpr, otherType:TType):TExpr {
		return switch otherType {
			case TTInt | TTUint:
				mkToIntCall(e);
			case _:
				mkToNumberCall(e);
		}
	}

	function rewriteIncDecUnsafe(target:TExpr, isInc:Bool, original:TExpr):Null<TExpr> {
		if (original.expectedType != TTVoid) {
			return null;
		}
		return switch target.kind {
			case TEArrayAccess(access):
				rewriteArrayAccessIncDec(access, target, isInc, original);
			case TEField(obj, fieldName, fieldToken):
				switch obj.kind {
					case TOExplicit(dot, eobj):
						if (canBeRepeated(eobj)) null else rewriteFieldIncDec(eobj, dot, fieldName, fieldToken, target.type, isInc, original);
					case _:
						null;
				}
			case _:
				null;
		}
	}

	function rewriteFieldIncDec(eobj:TExpr, dot:Token, fieldName:String, fieldToken:Token, fieldType:TType, isInc:Bool, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);

		var indent = extractIndent(lead);
		var tmpObjName = "__tmpIncObj" + tempId++;
		var tmpObjVar:TVar = {name: tmpObjName, type: eobj.type};
		var declObj:TVarDecl = {
			syntax: {name: mkIdent(tmpObjName), type: null},
			v: tmpObjVar,
			init: {equalsToken: mkTokenWithSpaces(TkEquals, "="), expr: eobj},
			comma: null
		};

		var varTokenObj = mkIdent("var", lead, [whitespace]);
		var declObjExpr = mk(TEVars(VVar(varTokenObj), [declObj]), TTVoid, TTVoid);

		var tmpLocal = mk(TELocal(mkIdent(tmpObjName), tmpObjVar), tmpObjVar.type, tmpObjVar.type);
		var newObj:TFieldObject = {type: tmpObjVar.type, kind: TOExplicit(dot, tmpLocal)};
		var lhs = mk(TEField(newObj, fieldName, fieldToken), fieldType, fieldType);

		var rhsLeft = cloneExpr(lhs);
		removeLeadingTrivia(rhsLeft);
		removeTrailingTrivia(rhsLeft);
		var opToken = if (isInc) mkTokenWithSpaces(TkPlus, "+") else mkTokenWithSpaces(TkMinus, "-");
		var op = if (isInc) OpAdd(opToken) else OpSub(opToken);
		var oneExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "1", [], []))), TTInt, TTInt);
		var rhsValue = mk(TEBinop(rhsLeft, op, oneExpr), fieldType, fieldType);
		if (fieldType == TTUint) {
			rhsValue = mk(TEHaxeRetype(rhsValue), TTUint, TTUint);
		}
		var assignExpr = mk(TEBinop(lhs, OpAssign(new Token(0, TkEquals, "=", [], [whitespace])), rhsValue), fieldType, original.expectedType);

		var semiDecl = addTrailingNewline(mkSemicolon());
		var semiAssign = mkSemicolon();
		semiAssign.trailTrivia = trail;

		return mkMergedBlock([
			{expr: declObjExpr, semicolon: semiDecl},
			{expr: assignExpr, semicolon: semiAssign}
		]);
	}

	function rewriteArrayAccessIncDec(access:TArrayAccess, target:TExpr, isInc:Bool, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);

		var indent = extractIndent(lead);
		var tmpObjName = "__tmpIncObj" + tempId++;
		var tmpIdxName = "__tmpIncIdx" + tempId++;
		var tmpObjVar:TVar = {name: tmpObjName, type: access.eobj.type};
		var tmpIdxVar:TVar = {name: tmpIdxName, type: access.eindex.type};

		var declObj:TVarDecl = {
			syntax: {name: mkIdent(tmpObjName), type: null},
			v: tmpObjVar,
			init: {equalsToken: mkTokenWithSpaces(TkEquals, "="), expr: access.eobj},
			comma: null
		};
		var declIdx:TVarDecl = {
			syntax: {name: mkIdent(tmpIdxName), type: null},
			v: tmpIdxVar,
			init: {equalsToken: mkTokenWithSpaces(TkEquals, "="), expr: access.eindex},
			comma: null
		};

		var varTokenObj = mkIdent("var", lead, [whitespace]);
		var varTokenIdx = mkIdent("var", cloneTrivia(indent), [whitespace]);
		var declObjExpr = mk(TEVars(VVar(varTokenObj), [declObj]), TTVoid, TTVoid);
		var declIdxExpr = mk(TEVars(VVar(varTokenIdx), [declIdx]), TTVoid, TTVoid);

		var lhs = mk(TEArrayAccess({
			syntax: access.syntax,
			eobj: mk(TELocal(mkIdent(tmpObjName), tmpObjVar), tmpObjVar.type, tmpObjVar.type),
			eindex: mk(TELocal(mkIdent(tmpIdxName), tmpIdxVar), tmpIdxVar.type, tmpIdxVar.type)
		}), target.type, target.type);

		var rhsLeft = cloneExpr(lhs);
		removeLeadingTrivia(rhsLeft);
		removeTrailingTrivia(rhsLeft);
		var opToken = if (isInc) mkTokenWithSpaces(TkPlus, "+") else mkTokenWithSpaces(TkMinus, "-");
		var op = if (isInc) OpAdd(opToken) else OpSub(opToken);
		var oneExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "1", [], []))), TTInt, TTInt);
		var rhsValue = mk(TEBinop(rhsLeft, op, oneExpr), target.type, target.type);
		if (target.type == TTUint) {
			rhsValue = mk(TEHaxeRetype(rhsValue), TTUint, TTUint);
		}
		var assignExpr = mk(TEBinop(lhs, OpAssign(new Token(0, TkEquals, "=", [], [whitespace])), rhsValue), target.type, original.expectedType);

		var semiDecl = addTrailingNewline(mkSemicolon());
		var semiDecl2 = addTrailingNewline(mkSemicolon());
		var semiAssign = mkSemicolon();
		semiAssign.trailTrivia = trail;

		return mkMergedBlock([
			{expr: declObjExpr, semicolon: semiDecl},
			{expr: declIdxExpr, semicolon: semiDecl2},
			{expr: assignExpr, semicolon: semiAssign}
		]);
	}

	static function extractIndent(trivia:Array<Trivia>):Array<Trivia> {
		var result:Array<Trivia> = [];
		for (item in trivia) {
			switch item.kind {
				case TrWhitespace:
					result.push(item);
				case TrNewline:
					result = [];
				case _:
			}
		}
		return result;
	}

	static function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}
}
