package ax4.filters;

class FixNonInlineableDefaultArgs extends AbstractFilter {
	override function processFunction(fun:TFunction) {
		if (fun.expr == null) return;
		var initExprs = [];
		var indent = getInnerIndent(fun.expr);
		for (arg in fun.sig.args) {
			switch arg.kind {
				case TArgNormal(type, init = {expr: initExpr}):
					if (!isConstantExpr(initExpr)) {
						var eLocal = mk(TELocal(mkIdent(arg.name), arg.v), arg.v.type, arg.v.type);
						var check = mk(TEIf({
							syntax: {
								keyword: mkIdent("if", indent, [whitespace]),
								openParen: mkOpenParen(),
								closeParen: addTrailingWhitespace(mkCloseParen())
							},
							econd: mk(TEBinop(eLocal, OpEquals(mkEqualsEqualsToken()), mkNullExpr()), TTBoolean, TTBoolean),
							ethen: mk(TEBinop(eLocal, OpAssign(new Token(0, TkEquals, "=", [whitespace], [whitespace])), init.expr), eLocal.type, eLocal.type),
							eelse: null
						}), TTVoid, TTVoid);
						initExprs.push({
							expr: check,
							semicolon: addTrailingNewline(mkSemicolon()),
						});
						arg.kind = TArgNormal(type, init.with(expr = mkNullExpr(arg.type)));
					}
				case _:
			}
		}
		if (initExprs.length > 0) {
			var initBlock = mk(TEBlock({
				syntax: {
					openBrace: addTrailingNewline(mkOpenBrace()),
					closeBrace: mkCloseBrace()
				},
				exprs: initExprs,
			}), TTVoid, TTVoid);
			fun.expr = concatExprs(initBlock, fun.expr);
		}
	}

	static function isConstantExpr(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, e2, _):
				isConstantExpr(e2);
			case TEHaxeRetype(e2):
				isConstantExpr(e2);

			case TEField(obj, fieldName, _):
				switch obj.type {
					case TTStatic(cls):
						var f = cls.findFieldInHierarchy(fieldName, true);
						(f != null) && f.field.kind.match(TFVar({kind: VConst(_)}));
					case _:
						false;
				}

			case TEDeclRef(_):
				true;

			case TELiteral(TLBool(_) | TLNull(_) | TLUndefined(_) | TLInt(_) | TLNumber(_) | TLString(_)):
				true;

			case _:
				false;
		}
	}
}
