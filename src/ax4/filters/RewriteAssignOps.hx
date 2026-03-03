package ax4.filters;

import ax4.ParseTree.Binop;

class RewriteAssignOps extends AbstractFilter {
	var tempId:Int = 0;

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			// hxcpp can emit duplicate temporary local names for compound assignments on nested dynamic field accesses.
			// Rewrite those to explicit assignment via a cached object target.
			case TEBinop(a = {kind: TEField(obj = {kind: TOExplicit(_, _)}, fieldName, fieldToken)}, OpAssignOp(aop), b)
				if (e.expectedType == TTVoid && shouldRewriteDynamicFieldAssign(a, obj)):
				rewriteDynamicFieldAssign(a, obj, fieldName, fieldToken, aop, b, e);

			// int/uint /= int/uint/Number
			case TEBinop(a = {type: TTInt | TTUint}, OpAssignOp(AOpDiv(t)), b):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "left side of `/=` must be safe to repeat");
				}

				var op:Binop = OpDiv(t.clone());

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var eValue = mk(TEBinop(leftSide, op, b.with(expectedType = TTNumber)), TTNumber, a.type);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			// int/uint %= Number
			// int/uint *= Number
			case TEBinop(a = {type: TTInt | TTUint}, OpAssignOp(aop = (AOpMod(_) | AOpMul(_))), b = {type: TTNumber}):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "left side of `%=` and `*=` must be safe to repeat");
				}

				var op:Binop = switch aop {
					case AOpMod(t): OpMod(t.clone());
					case AOpMul(t): OpMul(t.clone());
					case _: throw "assert";
				}

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var eValue = mk(TEBinop(leftSide, op, b.with(expectedType = TTNumber)), TTNumber, a.type);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			// ||=
			// &&=
			case TEBinop(a, OpAssignOp(aop = (AOpAnd(_) | AOpOr(_))), b):
				if (!canBeRepeated(a)) {
					throwError(exprPos(a), "left side of `||=` and `&&=` must be safe to repeat");
				}

				var op:Binop = switch aop {
					case AOpAnd(t): OpAnd(t.clone());
					case AOpOr(t): OpOr(t.clone());
					case _: throw "assert";
				}

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var eValue = mk(TEBinop(leftSide, op, b), a.type, a.expectedType);

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			// bitwise assign ops (|=, &=, ^=, <<=, >>=, >>>=)
			case TEBinop(a, OpAssignOp(aop = (AOpBitAnd(_) | AOpBitOr(_) | AOpBitXor(_) | AOpShl(_) | AOpShr(_) | AOpUshr(_))), b):
				if (!canBeRepeated(a)) {
					var rewritten = rewriteBitwiseAssignUnsafe(a, aop, b, e);
					if (rewritten != null) return rewritten;
					throwError(exprPos(a), "left side of bitwise assign ops must be safe to repeat");
				}

				var op:Binop = switch aop {
					case AOpBitAnd(t): OpBitAnd(t.clone());
					case AOpBitOr(t): OpBitOr(t.clone());
					case AOpBitXor(t): OpBitXor(t.clone());
					case AOpShl(t): OpShl(t.clone());
					case AOpShr(t): OpShr(t.clone());
					case AOpUshr(t): OpUshr(t.clone());
					case _: throw "assert";
				}

				var leftSide = cloneExpr(a);
				removeLeadingTrivia(leftSide);
				var leftValue = wrapToInt(leftSide);
				var rightValue = wrapToInt(b);

				var resultType = switch aop {
					case AOpUshr(_): TTUint;
					case _: TTInt;
				};

				var eValue = mk(TEBinop(leftValue, op, rightValue), resultType, a.type);
				if (a.type == TTUint && resultType == TTInt) {
					eValue = mk(TEHaxeRetype(eValue), TTUint, TTUint);
				}

				e.with(kind = TEBinop(
					a,
					OpAssign(new Token(0, TkEquals, "=", [], [whitespace])),
					eValue
				));

			case _:
				e;
		}
	}

	static inline function isAnyLike(t:TType):Bool {
		return t.match(TTAny | TTObject(_) | TTBuiltin);
	}

	static inline function shouldRewriteDynamicFieldAssign(lhs:TExpr, obj:TFieldObject):Bool {
		return isAnyLike(lhs.type) || isAnyLike(obj.type);
	}

	function rewriteDynamicFieldAssign(
		a:TExpr,
		obj:TFieldObject,
		fieldName:String,
		fieldToken:Token,
		aop:AssignOp,
		b:TExpr,
		original:TExpr
	):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);
		var indent = extractIndent(lead);

		var explicitObj = switch obj.kind {
			case TOExplicit(_, eobj): eobj;
			case _: throw "assert";
		};

		var tmpObjName = "__tmpAssignObj" + tempId++;
		var tmpObjVar:TVar = {name: tmpObjName, type: explicitObj.type};
		var declObj:TVarDecl = {
			syntax: {name: mkIdent(tmpObjName), type: null},
			v: tmpObjVar,
			init: {equalsToken: mkTokenWithSpaces(TkEquals, "="), expr: explicitObj},
			comma: null
		};

		var varTokenObj = mkIdent("var", lead, [whitespace]);
		var declObjExpr = mk(TEVars(VVar(varTokenObj), [declObj]), TTVoid, TTVoid);

		var tmpObjExpr = mk(TELocal(mkIdent(tmpObjName), tmpObjVar), tmpObjVar.type, tmpObjVar.type);
		var lhsObj:TFieldObject = {kind: TOExplicit(mkDot(), tmpObjExpr), type: tmpObjVar.type};
		var lhs = mk(TEField(lhsObj, fieldName, fieldToken.clone()), a.type, a.type);

		var lhsClone = cloneExpr(lhs);
		removeLeadingTrivia(lhsClone);
		var op = assignOpToBinop(aop);
		var rhsValue = mk(TEBinop(lhsClone, op, b), a.type, a.type);
		var assignExpr = mk(TEBinop(lhs, OpAssign(new Token(0, TkEquals, "=", [], [whitespace])), rhsValue), a.type, original.expectedType);

		var semiDecl = addTrailingNewline(mkSemicolon());
		var semiAssign = mkSemicolon();
		semiAssign.trailTrivia = trail;
		semiDecl.trailTrivia = semiDecl.trailTrivia.concat(cloneTrivia(indent));

		return mkMergedBlock([
			{expr: declObjExpr, semicolon: semiDecl},
			{expr: assignExpr, semicolon: semiAssign}
		]);
	}

	static function assignOpToBinop(aop:AssignOp):Binop {
		return switch aop {
			case AOpAdd(t): OpAdd(t.clone());
			case AOpSub(t): OpSub(t.clone());
			case AOpMul(t): OpMul(t.clone());
			case AOpDiv(t): OpDiv(t.clone());
			case AOpMod(t): OpMod(t.clone());
			case AOpAnd(t): OpAnd(t.clone());
			case AOpOr(t): OpOr(t.clone());
			case AOpBitAnd(t): OpBitAnd(t.clone());
			case AOpBitOr(t): OpBitOr(t.clone());
			case AOpBitXor(t): OpBitXor(t.clone());
			case AOpShl(t): OpShl(t.clone());
			case AOpShr(t): OpShr(t.clone());
			case AOpUshr(t): OpUshr(t.clone());
		};
	}

	function rewriteBitwiseAssignUnsafe(a:TExpr, aop:AssignOp, b:TExpr, original:TExpr):Null<TExpr> {
		if (original.expectedType != TTVoid) {
			return null;
		}
		return switch a.kind {
			case TEArrayAccess(access):
				rewriteArrayAccessBitwiseAssign(access, a, aop, b, original);
			case _:
				null;
		}
	}

	function rewriteArrayAccessBitwiseAssign(access:TArrayAccess, a:TExpr, aop:AssignOp, b:TExpr, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);

		var indent = extractIndent(lead);
		var tmpObjName = "__tmpAssignObj" + tempId++;
		var tmpIdxName = "__tmpAssignIdx" + tempId++;
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
		}), a.type, a.type);

		var rhsLeft = wrapToInt(cloneExpr(lhs));
		var rhsRight = wrapToInt(b);

		var op:Binop = switch aop {
			case AOpBitAnd(t): OpBitAnd(t.clone());
			case AOpBitOr(t): OpBitOr(t.clone());
			case AOpBitXor(t): OpBitXor(t.clone());
			case AOpShl(t): OpShl(t.clone());
			case AOpShr(t): OpShr(t.clone());
			case AOpUshr(t): OpUshr(t.clone());
			case _: throw "assert";
		}

		var resultType = switch aop {
			case AOpUshr(_): TTUint;
			case _: TTInt;
		};

		var rhsValue = mk(TEBinop(rhsLeft, op, rhsRight), resultType, a.type);
		if (a.type == TTUint && resultType == TTInt) {
			rhsValue = mk(TEHaxeRetype(rhsValue), TTUint, TTUint);
		}

		var assignExpr = mk(TEBinop(lhs, OpAssign(new Token(0, TkEquals, "=", [], [whitespace])), rhsValue), a.type, original.expectedType);

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

	static function wrapToInt(e:TExpr):TExpr {
		return switch e.type {
			case TTInt | TTUint:
				e;
			case _:
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var toInt = mkBuiltin("ASCompat.toInt", TTFun([TTAny], TTInt), lead);
				mkCall(toInt, [e.with(expectedType = e.type)], TTInt, trail);
		}
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
