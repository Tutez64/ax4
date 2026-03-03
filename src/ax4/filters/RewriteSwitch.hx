package ax4.filters;

private typedef BreakRewriteResult = {
	var expr:TExpr;
	var hasBreak:Bool;
}

private typedef BlockRewriteResult = {
	var exprs:Array<TBlockExpr>;
	var hasBreak:Bool;
	var firstBreakIndex:Int;
}

// TODO: rewrite `default` to `case _`?
class RewriteSwitch extends AbstractFilter {
	var breakVarIndex = 0;

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TESwitch(s):
				var switchHasBreak = false;
				var switchHasContinue = false;
				var newCases:Array<TSwitchCase> = [];
				var valueAcc = [];

				function processCaseBody(block:Array<TBlockExpr>, allowNonTerminalLast:Bool):Array<Trivia> {
					switch block {
						case [{expr: {kind: TEBlock(b)}}]:  block = b.exprs; // for cases with "braced" body: `case value: {...}`
						case _:
					}

					if (block.length == 0) return []; // empty block - nothing to do here

					var lastExpr = block[block.length - 1].expr;
					switch lastExpr.kind {
						case TEBreak(breakToken):
							var blockExpr = block.pop();
							var trivia = breakToken.leadTrivia.concat(breakToken.trailTrivia);
							if (blockExpr.semicolon != null) {
								trivia = trivia.concat(blockExpr.semicolon.leadTrivia).concat(blockExpr.semicolon.trailTrivia);
							}
							if (block.length > 0) {
								var hasBreak = hasSwitchBreak(block);
								var hasContinue = hasSwitchContinue(block);
								if (hasBreak) switchHasBreak = true;
								if (hasContinue) switchHasContinue = true;
							}
							return trivia;

						case TEReturn(_) | TEContinue(_) | TEThrow(_): // allowed terminators
							if (block.length > 0) {
								var hasBreak = hasSwitchBreak(block);
								var hasContinue = hasSwitchContinue(block);
								if (hasBreak) switchHasBreak = true;
								if (hasContinue) switchHasContinue = true;
							}
							return [];

						case _:
							if (!allowNonTerminalLast) {
								throwError(exprPos(lastExpr), "Non-terminal expression inside a switch case, possible fall-through?");
							}
							if (block.length > 0) {
								var hasBreak = hasSwitchBreak(block);
								var hasContinue = hasSwitchContinue(block);
								if (hasBreak) switchHasBreak = true;
								if (hasContinue) switchHasContinue = true;
							}
							return [];
					}
				}

