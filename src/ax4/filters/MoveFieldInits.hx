package ax4.filters;

class MoveFieldInits extends AbstractFilter {
	override function processClass(c:TClassOrInterfaceDecl) {
		var pending:Array<{field:TVarField, init:TVarInit}> = [];
		var ctor:Null<TFunctionField> = null;

		for (member in c.members) {
			switch member {
				case TMField(f):
					switch f.kind {
						case TFFun(fun) if (isCtorName(fun.name, c.name)):
							ctor = fun;
						case TFVar(v) if (v.init != null && !TypedTreeTools.isFieldStatic(f)):
							if (needsMove(v.init.expr)) {
								pending.push({field: v, init: v.init});
								v.init = null;
							}
						case _:
					}
				case _:
			}
		}

		if (pending.length == 0) {
			return;
		}

		if (ctor == null) {
			ctor = addConstructor(c);
		}

		if (ctor.fun.expr == null) {
			return;
		}

		ctor.fun.expr = insertAssignments(c, ctor.fun.expr, pending);
	}

	static inline function isCtorName(name:String, className:String):Bool {
		return name == "new" || name == className;
	}

	function addConstructor(c:TClassOrInterfaceDecl):TFunctionField {
		var ctorField:TClassField = {
			metadata: [],
			namespace: null,
			modifiers: [FMPublic(new Token(0, TkIdent, "public", [], [whitespace]))],
			kind: TFFun({
				syntax: {
					keyword: new Token(0, TkIdent, "function", [], [whitespace]),
					name: new Token(0, TkIdent, c.name, [], [])
				},
				name: c.name,
				fun: {
					sig: {
						syntax: {openParen: mkOpenParen(), closeParen: mkCloseParen()},
						args: [],
						ret: {syntax: null, type: TTVoid}
					},
					expr: mk(TEBlock({
						syntax: {
							openBrace: mkOpenBrace(),
							closeBrace: addTrailingNewline(mkCloseBrace())
						},
						exprs: []
					}), TTVoid, TTVoid)
				},
				type: TTFun([], TTVoid),
				isInline: false,
				semicolon: null
			})
		};

		c.members.push(TMField(ctorField));
		return switch ctorField.kind {
			case TFFun(fun): fun;
			case _: throw "assert";
		}
	}

	function insertAssignments(c:TClassOrInterfaceDecl, expr:TExpr, pending:Array<{field:TVarField, init:TVarInit}>):TExpr {
		var block = switch expr.kind {
			case TEBlock(b): b;
			case _:
				return expr;
		};

		// Find the position of super() call
		var superIndex = -1;
		for (i in 0...block.exprs.length) {
			if (isSuperCall(block.exprs[i].expr)) {
				superIndex = i;
				break;
			}
		}

		// Collect field dependencies from all pending initializations
		var deps = new Map<String, Bool>();
		for (item in pending) {
			collectFieldDeps(item.init.expr, deps);
		}

		// Determine insert position
		var insertAt = 0;
		if (superIndex >= 0) {
			// Check if any dependencies are assigned before super()
			var hasDepsBeforeSuper = false;
			if (deps.keys().hasNext()) {
				for (i in 0...superIndex) {
					if (assignsToDeps(block.exprs[i].expr, deps)) {
						hasDepsBeforeSuper = true;
						break;
					}
				}
			}

			if (hasDepsBeforeSuper) {
				// If dependencies are assigned before super(), we must insert before super()
				// to preserve AS3 semantics (field inits happen before parent constructor)
				insertAt = superIndex;
				// Find the earliest position after all dependency assignments
				var i = superIndex - 1;
				while (i >= 0) {
					if (assignsToDeps(block.exprs[i].expr, deps)) {
						insertAt = i + 1;
						break;
					}
					i--;
				}
			} else {
				// No dependencies before super(), insert after super() (default behavior)
				insertAt = superIndex + 1;
			}
		}

		var indent = TypedTreeTools.getInnerIndent(expr);
		var leadForFirst:Array<Trivia>;
		if (insertAt < block.exprs.length) {
			leadForFirst = removeLeadingTrivia(block.exprs[insertAt].expr);
			var extracted = extractIndent(leadForFirst);
			indent = extracted;
			processLeadingToken(t -> t.leadTrivia = cloneTrivia(extracted).concat(t.leadTrivia), block.exprs[insertAt].expr);
		} else if (block.exprs.length == 0) {
			leadForFirst = [newline].concat(cloneTrivia(indent));
		} else {
			if (!exprHasTrailingNewline(block.exprs[block.exprs.length - 1])) {
				leadForFirst = [newline].concat(cloneTrivia(indent));
			} else {
				leadForFirst = cloneTrivia(indent);
			}
		}

		var assignments:Array<TBlockExpr> = [];
		var isFirst = true;
		for (item in pending) {
			var assignExpr = mkAssignExpr(c, item.field, item.init.expr);
			var lead = isFirst ? leadForFirst : cloneTrivia(indent);
			processLeadingToken(t -> t.leadTrivia = cloneTrivia(lead).concat(t.leadTrivia), assignExpr);
			assignments.push({expr: assignExpr, semicolon: addTrailingNewline(mkSemicolon())});
			isFirst = false;
		}

		var newExprs = block.exprs.slice(0, insertAt).concat(assignments).concat(block.exprs.slice(insertAt));
		return expr.with(kind = TEBlock(block.with(exprs = newExprs)));
	}

