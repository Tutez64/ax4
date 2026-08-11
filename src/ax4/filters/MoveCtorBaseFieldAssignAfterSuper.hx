package ax4.filters;

class MoveCtorBaseFieldAssignAfterSuper extends AbstractFilter {
	override function processClass(c:TClassOrInterfaceDecl) {
		// When reorderFieldInitsForCtorDeps is on, MoveFieldInits places moved inits
		// after pre-super assigns that they read — keep those assigns before super().
		// Also never move a base-field assign if a later pre-super statement reads it
		// (e.g. mHost = x; mHelper = new Helper(mHost); super()).
		var fieldInitDeps = reorderFieldInitsForCtorDepsEnabled()
			? collectFieldInitDeps(c)
			: new Map<String, Bool>();

		for (m in c.members) {
			switch (m) {
				case TMField({kind: TFFun(f)}) if (isCtorName(f.name, c.name)):
					if (f.fun.expr != null) {
						f.fun.expr = moveBaseAssignsAfterSuper(f.fun.expr, c, fieldInitDeps);
					}
					break;
				case _:
			}
		}
	}

	inline function reorderFieldInitsForCtorDepsEnabled():Bool {
		return context.config.settings != null && context.config.settings.reorderFieldInitsForCtorDeps == true;
	}

	static inline function isCtorName(name:String, className:String):Bool {
		return name == "new" || name == className;
	}

	/**
	 * Collect field names that are used in instance field initializations.
	 * These are fields declared in this class that have initializers using other fields.
	 */
	function collectFieldInitDeps(c:TClassOrInterfaceDecl):Map<String, Bool> {
		var deps = new Map<String, Bool>();
		for (m in c.members) {
			switch m {
				case TMField(field):
					switch field.kind {
						case TFVar(v) if (v.init != null):
							collectFieldReads(v.init.expr, deps);
						case _:
					}
				case _:
			}
		}
		return deps;
	}

	function collectFieldReads(e:TExpr, deps:Map<String, Bool>):Void {
		switch e.kind {
			case TEField(obj, name, _) if (isThisObject(obj)):
				deps[name] = true;
			case _:
				iterExpr(e2 -> collectFieldReads(e2, deps), e);
		}
	}

	function moveBaseAssignsAfterSuper(e:TExpr, currentClass:TClassOrInterfaceDecl, fieldInitDeps:Map<String, Bool>):TExpr {
		return switch e.kind {
			case TEBlock(block):
				var superIndex = -1;
				for (i in 0...block.exprs.length) {
					if (isSuperCall(block.exprs[i].expr)) {
						superIndex = i;
						break;
					}
				}
				if (superIndex <= 0) {
					e;
				} else {
					var before = block.exprs.slice(0, superIndex);
					var after = block.exprs.slice(superIndex + 1);
					var keepBefore:Array<TBlockExpr> = [];
					var moveAfter:Array<TBlockExpr> = [];
					var lastNonSimpleIndex = -1;
					for (i in 0...before.length) {
						if (!isSimpleExpr(before[i].expr)) {
							lastNonSimpleIndex = i;
						}
					}
					for (i in 0...before.length) {
						var expr = before[i];
						var fieldName = getBaseFieldAssignName(expr.expr, currentClass);
						if (i > lastNonSimpleIndex && fieldName != null
							&& !fieldInitDeps.exists(fieldName)
							&& !isFieldReadInRange(before, i + 1, fieldName)) {
							moveAfter.push(expr);
						} else {
							keepBefore.push(expr);
						}
					}
					if (moveAfter.length == 0) {
						e;
					} else {
						var newExprs = keepBefore
							.concat([block.exprs[superIndex]])
							.concat(moveAfter)
							.concat(after);
						e.with(kind = TEBlock(block.with(exprs = newExprs)));
					}
				}
			case _:
				e;
		}
	}

	static function isSimpleExpr(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): isSimpleExpr(inner);
			case TEVars(_, _): true;
			case TEBinop(_, OpAssign(_), _): true;
			case _: false;
		}
	}

	static function isSuperCall(e:TExpr):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): isSuperCall(inner);
			case TECall({kind: TELiteral(TLSuper(_))}, _): true;
			case _: false;
		}
	}

	/**
	 * If `e` assigns an inherited instance field, return that field name; else null.
	 */
	function getBaseFieldAssignName(e:TExpr, currentClass:TClassOrInterfaceDecl):Null<String> {
		return switch e.kind {
			case TEParens(_, inner, _): getBaseFieldAssignName(inner, currentClass);
			case TEBinop(left, OpAssign(_), _):
				switch left.kind {
					case TEField(obj, name, _) if (isThisObject(obj)):
						var found = currentClass.findFieldInHierarchy(name, false);
						if (found != null && found.declaringClass != currentClass) {
							name;
						} else {
							null;
						}
					case _:
						null;
				}
			case _:
				null;
		}
	}

	function isFieldReadInRange(exprs:Array<TBlockExpr>, start:Int, fieldName:String):Bool {
		for (i in start...exprs.length) {
			if (exprReadsField(exprs[i].expr, fieldName)) {
				return true;
			}
		}
		return false;
	}

	function exprReadsField(e:TExpr, fieldName:String):Bool {
		return switch e.kind {
			case TEField(obj, name, _) if (name == fieldName && isThisObject(obj)):
				true;
			case TEBinop(left, OpAssign(_), right):
				// RHS (and nested) may read the field; LHS of the assign is a write.
				exprReadsField(right, fieldName) || switch left.kind {
					case TEField(_, _, _): false;
					case _: exprReadsField(left, fieldName);
				};
			case _:
				var found = false;
				iterExpr(function(inner) {
					if (!found && exprReadsField(inner, fieldName)) {
						found = true;
					}
				}, e);
				found;
		}
	}

	static inline function isThisObject(obj:TFieldObject):Bool {
		return switch obj.kind {
			case TOImplicitThis(_): true;
			case TOExplicit(_, {kind: TELiteral(TLThis(_) | TLSuper(_))}): true;
			case _:
				false;
		}
	}
}
