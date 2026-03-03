package ax4.filters;

import ax4.ParseTree.VarDeclKind;
import ax4.ParseTree.SyntaxType;
import ax4.Token;
import ax4.TypedTree.TType;
import ax4.TypedTreeTools.typeEq;
import haxe.ds.List;

class RewriteForIn extends AbstractFilter {
	static final tIteratorMethod = TTFun([], TTBuiltin);
	static inline final tempLoopVarName = "_tmp_";
	public static inline final checkNullIterateeBuiltin = "checkNullIteratee";

	final generateCheckNullIteratee:Bool;
	var tempIterateeVarId:Int = 0;

	public function new(context:Context) {
		super(context);
		generateCheckNullIteratee = if (context.config.settings == null) false else context.config.settings.checkNullIteratee;
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEForIn(f):
				makeHaxeFor(getLoopVar(f.iter.eit), getForInData(f), processExpr(f.body));
			case TEForEach(f):
				makeHaxeFor(getLoopVar(f.iter.eit), getForEachData(f), processExpr(f.body));
			case _:
				mapExpr(processExpr, e);
		}
	}

	function makeHaxeFor(loopVar:LoopVarData, data:LoopData, body:TExpr):TExpr {
		var loopVarVar, loopVarToken;
		var outerDecl:Null<TVarDecl> = null;
		var innerIndent = getInnerIndent(body);

		switch loopVar.kind {
			case LOwn(kind, decl):
				outerDecl = {
					syntax: {name: decl.syntax.name.clone(), type: decl.syntax.type},
					v: loopVar.v,
					init: null,
					comma: null
				};
				outerDecl.syntax.name.leadTrivia = [];
				outerDecl.syntax.name.trailTrivia = [];

				// use temp loop var and assign to the declared var inside the loop body
				loopVarToken = mkIdent(tempLoopVarName, [], [whitespace]);
				loopVarVar = {name: tempLoopVarName, type: data.loopVarType};

				var eAssign = mk(TEBinop(
					mk(TELocal(mkIdent(loopVar.v.name), loopVar.v), loopVar.v.type, loopVar.v.type),
					OpAssign(mkTokenWithSpaces(TkEquals, "=")),
					mk(TELocal(mkIdent(tempLoopVarName), loopVarVar), data.loopVarType, loopVar.v.type)
				), TTVoid, TTVoid);
				processLeadingToken(t -> t.leadTrivia = cloneTrivia(innerIndent), eAssign);
				body = concatExprs(eAssign, body);

			case LShared(eLocal):
				// always use temp loop var and assign it to the shared var
				loopVarToken = mkIdent(tempLoopVarName, [], [whitespace]);
				loopVarVar = {name: tempLoopVarName, type: data.loopVarType};

				var eAssign = mk(TEBinop(
					eLocal,
					OpAssign(mkTokenWithSpaces(TkEquals, "=")),
					mk(TELocal(mkIdent(tempLoopVarName), loopVarVar), data.loopVarType, loopVar.v.type)
				), TTVoid, TTVoid);
				processLeadingToken(t -> t.leadTrivia = cloneTrivia(innerIndent), eAssign);

				body = concatExprs(eAssign, body);
		}

		var eFor = mk(TEHaxeFor({
			syntax: {
				forKeyword: data.syntax.forKeyword,
				openParen: data.syntax.openParen,
				itName: loopVarToken,
				inKeyword: data.syntax.inKeyword,
				closeParen: data.syntax.closeParen
			},
			vit: loopVarVar,
			iter: data.iterateeExpr,
			body: body
		}), TTVoid, TTVoid);


		var loopExpr;
		if (generateCheckNullIteratee) {
			var checkedExpr;
			if (data.iterateeTempVar == null) {
				checkedExpr = data.originalExpr;
			} else {
				checkedExpr = mk(TELocal(mkIdent(data.iterateeTempVar.name), data.iterateeTempVar), data.iterateeTempVar.type, data.iterateeTempVar.type);
			}

			loopExpr = mk(TEIf({
				syntax: {
					keyword: mkIdent("if", removeLeadingTrivia(eFor), [whitespace]),
					openParen: mkOpenParen(),
					closeParen: addTrailingWhitespace(mkCloseParen()),
				},
				econd: mkCheckNullIterateeExpr(checkedExpr),
				ethen: eFor,
				eelse: null
			}), TTVoid, TTVoid);
		} else {
			loopExpr = eFor;
		}

		if (data.iterateeTempVar == null) {
			if (outerDecl == null) {
				return loopExpr;
			}

			var loopLead = takeLeadingTrivia(loopExpr);
			var declToken = mkIdent("var", loopLead, [whitespace]);
			var outerExpr = mk(TEVars(VVar(declToken), [outerDecl]), TTVoid, TTVoid);
			return mkMergedBlock([
				{expr: outerExpr, semicolon: addTrailingNewline(mkSemicolon())},
				{expr: loopExpr, semicolon: null},
			]);
		} else {
			var loopLead = takeLeadingTrivia(loopExpr);
			var tempVarDecl = mk(TEVars(VConst(mkIdent("final", loopLead, [whitespace])), [{
				syntax: {
					name: mkIdent(data.iterateeTempVar.name),
					type: null
				},
				v: data.iterateeTempVar,
				init: {
					equalsToken: mkTokenWithSpaces(TkEquals, "="),
					expr: data.originalExpr,
				},
				comma: null
			}]), TTVoid, TTVoid);
			var loopExprs = [
				{expr: tempVarDecl, semicolon: addTrailingNewline(mkSemicolon())},
				{expr: loopExpr, semicolon: null},
			];
			if (outerDecl == null) {
				return mkMergedBlock(loopExprs);
			}
			var tempLead = takeLeadingTrivia(loopExprs[0].expr);
			var declToken = mkIdent("var", tempLead, [whitespace]);
			var outerExpr = mk(TEVars(VVar(declToken), [outerDecl]), TTVoid, TTVoid);
			return mkMergedBlock([
				{expr: outerExpr, semicolon: addTrailingNewline(mkSemicolon())},
			].concat(loopExprs));
		}
	}

	function getLoopVar(e:TExpr):LoopVarData {
		return switch e.kind {
			// for (var x in obj)
			case TEVars(kind, [varDecl]):
				{
					kind: LOwn(kind, varDecl),
					v: varDecl.v
				};

			// for (x in obj)
			case TELocal(_, v):
				{
					kind: LShared(e),
					v: v
				};

			case _:
				throwError(exprPos(e), "Unsupported `for...in` loop variable declaration");
		}
	}

	function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}


	function takeLeadingTrivia(expr:TExpr):Array<Trivia> {
		var lead = removeLeadingTrivia(expr);
		processLeadingToken(t -> t.leadTrivia = cloneTrivia(lead).concat(t.leadTrivia), expr);
		return lead;
	}

	inline function maybeTempVarIteratee(e:TExpr):{expr:TExpr, tempVar:Null<TVar>} {
		return if (!generateCheckNullIteratee || skipParens(e).kind.match(TELocal(_)))
			{
				expr: e,
				tempVar: null,
			};
		else {
			var tempVarName = "__ax4_iter_" + tempIterateeVarId++;
			var tempVar = {name: tempVarName, type: e.type};
			{
				tempVar: tempVar,
				expr: mk(TELocal(mkIdent(tempVarName), tempVar), e.type, e.type),
			};
		};
	}

	function getForInData(f:TForIn):LoopData {
		var eobj, iterTempVar;
		{
			var d = maybeTempVarIteratee(f.iter.eobj);
			eobj = d.expr;
			iterTempVar = d.tempVar;
		}

		var loopVarType;
		switch eobj.type {
			case TTInst(cls) if (hasInstanceFunction(cls, "keyIterator")):
				eobj = mkIteratorMethodCallExpr(eobj, "keyIterator");
				loopVarType = TTAny;

			case TTInst(cls) if (isDynamicIterateeClass(cls)):
				var retyped = mk(TEHaxeRetype(eobj), TTAny, TTAny);
				eobj = mkIteratorMethodCallExpr(retyped, "___keys");
				loopVarType = TTString;

			case TTDictionary(keyType, _):
				eobj = mkIteratorMethodCallExpr(eobj, "keys");
				loopVarType = keyType;

			case TTObject(valueType):
				// TTAny most probably means it's coming from an AS3 Object,
				// while any other type is surely coming from haxe.DynamicAccess
				var keysMethod = if (valueType == TTAny) "___keys" else "keys";
				eobj = mkIteratorMethodCallExpr(eobj, keysMethod);
				loopVarType = TTString;

			case TTAny:
				eobj = mkIteratorMethodCallExpr(eobj, "___keys");
				loopVarType = TTAny;

			case TTXMLList:
				eobj = mkIteratorMethodCallExpr(eobj, "keys");
				loopVarType = TTString;

			case TTArray(_) | TTVector(_):
				var pos = exprPos(eobj);
				var eZero = mk(TELiteral(TLInt(new Token(pos, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
				var eLength = mk(TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, "length", mkIdent("length")), TTInt, TTInt);
				eobj = mk(TEHaxeIntIter(eZero, eLength), TTBuiltin, TTBuiltin);
				loopVarType = TTInt;

			case other:
				throwError(exprPos(f.iter.eobj), "Unsupported iteratee type: " + other);
		}
		return {
			originalExpr: f.iter.eobj,
			iterateeExpr: eobj,
			iterateeTempVar: iterTempVar,
			loopVarType: loopVarType,
			syntax: {
				forKeyword: f.syntax.forKeyword,
				openParen: f.syntax.openParen,
				inKeyword: f.iter.inKeyword,
				closeParen: f.syntax.closeParen
			}
		};
	}

	function getForEachData(f:TForEach):LoopData {
		var eobj, iterTempVar;
		{
			var d = maybeTempVarIteratee(f.iter.eobj);
			eobj = d.expr;
			iterTempVar = d.tempVar;
		}

		var loopVarType;
		switch eobj.type {
			case TTInst(cls) if (hasInstanceFunction(cls, "iterator")):
				eobj = mkIteratorMethodCallExpr(eobj, "iterator");
				loopVarType = TTAny;

			case TTInst(cls) if (isDynamicIterateeClass(cls)):
				eobj = mk(TEHaxeRetype(eobj), TTAny, TTAny);
				loopVarType = TTAny;

			case TTObject(TTAny):
				eobj = mkIteratorMethodCallExpr(eobj, "iterator");
				loopVarType = TTAny;

			case TTAny:
				// Try to infer element type from array literal
				loopVarType = tryInferElementTypeFromExpr(eobj);
			case TTArray(t) | TTVector(t) | TTDictionary(_, t) | TTObject(t):
				// If the element type is Any, try to infer from array literal
				if (t == TTAny) {
					loopVarType = tryInferElementTypeFromExpr(eobj);
				} else {
					loopVarType = t;
				}
			case TTXMLList:
				loopVarType = TTXML;
			case other:
				throwError(exprPos(f.iter.eobj), "Unsupported iteratee type: " + other);
		}
		return {
			originalExpr: f.iter.eobj,
			iterateeExpr: eobj,
			iterateeTempVar: iterTempVar,
			loopVarType: loopVarType,
			syntax: {
				forKeyword: f.syntax.forKeyword,
				openParen: f.syntax.openParen,
				inKeyword: f.iter.inKeyword,
				closeParen: f.syntax.closeParen
			}
		};
	}

	static function isDynamicIterateeClass(cls:TClassOrInterfaceDecl):Bool {
		if (Lambda.exists(cls.modifiers, function(m) return m.match(DMDynamic(_)))) {
			return true;
		}
		return extendsProxy(cls);
	}

	static function hasInstanceFunction(cls:TClassOrInterfaceDecl, name:String):Bool {
		var found = cls.findFieldInHierarchy(name, false);
		return found != null && found.field.kind.match(TFFun(_));
	}

	static function extendsProxy(cls:TClassOrInterfaceDecl):Bool {
		return switch cls.kind {
			case TClass(info):
				if (info.extend == null) {
					false;
				} else {
					var parent = info.extend.superClass;
					if (parent.name == "Proxy" && parent.parentModule.parentPack.name == "flash.utils") {
						true;
					} else {
						extendsProxy(parent);
					}
				}
			case _: false;
		}
	}

	static inline function mkIteratorMethodCallExpr(eobj:TExpr, methodName:String):TExpr {
		var eMethod = mk(TEField({kind: TOExplicit(mkDot(), eobj), type: eobj.type}, methodName, mkIdent(methodName)), tIteratorMethod, tIteratorMethod);
		return mkCall(eMethod, []);
	}

	inline function mkCheckNullIterateeExpr(eobj:TExpr):TExpr {
		var eCheckBuiltin = mkBuiltin(checkNullIterateeBuiltin, TTBuiltin);
		context.addToplevelImport("ASCompat.checkNullIteratee", Import);
		return mkCall(eCheckBuiltin, [eobj], TTBoolean);
	}

	/**
	 * Try to infer the element type from an array literal expression.
	 * This helps avoid unnecessary casts when iterating over array literals.
	 */
	function tryInferElementTypeFromExpr(e:TExpr):TType {
		// Handle array literal [a, b, c]
		switch e.kind {
			case TEArrayDecl(arr):
				if (arr.elements.length == 0) return TTAny;

				// Try to find a common type among all elements
				var commonType:TType = null;
				for (elem in arr.elements) {
					var elemType = elem.expr.type;
					if (elemType == TTAny) {
						// If any element is TTAny, we can't infer a common type
						return TTAny;
					}
					if (commonType == null) {
						commonType = elemType;
					} else if (!typeEq(commonType, elemType)) {
						// Types don't match, fall back to TTAny
						return TTAny;
					}
				}
				return commonType != null ? commonType : TTAny;

			case _:
				return TTAny;
		}
	}
}

typedef LoopData = {
	var syntax:ForSyntax;
	var originalExpr:TExpr;
	var iterateeTempVar:Null<TVar>;
	var iterateeExpr:TExpr;
	var loopVarType:TType;
}

private typedef LoopVarData = {
	var kind:LoopVarKind;
	var v:TVar;
}

private typedef ForSyntax = {
	var forKeyword:Token;
	var openParen:Token;
	var inKeyword:Token;
	var closeParen:Token;
}

private enum LoopVarKind {
	LOwn(kind:VarDeclKind, decl:TVarDecl);
	LShared(eLocal:TExpr);
}