	function mkAssignExpr(c:TClassOrInterfaceDecl, field:TVarField, initExpr:TExpr):TExpr {
		var nameToken = mkIdent(field.name);
		var fieldObj:TFieldObject = {kind: TOImplicitThis(c), type: TTInst(c)};
		var left = mk(TEField(fieldObj, field.name, nameToken), field.type, field.type);
		var assignToken = new Token(0, TkEquals, "=", [whitespace], [whitespace]);
		return mk(TEBinop(left, OpAssign(assignToken), initExpr), field.type, TTVoid);
	}

	static function isSuperCall(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): isSuperCall(inner);
			case TECall({kind: TELiteral(TLSuper(_))}, _): true;
			case _: false;
		}
	}

	static function needsMove(e:TExpr):Bool {
		var found = false;
		function walk(expr:TExpr) {
			if (found) return;
			switch expr.kind {
				case TELiteral(TLThis(_) | TLSuper(_)):
					found = true;
				case TEField(obj, _, _):
					if (isThisObject(obj)) {
						found = true;
					} else {
						switch obj.kind {
							case TOExplicit(_, inner): walk(inner);
							case _:
						}
					}
				case _:
					iterExpr(walk, expr);
			}
		}
		walk(e);
		return found;
	}

	static inline function isThisObject(obj:TFieldObject):Bool {
		return switch obj.kind {
			case TOImplicitThis(_): true;
			case TOExplicit(_, {kind: TELiteral(TLThis(_) | TLSuper(_))}): true;
			case _:
				false;
		}
	}

	static function collectFieldDeps(e:TExpr, deps:Map<String, Bool>):Void {
		switch e.kind {
			case TEField(obj, name, _):
				if (isThisObject(obj)) {
					deps[name] = true;
				} else {
					switch obj.kind {
						case TOExplicit(_, inner): collectFieldDeps(inner, deps);
						case _:
					}
				}
			case _:
				iterExpr(e2 -> collectFieldDeps(e2, deps), e);
		}
	}

	static function assignsToDeps(e:TExpr, deps:Map<String, Bool>):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): assignsToDeps(inner, deps);
			case TEBinop(left, OpAssign(_), _):
				switch left.kind {
					case TEField(obj, name, _):
						isThisObject(obj) && deps.exists(name);
					case _:
						false;
				}
			case _:
				false;
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

	static function exprHasTrailingNewline(expr:TBlockExpr):Bool {
		if (expr.semicolon != null) {
			return triviaHasNewline(expr.semicolon.trailTrivia);
		}
		var trail = processTrailingToken(t -> t.trailTrivia, expr.expr);
		return triviaHasNewline(trail);
	}

	static function triviaHasNewline(trivia:Array<Trivia>):Bool {
		for (item in trivia) {
			if (item.kind == TrNewline) return true;
		}
		return false;
	}
}
