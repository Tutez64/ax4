package ax4.filters;

class FixVoidReturn extends AbstractFilter {
	final returnStack:Array<TType> = [];
	var currentClassName:Null<String> = null;

	override function processClass(c:TClassOrInterfaceDecl) {
		var prev = currentClassName;
		currentClassName = c.name;
		super.processClass(c);
		currentClassName = prev;
	}

	override function processFunction(fun:TFunction) {
		processFunctionWithReturnType(fun, fun.sig.ret.type);
	}

	override function processClassField(field:TClassField) {
		switch field.kind {
			case TFVar(v):
				processVarField(v);
			case TFFun(field) if (field.name == "new" || field.name == currentClassName):
				processFunctionWithReturnType(field.fun, TTVoid);
			case TFFun(field):
				processFunction(field.fun);
			case TFGetter(field):
				processFunction(field.fun);
			case TFSetter(field):
				processFunction(field.fun);
		}
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TELocalFunction(f):
				processFunctionWithReturnType(f.fun, f.fun.sig.ret.type);
				e;
			case TEReturn(keyword, null):
				var retType = returnStack.length > 0 ? returnStack[returnStack.length - 1] : TTVoid;
				if (retType == TTVoid) {
					e;
				} else {
					if (keyword.trailTrivia.length == 0) {
						keyword.trailTrivia.push(whitespace);
					}
					var value = defaultReturnExpr(retType);
					e.with(kind = TEReturn(keyword, value));
				}
			case _:
				mapExpr(processExpr, e);
		}
	}

	function processFunctionWithReturnType(fun:TFunction, retType:TType) {
		returnStack.push(retType);
		if (fun.expr != null) {
			fun.expr = processExpr(fun.expr);
			if (retType != TTVoid) {
				switch fun.expr.kind {
					case TEBlock(block):
						if (block.exprs.length == 0 || !block.exprs[block.exprs.length - 1].expr.kind.match(TEReturn(_))) {
							var keyword = mkIdent("return");
							if (keyword.trailTrivia.length == 0) {
								keyword.trailTrivia.push(whitespace);
							}
							var value = defaultReturnExpr(retType);
							block.exprs.push({
								expr: mk(TEReturn(keyword, value), TTVoid, TTVoid),
								semicolon: addTrailingNewline(mkSemicolon())
							});
							fun.expr = fun.expr.with(kind = TEBlock(block));
						}
					case _:
				}
			}
		}
		returnStack.pop();
	}

	static function defaultReturnExpr(t:TType):TExpr {
		return switch t {
			case TTBoolean:
				mk(TELiteral(TLBool(mkIdent("false"))), TTBoolean, TTBoolean);
			case TTInt:
				mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
			case TTUint:
				mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTUint, TTUint);
			case TTNumber:
				mkBuiltin("NaN", TTNumber);
			case _:
				mkNullExpr(t);
		}
	}
}
