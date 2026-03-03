package ax4.filters;

class RewriteDelete extends AbstractFilter {
	static final tDeleteProperty = TTFun([TTAny, TTString], TTBoolean);

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEDelete(keyword, eobj):
				switch eobj.kind {
					case TEArrayAccess(a) | TEParens(_, {kind: TEArrayAccess(a)}, _):
						rewrite(keyword, a, eobj, e);

					case TEField(obj, fieldName, fieldToken) | TEParens(_, {kind: TEField(obj, fieldName, fieldToken)}, _):
						rewriteFieldDelete(keyword, obj, fieldName, fieldToken, e);

					case _:
						reportError(exprPos(eobj), "Unsupported `delete` operation");
						e;
				}
			case _:
				e;
		}
	}

	function rewriteFieldDelete(deleteKeyword:Token, obj:TFieldObject, fieldName:String, fieldToken:Token, eDelete:TExpr):TExpr {
		var lead = removeLeadingTrivia(eDelete);
		var trail = removeTrailingTrivia(eDelete);
		var eDeleteField = mkBuiltin("ASCompat.deleteProperty", tDeleteProperty, lead);
		var objectExpr:TExpr;
		var extraLead:Array<Trivia> = [];

		switch obj.kind {
			case TOExplicit(dot, eobj):
				objectExpr = eobj;
				extraLead = dot.leadTrivia.concat(dot.trailTrivia);

			case TOImplicitThis(_):
				objectExpr = mk(TELiteral(TLThis(mkIdent("this", fieldToken.leadTrivia, []))), obj.type, obj.type);
				fieldToken.leadTrivia = [];

			case TOImplicitClass(cls):
				objectExpr = mkDeclRef({first: mkIdent(cls.name, fieldToken.leadTrivia, []), rest: []}, {name: cls.name, kind: TDClassOrInterface(cls)}, null);
				fieldToken.leadTrivia = [];
		}

		var nameToken = new Token(fieldToken.pos, TkStringDouble, haxe.Json.stringify(fieldName), extraLead.concat(fieldToken.leadTrivia), fieldToken.trailTrivia);
		fieldToken.leadTrivia = [];
		fieldToken.trailTrivia = [];
		var eName = mk(TELiteral(TLString(nameToken)), TTString, TTString);

		return mk(TECall(eDeleteField, {
			openParen: mkOpenParen(),
			args: [{expr: objectExpr, comma: commaWithSpace}, {expr: eName, comma: null}],
			closeParen: mkCloseParen(trail)
		}), TTBoolean, eDelete.expectedType);
	}

	function rewrite(deleteKeyword:Token, a:TArrayAccess, eDeleteObj:TExpr, eDelete:TExpr):TExpr {
		// TODO: trivia \o/
		return switch [a.eobj.type, a.eindex.type] {
			case [TTDictionary(keyType, _), _]:
				processLeadingToken(function(t) {
					t.leadTrivia = deleteKeyword.leadTrivia.concat(t.leadTrivia);
				}, a.eobj);

				var eRemoveField = mk(TEField({kind: TOExplicit(mkDot(), a.eobj), type: a.eobj.type}, "remove", mkIdent("remove")), TTFunction, TTFunction);
				mkCall(eRemoveField, [a.eindex.with(expectedType = keyType)], TTBoolean);

			case [TTObject(_), _] | [TTAny, _] | [_, TTString]:
				// TODO: this should actually generate (expr : ASObject).___delete that handles delection of Dictionary keys too
				// make sure the expected type is string so further filters add the cast
				var eindex = if (a.eindex.type != TTString) a.eindex.with(expectedType = TTString) else a.eindex;
				var eDeleteField = mkBuiltin("ASCompat.deleteProperty", tDeleteProperty, deleteKeyword.leadTrivia);
				eDelete.with(kind = TECall(eDeleteField, {
					openParen: new Token(0, TkParenOpen, "(", a.syntax.openBracket.leadTrivia, a.syntax.openBracket.trailTrivia),
					closeParen: new Token(0, TkParenClose, ")", a.syntax.openBracket.leadTrivia, a.syntax.openBracket.trailTrivia),
					args: [{expr: a.eobj, comma: commaWithSpace}, {expr: eindex, comma: null}]
				}));

			case [TTInst(cls), _] if (isDynamicClass(cls) || isProxyClass(cls)):
				var eindex = if (a.eindex.type != TTString) a.eindex.with(expectedType = TTString) else a.eindex;
				var eDeleteField = mkBuiltin("ASCompat.deleteProperty", tDeleteProperty, deleteKeyword.leadTrivia);
				eDelete.with(kind = TECall(eDeleteField, {
					openParen: new Token(0, TkParenOpen, "(", a.syntax.openBracket.leadTrivia, a.syntax.openBracket.trailTrivia),
					closeParen: new Token(0, TkParenClose, ")", a.syntax.openBracket.leadTrivia, a.syntax.openBracket.trailTrivia),
					args: [{expr: a.eobj, comma: commaWithSpace}, {expr: eindex, comma: null}]
				}));

			case [TTXMLList, TTInt | TTUint]:
				var lead = removeLeadingTrivia(eDelete);
				var trail = removeTrailingTrivia(eDelete);
				processLeadingToken(function(t) {
					t.leadTrivia = lead.concat(t.leadTrivia);
				}, a.eobj);

				var eindex = if (a.eindex.type == TTUint) a.eindex.with(expectedType = TTInt) else a.eindex;
				var eDeleteAt = mk(TEField({kind: TOExplicit(mkDot(), a.eobj), type: a.eobj.type}, "deleteAt", mkIdent("deleteAt")), TTFunction, TTFunction);
				mkCall(eDeleteAt, [eindex], TTBoolean, trail).with(expectedType = eDelete.expectedType);

			case [TTArray(_), TTInt | TTUint]:
				reportError(exprPos(a.eindex), 'delete on array?');

				if (eDelete.expectedType == TTBoolean) {
					throw "TODO"; // always true probably
				}

				processLeadingToken(function(t) {
					t.leadTrivia = deleteKeyword.leadTrivia.concat(t.leadTrivia);
				}, eDeleteObj);

				mk(TEBinop(eDeleteObj, OpAssign(new Token(0, TkEquals, "=", [], [])), mkNullExpr()), TTVoid, TTVoid);

			case _:
				throwError(exprPos(a.eindex), 'Unknown `delete` expression: index type = ${a.eindex.type.getName()}, object type = ${a.eobj.type}');
		}
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

	static function isProxyClass(cls:TClassOrInterfaceDecl):Bool {
		return switch cls.kind {
			case TClass(info) if (info.extend != null):
				info.extend.superClass.parentModule.parentPack.name == "flash.utils"
					&& info.extend.superClass.name == "Proxy";
			case _:
				false;
		}
	}
}