				for (i in 0...s.cases.length) {
					var c = s.cases[i];
					var value = switch c.values {
						case [value]: value;
						case _: throw "assert";
					};
					valueAcc.push({syntax: c.syntax, value: value});
					if (c.body.length > 0) {
						var values = [];
						for (v in valueAcc) {
							var expr = v.value;
							processLeadingToken(function(t) {
								t.leadTrivia = t.leadTrivia.concat(v.syntax.keyword.leadTrivia);
							}, expr);
							processTrailingToken(function(t) {
								t.trailTrivia = t.trailTrivia.concat(v.syntax.colon.leadTrivia).concat(v.syntax.colon.trailTrivia);
							}, expr);
							values.push(expr);
						}

						var isLast = (i == s.cases.length - 1) && s.def == null;

						var breakTrivia = processCaseBody(c.body, isLast);

						var colonTrivia = removeTrailingTrivia(values[values.length - 1]);
						if (breakTrivia.length > 0) {
							if (c.body.length == 0) {
								colonTrivia = colonTrivia.concat(breakTrivia);
							} else {
								var lastBlockExpr = c.body[c.body.length - 1];
								if (lastBlockExpr.semicolon != null) {
									lastBlockExpr.semicolon.trailTrivia = lastBlockExpr.semicolon.trailTrivia.concat(breakTrivia);
								} else {
									processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(breakTrivia), lastBlockExpr.expr);
								}
							}
						}

						newCases.push({
							syntax: {
								keyword: new Token(0, TkIdent, "case", removeLeadingTrivia(values[0]), [whitespace]),
								colon: new Token(0, TkColon, ":", [], colonTrivia)
							},
							values: values,
							body: c.body // mutated inplace
						});
						valueAcc = [];
					}
				}

				if (s.def != null) {
					processCaseBody(s.def.body, true);
				}

				var breakVar:Null<TVar> = null;
				if (switchHasContinue) {
					var switchBreakVar = {name: "__ax4SwitchBreak" + breakVarIndex++, type: TTBoolean};
					breakVar = switchBreakVar;
					for (c in newCases) {
						if (hasSwitchBreak(c.body)) {
							rewriteSwitchBreaksWithVar(c.body, switchBreakVar);
						}
					}
					if (s.def != null && hasSwitchBreak(s.def.body)) {
						rewriteSwitchBreaksWithVar(s.def.body, switchBreakVar);
					}
				}

				var switchExpr = e.with(kind = TESwitch({
					syntax: s.syntax,
					subj: s.subj,
					cases: newCases,
					def: s.def
				}));
				if (switchHasBreak && !switchHasContinue) {
					wrapSwitchExpr(switchExpr);
				} else if (switchHasContinue) {
					if (breakVar == null) throw "assert";
					addSwitchBreakPrelude(switchExpr, breakVar);
				} else {
					switchExpr;
				}

			case _:
				e;
		}
	}

	function hasSwitchBreakExpr(expr:TExpr, loopDepth:Int):Bool {
		return switch expr.kind {
			case TEBreak(_):
				loopDepth == 0;

			case TEWhile(w):
				hasSwitchBreakExpr(w.cond, loopDepth) || hasSwitchBreakExpr(w.body, loopDepth + 1);

			case TEDoWhile(w):
				hasSwitchBreakExpr(w.body, loopDepth + 1) || hasSwitchBreakExpr(w.cond, loopDepth);

			case TEHaxeFor(f):
				hasSwitchBreakExpr(f.iter, loopDepth) || hasSwitchBreakExpr(f.body, loopDepth + 1);

			case TEFor(f):
				(f.einit != null && hasSwitchBreakExpr(f.einit, loopDepth))
					|| (f.econd != null && hasSwitchBreakExpr(f.econd, loopDepth))
					|| (f.eincr != null && hasSwitchBreakExpr(f.eincr, loopDepth))
					|| hasSwitchBreakExpr(f.body, loopDepth + 1);

			case TEForIn(f):
				hasSwitchBreakExpr(f.iter.eit, loopDepth)
					|| hasSwitchBreakExpr(f.iter.eobj, loopDepth)
					|| hasSwitchBreakExpr(f.body, loopDepth + 1);

			case TEForEach(f):
				hasSwitchBreakExpr(f.iter.eit, loopDepth)
					|| hasSwitchBreakExpr(f.iter.eobj, loopDepth)
					|| hasSwitchBreakExpr(f.body, loopDepth + 1);

			case TELocalFunction(_) | TESwitch(_):
				false;

			case _:
				var found = false;
				iterExpr(function(inner) {
					if (!found && hasSwitchBreakExpr(inner, loopDepth)) {
						found = true;
					}
				}, expr);
				found;
		}
	}

	function hasSwitchContinueExpr(expr:TExpr, loopDepth:Int):Bool {
		return switch expr.kind {
			case TEContinue(_):
				loopDepth == 0;

			case TEWhile(w):
				hasSwitchContinueExpr(w.cond, loopDepth) || hasSwitchContinueExpr(w.body, loopDepth + 1);

			case TEDoWhile(w):
				hasSwitchContinueExpr(w.body, loopDepth + 1) || hasSwitchContinueExpr(w.cond, loopDepth);

			case TEHaxeFor(f):
				hasSwitchContinueExpr(f.iter, loopDepth) || hasSwitchContinueExpr(f.body, loopDepth + 1);

			case TEFor(f):
				(f.einit != null && hasSwitchContinueExpr(f.einit, loopDepth))
					|| (f.econd != null && hasSwitchContinueExpr(f.econd, loopDepth))
					|| (f.eincr != null && hasSwitchContinueExpr(f.eincr, loopDepth))
					|| hasSwitchContinueExpr(f.body, loopDepth + 1);

			case TEForIn(f):
				hasSwitchContinueExpr(f.iter.eit, loopDepth)
					|| hasSwitchContinueExpr(f.iter.eobj, loopDepth)
					|| hasSwitchContinueExpr(f.body, loopDepth + 1);

			case TEForEach(f):
				hasSwitchContinueExpr(f.iter.eit, loopDepth)
					|| hasSwitchContinueExpr(f.iter.eobj, loopDepth)
					|| hasSwitchContinueExpr(f.body, loopDepth + 1);

			case TELocalFunction(_) | TESwitch(_):
				false;

			case _:
				var found = false;
				iterExpr(function(inner) {
					if (!found && hasSwitchContinueExpr(inner, loopDepth)) {
						found = true;
					}
				}, expr);
				found;
		}
	}

	function hasSwitchBreak(block:Array<TBlockExpr>):Bool {
		for (expr in block) {
			if (hasSwitchBreakExpr(expr.expr, 0)) {
				return true;
			}
		}
		return false;
	}

	function hasSwitchContinue(block:Array<TBlockExpr>):Bool {
		for (expr in block) {
			if (hasSwitchContinueExpr(expr.expr, 0)) {
				return true;
			}
		}
		return false;
	}

	function wrapSwitchExpr(switchExpr:TExpr):TExpr {
		var leadTrivia = removeLeadingTrivia(switchExpr);
		var indentTrivia = extractIndent(leadTrivia);
		processLeadingToken(t -> t.leadTrivia = addIndent(indentTrivia), switchExpr);
		var trailTrivia = removeTrailingTrivia(switchExpr);

		var blockExpr = mk(TEBlock({
			syntax: {
				openBrace: new Token(0, TkBraceOpen, "{", [], [newline]),
				closeBrace: new Token(0, TkBraceClose, "}", [newline].concat(cloneTrivia(indentTrivia)), [whitespace])
			},
			exprs: [{expr: switchExpr, semicolon: null}]
		}), TTVoid, TTVoid);

		var doWhile = mk(TEDoWhile({
			syntax: {
				doKeyword: mkIdent("do", cloneTrivia(leadTrivia), [whitespace]),
				whileKeyword: mkIdent("while", [], [whitespace]),
				openParen: mkOpenParen(),
				closeParen: mkCloseParen()
			},
			body: blockExpr,
			cond: mk(TELiteral(TLBool(mkIdent("false"))), TTBoolean, TTBoolean)
		}), TTVoid, TTVoid);

		return mkMergedBlock([
			{
				expr: doWhile,
				semicolon: new Token(0, TkSemicolon, ";", [], trailTrivia)
			}
		]);
	}

	function addSwitchBreakPrelude(switchExpr:TExpr, breakVar:TVar):TExpr {
		var leadTrivia = removeLeadingTrivia(switchExpr);
		var indentTrivia = extractIndent(leadTrivia);
		processLeadingToken(t -> t.leadTrivia = cloneTrivia(indentTrivia), switchExpr);

		var varDecl = mk(TEVars(VVar(mkIdent("var", cloneTrivia(leadTrivia), [whitespace])), [{
			syntax: {name: mkIdent(breakVar.name), type: null},
			v: breakVar,
			init: {
				equalsToken: mkTokenWithSpaces(TkEquals, "="),
				expr: mk(TELiteral(TLBool(mkIdent("false"))), TTBoolean, TTBoolean)
			},
			comma: null
		}]), TTVoid, TTVoid);

		var semicolon = mkSemicolon();
		semicolon.trailTrivia = [newline];

		return mkMergedBlock([
			{expr: varDecl, semicolon: semicolon},
			{expr: switchExpr, semicolon: null}
		]);
	}

	function rewriteSwitchBreaks(block:Array<TBlockExpr>) {
		var breakVar:Null<TVar> = null;
		var firstBreakIndex = -1;

		function getBreakVar():TVar {
			if (breakVar == null) {
				breakVar = {name: "__ax4SwitchBreak" + breakVarIndex++, type: TTBoolean};
			}
			return breakVar;
		}

		var result = rewriteSwitchBreaksBlock(block, getBreakVar);
		if (!result.hasBreak) {
			if (result.exprs != block) {
				replaceBlockExprs(block, result.exprs);
			}
			return;
		}

		firstBreakIndex = result.firstBreakIndex;
		if (firstBreakIndex < 0) firstBreakIndex = 0;

		var leadTrivia = processLeadingToken(t -> t.leadTrivia, result.exprs[firstBreakIndex].expr);
		var varLead = extractBreakVarLead(leadTrivia);
		var decl = mkBreakVarDecl(getBreakVar(), varLead);
		result.exprs.insert(firstBreakIndex, decl);
		replaceBlockExprs(block, result.exprs);
	}

	function rewriteSwitchBreaksBlock(exprs:Array<TBlockExpr>, getBreakVar:Void->TVar):BlockRewriteResult {
		var needsGuard = false;
		var hasBreak = false;
		var firstBreakIndex = -1;
		var newExprs:Array<TBlockExpr> = [];

		for (i in 0...exprs.length) {
			var blockExpr = exprs[i];
			var result = rewriteSwitchBreaksExpr(blockExpr.expr, getBreakVar, false);
			var expr = result.expr;

			if (needsGuard) {
				expr = wrapWithBreakGuard(expr, getBreakVar());
			}

			var newBlockExpr = if (expr == blockExpr.expr && !needsGuard) blockExpr else blockExpr.with(expr = expr);
			newExprs.push(newBlockExpr);

			if (result.hasBreak) {
				if (!hasBreak) {
					firstBreakIndex = newExprs.length - 1;
				}
				hasBreak = true;
				needsGuard = true;
			}
		}

		return {
			exprs: newExprs,
			hasBreak: hasBreak,
			firstBreakIndex: firstBreakIndex
		};
	}

	function rewriteSwitchBreaksWithVar(block:Array<TBlockExpr>, breakVar:TVar) {
		var result = rewriteSwitchBreaksBlockWithVar(block, breakVar);
		if (result.exprs != block) {
			replaceBlockExprs(block, result.exprs);
		}
	}

	function rewriteSwitchBreaksBlockWithVar(exprs:Array<TBlockExpr>, breakVar:TVar):BlockRewriteResult {
		var needsGuard = false;
		var hasBreak = false;
		var firstBreakIndex = -1;
		var newExprs:Array<TBlockExpr> = [];

		for (i in 0...exprs.length) {
			var blockExpr = exprs[i];
			var result = rewriteSwitchBreaksExprWithVar(blockExpr.expr, breakVar, false);
			var expr = result.expr;

			if (needsGuard) {
				expr = wrapWithBreakGuard(expr, breakVar);
			}

			var newBlockExpr = if (expr == blockExpr.expr && !needsGuard) blockExpr else blockExpr.with(expr = expr);
			newExprs.push(newBlockExpr);

			if (result.hasBreak) {
				if (!hasBreak) {
					firstBreakIndex = newExprs.length - 1;
				}
				hasBreak = true;
				needsGuard = true;
			}
		}

		return {
			exprs: newExprs,
			hasBreak: hasBreak,
			firstBreakIndex: firstBreakIndex
		};
	}

	function rewriteSwitchBreaksExprWithVar(expr:TExpr, breakVar:TVar, inLoop:Bool):BreakRewriteResult {
		if (inLoop) {
			return {expr: expr, hasBreak: false};
		}

		return switch expr.kind {
			case TEBreak(breakToken):
				{expr: mkBreakAssignExpr(breakVar, breakToken), hasBreak: true};

			case TEBlock(block):
				var result = rewriteSwitchBreaksBlockWithVar(block.exprs, breakVar);
				var newBlock = if (result.exprs == block.exprs) block else block.with(exprs = result.exprs);
				var newExpr = if (newBlock == block) expr else expr.with(kind = TEBlock(newBlock));
				{expr: newExpr, hasBreak: result.hasBreak};

			case TEIf(i):
				var thenResult = rewriteSwitchBreaksExprWithVar(i.ethen, breakVar, false);
				var elseResult =
					if (i.eelse == null) null else rewriteSwitchBreaksExprWithVar(i.eelse.expr, breakVar, false);

				var hasBreak = thenResult.hasBreak || (elseResult != null && elseResult.hasBreak);
				var newElse =
					if (i.eelse == null) null
					else if (elseResult.expr == i.eelse.expr) i.eelse
					else i.eelse.with(expr = elseResult.expr);
				var newIf =
					if (thenResult.expr == i.ethen && newElse == i.eelse) i
					else i.with(ethen = thenResult.expr, eelse = newElse);
				var newExpr = if (newIf == i) expr else expr.with(kind = TEIf(newIf));
				{expr: newExpr, hasBreak: hasBreak};

			case TETry(t):
				var exprResult = rewriteSwitchBreaksExprWithVar(t.expr, breakVar, false);
				var hasBreak = exprResult.hasBreak;
				var catchesChanged = false;
				var newCatches = [];
				for (c in t.catches) {
					var catchResult = rewriteSwitchBreaksExprWithVar(c.expr, breakVar, false);
					if (catchResult.hasBreak) hasBreak = true;
					if (catchResult.expr != c.expr) catchesChanged = true;
					newCatches.push(catchResult.expr == c.expr ? c : c.with(expr = catchResult.expr));
				}
				var newTry =
					if (!catchesChanged && exprResult.expr == t.expr) t
					else t.with(expr = exprResult.expr, catches = newCatches);
				var newExpr = if (newTry == t) expr else expr.with(kind = TETry(newTry));
				{expr: newExpr, hasBreak: hasBreak};

			case TECondCompBlock(v, inner):
				var innerResult = rewriteSwitchBreaksExprWithVar(inner, breakVar, false);
				var newExpr = if (innerResult.expr == inner) expr else expr.with(kind = TECondCompBlock(v, innerResult.expr));
				{expr: newExpr, hasBreak: innerResult.hasBreak};

			case TEParens(openParen, inner, closeParen):
				var innerResult = rewriteSwitchBreaksExprWithVar(inner, breakVar, false);
				var newExpr =
					if (innerResult.expr == inner) expr
					else expr.with(
						kind = TEParens(openParen, innerResult.expr, closeParen),
						type = innerResult.expr.type,
						expectedType = innerResult.expr.expectedType
					);
				{expr: newExpr, hasBreak: innerResult.hasBreak};

			case TEWhile(_) | TEDoWhile(_) | TEFor(_) | TEForIn(_) | TEForEach(_) | TEHaxeFor(_) | TELocalFunction(_) | TESwitch(_):
				{expr: expr, hasBreak: false};

			case _:
				{expr: expr, hasBreak: false};
		}
	}

	function rewriteSwitchBreaksExpr(expr:TExpr, getBreakVar:Void->TVar, inLoop:Bool):BreakRewriteResult {
		if (inLoop) {
			return {expr: expr, hasBreak: false};
		}

		return switch expr.kind {
			case TEBreak(breakToken):
				{expr: mkBreakAssignExpr(getBreakVar(), breakToken), hasBreak: true};

			case TEBlock(block):
				var result = rewriteSwitchBreaksBlock(block.exprs, getBreakVar);
				var newBlock = if (result.exprs == block.exprs) block else block.with(exprs = result.exprs);
				var newExpr = if (newBlock == block) expr else expr.with(kind = TEBlock(newBlock));
				{expr: newExpr, hasBreak: result.hasBreak};

			case TEIf(i):
				var thenResult = rewriteSwitchBreaksExpr(i.ethen, getBreakVar, false);
				var elseResult =
					if (i.eelse == null) null else rewriteSwitchBreaksExpr(i.eelse.expr, getBreakVar, false);

				var hasBreak = thenResult.hasBreak || (elseResult != null && elseResult.hasBreak);
				var newElse =
					if (i.eelse == null) null
					else if (elseResult.expr == i.eelse.expr) i.eelse
					else i.eelse.with(expr = elseResult.expr);
				var newIf =
					if (thenResult.expr == i.ethen && newElse == i.eelse) i
					else i.with(ethen = thenResult.expr, eelse = newElse);
				var newExpr = if (newIf == i) expr else expr.with(kind = TEIf(newIf));
				{expr: newExpr, hasBreak: hasBreak};

			case TETry(t):
				var exprResult = rewriteSwitchBreaksExpr(t.expr, getBreakVar, false);
				var hasBreak = exprResult.hasBreak;
				var catchesChanged = false;
				var newCatches = [];
				for (c in t.catches) {
					var catchResult = rewriteSwitchBreaksExpr(c.expr, getBreakVar, false);
					if (catchResult.hasBreak) hasBreak = true;
					if (catchResult.expr != c.expr) catchesChanged = true;
					newCatches.push(catchResult.expr == c.expr ? c : c.with(expr = catchResult.expr));
				}
				var newTry =
					if (!catchesChanged && exprResult.expr == t.expr) t
					else t.with(expr = exprResult.expr, catches = newCatches);
				var newExpr = if (newTry == t) expr else expr.with(kind = TETry(newTry));
				{expr: newExpr, hasBreak: hasBreak};

			case TECondCompBlock(v, inner):
				var innerResult = rewriteSwitchBreaksExpr(inner, getBreakVar, false);
				var newExpr = if (innerResult.expr == inner) expr else expr.with(kind = TECondCompBlock(v, innerResult.expr));
				{expr: newExpr, hasBreak: innerResult.hasBreak};

			case TEParens(openParen, inner, closeParen):
				var innerResult = rewriteSwitchBreaksExpr(inner, getBreakVar, false);
				var newExpr =
					if (innerResult.expr == inner) expr
					else expr.with(
						kind = TEParens(openParen, innerResult.expr, closeParen),
						type = innerResult.expr.type,
						expectedType = innerResult.expr.expectedType
					);
				{expr: newExpr, hasBreak: innerResult.hasBreak};

			case TEWhile(_) | TEDoWhile(_) | TEFor(_) | TEForIn(_) | TEForEach(_) | TEHaxeFor(_) | TELocalFunction(_) | TESwitch(_):
				{expr: expr, hasBreak: false};

			case _:
				{expr: expr, hasBreak: false};
		}
	}

	function wrapWithBreakGuard(expr:TExpr, breakVar:TVar):TExpr {
		var lead = removeLeadingTrivia(expr);
		return mk(TEIf({
			syntax: {
				keyword: mkIdent("if", lead, [whitespace]),
				openParen: mkOpenParen(),
				closeParen: addTrailingWhitespace(mkCloseParen()),
			},
			econd: mkNotBreakVarExpr(breakVar),
			ethen: expr,
			eelse: null
		}), TTVoid, TTVoid);
	}

	function mkNotBreakVarExpr(breakVar:TVar):TExpr {
		var local = mk(TELocal(mkIdent(breakVar.name), breakVar), TTBoolean, TTBoolean);
		var notToken = new Token(0, TkExclamation, "!", [], []);
		return mk(TEPreUnop(PreNot(notToken), local), TTBoolean, TTBoolean);
	}

	function mkBreakAssignExpr(breakVar:TVar, breakToken:Token):TExpr {
		var nameToken = new Token(
			breakToken.pos,
			TkIdent,
			breakVar.name,
			cloneTrivia(breakToken.leadTrivia),
			cloneTrivia(breakToken.trailTrivia)
		);
		var local = mk(TELocal(nameToken, breakVar), TTBoolean, TTBoolean);
		var value = mk(TELiteral(TLBool(mkIdent("true"))), TTBoolean, TTBoolean);
		return mk(TEBinop(local, OpAssign(mkTokenWithSpaces(TkEquals, "=")), value), TTVoid, TTVoid);
	}

	function mkBreakVarDecl(breakVar:TVar, leadTrivia:Array<Trivia>):TBlockExpr {
		var varToken = mkIdent("var", leadTrivia, [whitespace]);
		var nameToken = mkIdent(breakVar.name);
		return {
			expr: mk(TEVars(VVar(varToken), [{
				syntax: {name: nameToken, type: null},
				v: breakVar,
				init: {
					equalsToken: mkTokenWithSpaces(TkEquals, "="),
					expr: mk(TELiteral(TLBool(mkIdent("false"))), TTBoolean, TTBoolean)
				},
				comma: null
			}]), TTVoid, TTVoid),
			semicolon: mkSemicolon()
		};
	}

	function extractBreakVarLead(trivia:Array<Trivia>):Array<Trivia> {
		var lastNewline:Null<Trivia> = null;
		var indent:Array<Trivia> = [];
		for (item in trivia) {
			switch item.kind {
				case TrNewline:
					lastNewline = item;
					indent = [];
				case TrWhitespace:
					if (lastNewline != null) {
						indent.push(item);
					}
				case TrBlockComment | TrLineComment:
			}
		}

		var result:Array<Trivia> = [];
		if (lastNewline != null) {
			result.push(new Trivia(lastNewline.kind, lastNewline.text));
			for (item in indent) {
				result.push(new Trivia(item.kind, item.text));
			}
			return result;
		}

		for (item in trivia) {
			if (item.kind == TrWhitespace) {
				result.push(new Trivia(item.kind, item.text));
			}
		}
		return result;
	}

	function replaceBlockExprs(target:Array<TBlockExpr>, source:Array<TBlockExpr>) {
		if (target == source) return;
		target.splice(0, target.length);
		for (item in source) {
			target.push(item);
		}
	}

	function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}

	function extractIndent(trivia:Array<Trivia>):Array<Trivia> {
		var result:Array<Trivia> = [];
		var hadOnlyWhitespace = true;
		for (item in trivia) {
			switch item.kind {
				case TrBlockComment | TrLineComment:
					result = [];
					hadOnlyWhitespace = false;
				case TrNewline:
					result = [];
					hadOnlyWhitespace = true;
				case TrWhitespace:
					result.push(item);
			}
		}
		return if (hadOnlyWhitespace) cloneTrivia(result) else [];
	}

	function addIndent(trivia:Array<Trivia>):Array<Trivia> {
		var result = cloneTrivia(trivia);
		var indentUnit = "\t";
		for (i in 0...trivia.length) {
			var item = trivia[trivia.length - 1 - i];
			if (item.kind == TrWhitespace) {
				indentUnit = item.text;
				break;
			}
		}
		result.push(new Trivia(TrWhitespace, indentUnit));
		return result;
	}
}
