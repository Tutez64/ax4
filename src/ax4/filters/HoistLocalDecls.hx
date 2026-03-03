package ax4.filters;

private typedef DeclInfo = {
	var decl:TVarDecl;
	var kind:VarDeclKind;
}

class HoistLocalDecls extends AbstractFilter {
	var globalHoist:Map<TVar, Bool> = new Map();

	override function processFunction(fun:TFunction) {
		var oldHoist = globalHoist;
		globalHoist = new Map();
		super.processFunction(fun);
		globalHoist = oldHoist;
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBlock(block):
				var updated = hoistBlock(block);
				if (updated == block) e else e.with(kind = TEBlock(updated));

			case TELocalFunction(f):
				var oldHoist = globalHoist;
				globalHoist = new Map();
				if (f.fun.expr != null) {
					f.fun.expr = processExpr(f.fun.expr);
				}
				globalHoist = oldHoist;
				e.with(kind = TELocalFunction(f));

			case _:
				mapExpr(processExpr, e);
		};
	}

	function hoistBlock(block:TBlock):TBlock {
		var directDecls = new Map<TVar, DeclInfo>();
		var allDecls = new Map<TVar, DeclInfo>();
		var declOrder:Array<TVar> = [];
		var nameToVar = new Map<String, TVar>();

		for (blockExpr in block.exprs) {
			switch blockExpr.expr.kind {
				case TEVars(kind, decls):
					for (decl in decls) {
						if (!allDecls.exists(decl.v)) {
							var info = {decl: decl, kind: kind};
							directDecls[decl.v] = info;
							allDecls[decl.v] = info;
							declOrder.push(decl.v);
							if (!nameToVar.exists(decl.v.name)) {
								nameToVar[decl.v.name] = decl.v;
							}
						}
					}
				case _:
					collectNestedDecls(blockExpr.expr, allDecls, declOrder);
			}
		}

		if (declOrder.length == 0) {
			var updatedExprs = mapBlockExprs(processExpr, block.exprs);
			return if (updatedExprs == block.exprs) block else block.with(exprs = updatedExprs);
		}

		var declared = new Map<TVar, Bool>();
		var hoist = new Map<TVar, Bool>();

		// 1. Force hoist for variables declared in nested blocks
		for (v in allDecls.keys()) {
			if (!directDecls.exists(v)) {
				hoist[v] = true;
			}
		}

		// 2. Scan for variables used before declaration in current block
		for (blockExpr in block.exprs) {
			var expr = blockExpr.expr;

			function scan(e:TExpr) {
				switch e.kind {
					case TELocal(_, v):
						if (!declared.exists(v) && allDecls.exists(v)) {
							hoist[v] = true;
						} else if (!declared.exists(v)) {
							var named = nameToVar[v.name];
							if (named != null && !declared.exists(named)) {
								hoist[named] = true;
							}
						}
					case TEField({kind: TOImplicitThis(_) | TOImplicitClass(_)}, fieldName, _):
						var v = nameToVar[fieldName];
						if (v != null && !declared.exists(v)) {
							hoist[v] = true;
						}
					case TEDeclRef(path, _):
						if (path.rest.length == 0) {
							var v = nameToVar[path.first.text];
							if (v != null && !declared.exists(v)) {
								hoist[v] = true;
							}
						}
					case _:
				}
				iterExpr(scan, e);
			}

			scan(expr);

			switch expr.kind {
				case TEVars(_, decls):
					for (decl in decls) {
						declared[decl.v] = true;
					}
				case _:
			}
		}

		var hasHoisted = false;
		for (_ in hoist.keys()) {
			hasHoisted = true;
			break;
		}
		if (!hasHoisted) {
			var updatedExprs = mapBlockExprs(function(e) {
				return processExpr(rewriteVars(e, hoist));
			}, block.exprs);
			return block.with(exprs = updatedExprs);
		}

		// Mark these as globally hoisted so nested blocks don't declare them
		for (v in hoist.keys()) {
			globalHoist[v] = true;
		}

		var hoistedDecls:Array<TVarDecl> = [];
		for (v in declOrder) {
			if (!hoist.exists(v)) continue;
			var info = allDecls[v];
			var nameToken = info.decl.syntax.name.clone();
			nameToken.leadTrivia = [];
			nameToken.trailTrivia = [];
			hoistedDecls.push({
				syntax: {name: nameToken, type: cloneTypeHint(info.decl.syntax.type)},
				v: v,
				init: null,
				comma: null,
			});
		}

		var hoistedExprs:Array<TBlockExpr> = [];
		if (hoistedDecls.length > 0) {
			var leadingTrivia =
				if (block.exprs.length > 0) processLeadingToken(t -> t.leadTrivia.copy(), block.exprs[0].expr) else [];
			var indentTrivia = extractIndent(leadingTrivia);
			var isFirst = true;
			for (decl in hoistedDecls) {
				var lead = isFirst ? leadingTrivia : cloneTrivia(indentTrivia);
				var varToken = mkIdent("var", lead, [whitespace]);
				var hoistDecl = mk(TEVars(VVar(varToken), [decl]), TTVoid, TTVoid);
				hoistedExprs.push({expr: hoistDecl, semicolon: addTrailingNewline(mkSemicolon())});
				isFirst = false;
			}
		}

		var newExprs = mapBlockExprs(function(e) {
			return processExpr(rewriteVars(e, hoist));
		}, block.exprs);

		return block.with(exprs = hoistedExprs.concat(newExprs));
	}

	function collectNestedDecls(e:TExpr, decls:Map<TVar, DeclInfo>, order:Array<TVar>) {
		function walk(expr:TExpr) {
			switch expr.kind {
				case TEVars(kind, varDecls):
					for (decl in varDecls) {
						if (!decls.exists(decl.v)) {
							decls[decl.v] = {decl: decl, kind: kind};
							order.push(decl.v);
						}
						if (decl.init != null) {
							walk(decl.init.expr);
						}
					}
				case TELocalFunction(_):
					return;
				case TEBlock(block):
					for (b in block.exprs) walk(b.expr);
				case TEIf(i):
					walk(i.econd);
					walk(i.ethen);
					if (i.eelse != null) walk(i.eelse.expr);
				case TETry(t):
					walk(t.expr);
					for (c in t.catches) walk(c.expr);
				case TESwitch(s):
					walk(s.subj);
					for (c in s.cases) {
						for (v in c.values) walk(v);
						for (b in c.body) walk(b.expr);
					}
					if (s.def != null) {
						for (b in s.def.body) walk(b.expr);
					}
				case TECall(eobj, args):
					walk(eobj);
					for (arg in args.args) walk(arg.expr);
				case TEArrayDecl(a):
					for (el in a.elements) walk(el.expr);
				case TEVectorDecl(v):
					for (el in v.elements.elements) walk(el.expr);
				case TEArrayAccess(a):
					walk(a.eobj);
					walk(a.eindex);
				case TEObjectDecl(o):
					for (f in o.fields) walk(f.expr);
				case TEReturn(_, e) | TETypeof(_, e) | TEThrow(_, e) | TEDelete(_, e):
					if (e != null) walk(e);
				case TEParens(_, e, _):
					walk(e);
				case TECast(c):
					walk(c.expr);
				case TEField({kind: TOExplicit(_, e)}, _, _):
					walk(e);
				case TETernary(t):
					walk(t.econd);
					walk(t.ethen);
					walk(t.eelse);
				case TEWhile(w):
					walk(w.cond);
					walk(w.body);
				case TEDoWhile(w):
					walk(w.body);
					walk(w.cond);
				case TEHaxeFor(f):
					walk(f.iter);
					walk(f.body);
				case TEFor(f):
					if (f.einit != null) walk(f.einit);
					if (f.econd != null) walk(f.econd);
					if (f.eincr != null) walk(f.eincr);
					walk(f.body);
				case TEForIn(f):
					walk(f.iter.eit);
					walk(f.iter.eobj);
					walk(f.body);
				case TEForEach(f):
					walk(f.iter.eit);
					walk(f.iter.eobj);
					walk(f.body);
				case TEAs(e, _, _):
					walk(e);
				case TENew(_, TNExpr(e), _):
					walk(e);
				case TENew(_, TNType(_), _):
				case TEHaxeRetype(e):
					walk(e);
				case TEHaxeIntIter(start, end):
					walk(start);
					walk(end);
				case TECondCompBlock(_, expr):
					walk(expr);
				case TEXmlChild(x): walk(x.eobj);
				case TEXmlAttr(x): walk(x.eobj);
				case TEXmlAttrExpr(x): walk(x.eobj);
				case TEXmlDescend(x): walk(x.eobj);
				case TEPreUnop(_, e) | TEPostUnop(e, _):
					walk(e);
				case TEBinop(a, _, b):
					walk(a);
					walk(b);
				case TEVector(_) | TELiteral(_) | TEUseNamespace(_) | TELocal(_) | TEBuiltin(_) | TEDeclRef(_) | TEBreak(_) | TEContinue(_) | TECondCompValue(_):
				case _:
			}
		}
		walk(e);
	}

	function rewriteVars(expr:TExpr, hoist:Map<TVar, Bool>):TExpr {
		return switch expr.kind {
			case TEVars(kind, decls):
				var remaining:Array<TVarDecl> = [];
				var assignments:Array<TBlockExpr> = [];
				var lead = removeLeadingTrivia(expr);
				var trail = removeTrailingTrivia(expr);

				for (decl in decls) {
					if (!hoist.exists(decl.v) && !globalHoist.exists(decl.v)) {
						remaining.push(decl);
						continue;
					}
					if (decl.init != null) {
						assignments.push({expr: mkAssign(decl), semicolon: mkSemicolon()});
					}
				}

				var exprs:Array<TBlockExpr> = [];
				if (remaining.length > 0) {
					exprs.push({expr: mk(TEVars(kind, remaining), TTVoid, TTVoid), semicolon: mkSemicolon()});
				}
				exprs = exprs.concat(assignments);

				if (exprs.length == 0) {
					return mkMergedBlock([]);
				}
				if (exprs.length == 1) {
					processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), exprs[0].expr);
					processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), exprs[0].expr);
					return exprs[0].expr;
				}

				processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), exprs[0].expr);
				processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), exprs[exprs.length - 1].expr);
				return mkMergedBlock(exprs);

			case _:
				mapExpr(processExpr, expr);
		}
	}

	function mkAssign(decl:TVarDecl):TExpr {
		var nameToken = decl.syntax.name.clone();
		nameToken.leadTrivia = [];
		nameToken.trailTrivia = [];
		var left = mk(TELocal(nameToken, decl.v), decl.v.type, decl.v.type);
		var assignToken = new Token(0, TkEquals, "=", [whitespace], [whitespace]);
		return mk(TEBinop(left, OpAssign(assignToken), decl.init.expr), decl.v.type, TTVoid);
	}

	function cloneTypeHint(type:Null<TypeHint>):Null<TypeHint> {
		if (type == null) return null;
		return {
			colon: type.colon.clone(),
			type: cloneSyntaxType(type.type)
		};
	}

	function cloneSyntaxType(type:SyntaxType):SyntaxType {
		return switch (type) {
			case TAny(star):
				var cloned = star.clone();
				cloned.trimTrailingWhitespace();
				TAny(cloned);
			case TPath(path):
				var cloned = cloneDotPath(path);
				processDotPathTrailingToken(t -> t.trimTrailingWhitespace(), cloned);
				TPath(cloned);
			case TVector(v):
				var cloned = {
					name: v.name.clone(),
					dot: v.dot.clone(),
					t: {
						lt: v.t.lt.clone(),
						type: cloneSyntaxType(v.t.type),
						gt: v.t.gt.clone(),
					}
				};
				cloned.t.gt.trimTrailingWhitespace();
				TVector(cloned);
		}
	}

	function cloneDotPath(path:DotPath):DotPath {
		return {
			first: path.first.clone(),
			rest: [for (part in path.rest) {sep: part.sep.clone(), element: part.element.clone()}]
		};
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

	function cloneTrivia(trivia:Array<Trivia>):Array<Trivia> {
		return [for (item in trivia) new Trivia(item.kind, item.text)];
	}
}
