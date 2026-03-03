package ax4.filters;

import ax4.TypedTreeTools;

private typedef AccessInfo = {
	var get:Bool;
	var set:Bool;
}

private typedef AccessFix = {
	var read:Bool;
	var write:Bool;
}

class RewriteAccessorAccess extends AbstractFilter {
	var fixes:Map<TClassOrInterfaceDecl, Map<String, AccessFix>> = new Map();

	override public function run(tree:TypedTree) {
		this.tree = tree;
		buildFixes();
		super.run(tree);
	}

	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TEBinop(a, op = OpAssign(_), b):
				var b2 = processExpr(b);
				var a2 = mapAssignmentTarget(a);
				rewriteAssignment(e, a2, op, b2);

			case TEField(obj, name, token):
				var obj2 = mapFieldObject(obj);
				var e2 = if (obj2 == obj) e else e.with(kind = TEField(obj2, name, token));
				rewriteFieldRead(e2, obj2, name, token);

			case _:
				mapExpr(processExpr, e);
		}
	}

	function rewriteAssignment(orig:TExpr, target:TExpr, op:Binop, value:TExpr):TExpr {
		switch target.kind {
			case TEField(obj, name, token):
				var fix = getFix(obj.type, name);
				if (fix != null && fix.write) {
					var methodName = "set_" + name;
					var methodToken = mkIdent(methodName, token.leadTrivia, token.trailTrivia);
					var eMethod = mk(TEField(obj, methodName, methodToken), TTFunction, TTFunction);
					var lead = removeLeadingTrivia(orig);
					var trail = removeTrailingTrivia(orig);
					var call = mkCall(eMethod, [value], target.type, trail);
					processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), call);
					return call;
				}
			case _:
		}
		return orig.with(kind = TEBinop(target, op, value));
	}

	function rewriteFieldRead(e:TExpr, obj:TFieldObject, name:String, token:Token):TExpr {
		var fix = getFix(obj.type, name);
		if (fix == null || !fix.read) {
			return e;
		}
		var methodName = "get_" + name;
		var methodToken = mkIdent(methodName, token.leadTrivia, token.trailTrivia);
		var eMethod = mk(TEField(obj, methodName, methodToken), TTFunction, TTFunction);
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var call = mkCall(eMethod, [], e.type, trail);
		processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), call);
		return call;
	}

	function mapAssignmentTarget(e:TExpr):TExpr {
		return switch e.kind {
			case TEField(obj, name, token):
				var obj2 = mapFieldObject(obj);
				if (obj2 == obj) e else e.with(kind = TEField(obj2, name, token));
			case _:
				mapExpr(processExpr, e);
		}
	}

	function mapFieldObject(obj:TFieldObject):TFieldObject {
		return switch obj.kind {
			case TOExplicit(dot, e):
				var mapped = processExpr(e);
				if (mapped == e) obj else obj.with(kind = TOExplicit(dot, mapped), type = mapped.type);
			case _:
				obj;
		}
	}

	function buildFixes() {
		fixes = new Map();
		for (pack in tree.packages) {
			for (mod in pack) {
				if (mod.isExtern) continue;
				collectDecl(mod.pack.decl);
				for (decl in mod.privateDecls) {
					collectDecl(decl);
				}
			}
		}
	}

	function collectDecl(decl:TDecl) {
		switch decl.kind {
			case TDClassOrInterface(c):
				switch c.kind {
					case TClass(info) if (info.extend != null):
						var fixMap = computeFixesForClass(c);
						if (fixMap != null) fixes[c] = fixMap;
					case _:
				}
			case _:
		}
	}

	function computeFixesForClass(c:TClassOrInterfaceDecl):Null<Map<String, AccessFix>> {
		var superClass = getSuperClass(c);
		if (superClass == null) return null;

		var superAccess = collectAccessors(superClass, true);
		var selfAccess = collectAccessors(c, false);
		var map:Map<String, AccessFix> = null;

		for (name in selfAccess.keys()) {
			var self = selfAccess[name];
			var sup = superAccess[name];
			if (sup == null) continue;

			var readFix = self.get && sup.set && !sup.get;
			var writeFix = self.set && sup.get && !sup.set;
			if (!readFix && !writeFix) continue;

			if (map == null) map = new Map();
			map[name] = {read: readFix, write: writeFix};
		}
		return map;
	}

	function collectAccessors(c:TClassOrInterfaceDecl, includeSuper:Bool):Map<String, AccessInfo> {
		var map:Map<String, AccessInfo> = new Map();
		var current:Null<TClassOrInterfaceDecl> = c;
		while (current != null) {
			for (member in current.members) {
				switch member {
					case TMField(f) if (!TypedTreeTools.isFieldStatic(f)):
						switch f.kind {
							case TFGetter(a):
								var info = map[a.name];
								if (info == null) {
									map[a.name] = {get: true, set: false};
								} else {
									info.get = true;
								}
							case TFSetter(a):
								var info = map[a.name];
								if (info == null) {
									map[a.name] = {get: false, set: true};
								} else {
									info.set = true;
								}
							case _:
						}
					case _:
				}
			}
			if (!includeSuper) break;
			current = getSuperClass(current);
		}
		return map;
	}

	function getFix(t:TType, name:String):Null<AccessFix> {
		var cls = switch t {
			case TTInst(c): c;
			case _:
				return null;
		};
		var current:Null<TClassOrInterfaceDecl> = cls;
		while (current != null) {
			var map = fixes[current];
			if (map != null) {
				var fix = map[name];
				if (fix != null) return fix;
			}
			current = getSuperClass(current);
		}
		return null;
	}

	static function getSuperClass(c:TClassOrInterfaceDecl):Null<TClassOrInterfaceDecl> {
		return switch c.kind {
			case TClass(info):
				info.extend != null ? info.extend.superClass : null;
			case _:
				null;
		}
	}
}
