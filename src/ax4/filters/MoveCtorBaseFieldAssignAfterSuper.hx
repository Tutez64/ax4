package ax4.filters;

class MoveCtorBaseFieldAssignAfterSuper extends AbstractFilter {
	override function processClass(c:TClassOrInterfaceDecl) {
		// Collect field dependencies from instance field initializations in this class
		// These fields will be moved to the constructor by MoveFieldInits,
		// so we need to know if they depend on base class fields
		var fieldInitDeps = collectFieldInitDeps(c);

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
							collectDepsFromExpr(v.init.expr, deps);
						case _:
					}
				case _:
			}
		}
		return deps;
	}

	function collectDepsFromExpr(e:TExpr, deps:Map<String, Bool>):Void {
		switch e.kind {
			case TEField(obj, name, _) if (isThisObject(obj)):
				deps[name] = true;
			case _:
				iterExpr(e2 -> collectDepsFromExpr(e2, deps), e);
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
						if (i > lastNonSimpleIndex && isAssignToBaseField(expr.expr, currentClass, fieldInitDeps)) {
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
	 * Check if an expression is an assignment to a base class field.
	 * Returns true only if the field is inherited AND not needed by child class field initializations.
	 */
	function isAssignToBaseField(e:TExpr, currentClass:TClassOrInterfaceDecl, fieldInitDeps:Map<String, Bool>):Bool {
		return switch e.kind {
			case TEParens(_, inner, _): isAssignToBaseField(inner, currentClass, fieldInitDeps);
			case TEBinop(left, OpAssign(_), _):
				switch left.kind {
					case TEField(obj, name, _) if (isThisObject(obj)):
						var found = currentClass.findFieldInHierarchy(name, false);
						// It's a base field if it's declared in a parent class
						if (found != null && found.declaringClass != currentClass) {
							// BUT don't move it if child class field initializations depend on it
							!fieldInitDeps.exists(name);
						} else {
							false;
						}
					case _:
						false;
				}
			case _:
				false;
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
