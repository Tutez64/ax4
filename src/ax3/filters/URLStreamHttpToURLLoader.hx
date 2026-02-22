package ax3.filters;

class URLStreamHttpToURLLoader extends AbstractFilter {
	var rewriteEnabled = false;
	var urlLoaderDecl:Null<TClassOrInterfaceDecl> = null;

	override public function run(tree:TypedTree) {
		this.tree = tree;
		rewriteEnabled = shouldRewrite(tree);
		if (!rewriteEnabled) {
			return;
		}
		super.run(tree);
	}

	override function processVarField(v:TVarField) {
		v.type = rewriteType(v.type);
		super.processVarField(v);
	}

	override function processSignature(sig:TFunctionSignature) {
		sig = super.processSignature(sig);
		for (arg in sig.args) {
			arg.type = rewriteType(arg.type);
			if (arg.v != null) {
				arg.v.type = arg.type;
			}
		}
		sig.ret.type = rewriteType(sig.ret.type);
		return sig;
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		if (!rewriteEnabled) {
			return e;
		}

		switch e.kind {
			case TELocalFunction(f):
				processFunction(f.fun);

			case TELocal(_, v):
				v.type = rewriteType(v.type);

			case TEVars(_, vars):
				for (v in vars) {
					v.v.type = rewriteType(v.v.type);
				}

			case TENew(keyword, TNType(tref), args):
				var nextType = rewriteType(tref.type);
				if (!Type.enumEq(nextType, tref.type)) {
					e = e.with(kind = TENew(keyword, TNType(tref.with(type = nextType)), args));
				}

			case TECall({kind: TEField({kind: TOExplicit(_, eStream = {type: streamType})}, "readUTFBytes", _)}, args)
				if (isUrlLoaderLikeType(streamType) && args.args.length == 1):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var eReadText = mkBuiltin("ASCompat.urlLoaderReadUTFBytes", TTFunction, lead, []);
				var streamExpr = cloneExpr(eStream);
				removeLeadingTrivia(streamExpr);
				removeTrailingTrivia(streamExpr);
				var lengthExpr = cloneExpr(args.args[0].expr);
				var nextArgs:TCallArgs = {
					openParen: mkOpenParen(),
					args: [
						{expr: streamExpr, comma: commaWithSpace},
						{expr: lengthExpr, comma: null}
					],
					closeParen: mkCloseParen(trail)
				};
				e = mk(TECall(eReadText, nextArgs), TTString, rewriteType(e.expectedType));

			case TEField({kind: TOExplicit(_, eStream = {type: streamType})}, "bytesAvailable", _)
				if (isUrlLoaderLikeType(streamType)):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var eBytesAvailable = mkBuiltin("ASCompat.urlLoaderBytesAvailable", TTFunction, lead, []);
				var streamExpr = cloneExpr(eStream);
				removeLeadingTrivia(streamExpr);
				removeTrailingTrivia(streamExpr);
				e = mk(TECall(eBytesAvailable, {
					openParen: mkOpenParen(),
					args: [{expr: streamExpr, comma: null}],
					closeParen: mkCloseParen(trail)
				}), TTUint, rewriteType(e.expectedType));

			case _:
		}

		e.type = rewriteType(e.type);
		e.expectedType = rewriteType(e.expectedType);
		return e;
	}

	function shouldRewrite(tree:TypedTree):Bool {
		var hasUrlStream = false;
		var safeUsage = true;

		function scanExpr(e:TExpr) {
			switch e.kind {
				case TENew(_, TNType({type: t}), _):
					if (isUrlStreamType(t)) {
						hasUrlStream = true;
					}

				case TEField({kind: TOExplicit(_, eobj = {type: t})}, fieldName, _):
					if (isUrlStreamType(t)) {
						hasUrlStream = true;
						if (!isAllowedUrlStreamField(fieldName)) {
							safeUsage = false;
						}
					}

				case _:
			}
			if (safeUsage) {
				iterExpr(scanExpr, e);
			}
		}

		function scanFunction(fun:TFunction) {
			for (arg in fun.sig.args) {
				if (isUrlStreamType(arg.type)) {
					hasUrlStream = true;
				}
			}
			if (isUrlStreamType(fun.sig.ret.type)) {
				hasUrlStream = true;
			}
			if (fun.expr != null) {
				scanExpr(fun.expr);
			}
		}

		for (pack in tree.packages) {
			for (mod in pack) {
				if (!safeUsage) {
					break;
				}
				switch mod.pack.decl.kind {
					case TDClassOrInterface(c):
						for (member in c.members) {
							switch member {
								case TMField(field):
									switch field.kind {
										case TFVar(v):
											if (isUrlStreamType(v.type)) {
												hasUrlStream = true;
											}
											if (v.init != null) {
												scanExpr(v.init.expr);
											}
										case TFFun(fun):
											scanFunction(fun.fun);
										case TFGetter(accessor):
											scanFunction(accessor.fun);
										case TFSetter(accessor):
											scanFunction(accessor.fun);
									}
								case TMStaticInit(i):
									scanExpr(i.expr);
								case TMUseNamespace(_) | TMCondCompBegin(_) | TMCondCompEnd(_):
							}
						}
					case TDFunction(fun):
						scanFunction(fun.fun);
					case TDVar(v):
						if (isUrlStreamType(v.type)) {
							hasUrlStream = true;
						}
						if (v.init != null) {
							scanExpr(v.init.expr);
						}
					case TDNamespace(_):
				}
			}
		}

		return hasUrlStream && safeUsage && ensureUrlLoaderDecl() != null;
	}

	function isAllowedUrlStreamField(fieldName:String):Bool {
		return switch fieldName {
			case "addEventListener" | "removeEventListener" | "load" | "close" | "readUTFBytes" | "bytesAvailable":
				true;
			case _:
				false;
		}
	}

	function rewriteType(t:TType):TType {
		return switch t {
			case TTInst(cls) if (isUrlStreamClass(cls)):
				var loader = ensureUrlLoaderDecl();
				if (loader == null) t else TTInst(loader);

			case TTStatic(cls) if (isUrlStreamClass(cls)):
				var loader = ensureUrlLoaderDecl();
				if (loader == null) t else TTStatic(loader);

			case TTArray(inner):
				var next = rewriteType(inner);
				if (Type.enumEq(next, inner)) t else TTArray(next);

			case TTVector(inner):
				var next = rewriteType(inner);
				if (Type.enumEq(next, inner)) t else TTVector(next);

			case TTDictionary(k, v):
				var nextK = rewriteType(k);
				var nextV = rewriteType(v);
				if (Type.enumEq(nextK, k) && Type.enumEq(nextV, v)) t else TTDictionary(nextK, nextV);

			case TTObject(inner):
				var next = rewriteType(inner);
				if (Type.enumEq(next, inner)) t else TTObject(next);

			case TTFun(args, ret, rest):
				var changed = false;
				var nextArgs = [for (a in args) {
					var next = rewriteType(a);
					if (!Type.enumEq(next, a)) changed = true;
					next;
				}];
				var nextRet = rewriteType(ret);
				if (!Type.enumEq(nextRet, ret)) changed = true;
				if (!changed) t else TTFun(nextArgs, nextRet, rest);

			case _:
				t;
		}
	}

	function ensureUrlLoaderDecl():Null<TClassOrInterfaceDecl> {
		if (urlLoaderDecl != null) {
			return urlLoaderDecl;
		}
		var candidates = ["flash.net", "openfl.net", ""];
		for (pack in candidates) {
			try {
				urlLoaderDecl = tree.getClassOrInterface(pack, "URLLoader");
				if (urlLoaderDecl != null) {
					return urlLoaderDecl;
				}
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function isUrlStreamType(t:TType):Bool {
		return switch t {
			case TTInst(cls) | TTStatic(cls):
				isUrlStreamClass(cls);
			case _:
				false;
		}
	}

	static function isUrlLoaderLikeType(t:TType):Bool {
		return switch t {
			case TTInst(cls) | TTStatic(cls):
				if (cls == null) {
					false;
				} else {
				var pack = if (cls.parentModule == null || cls.parentModule.parentPack == null) "" else cls.parentModule.parentPack.name;
				(pack == "flash.net" || pack == "openfl.net" || pack == "") && (cls.name == "URLLoader" || cls.name == "URLStream");
				}
			case _:
				false;
		}
	}

	static function isUrlStreamClass(cls:TClassOrInterfaceDecl):Bool {
		if (cls == null) {
			return false;
		}
		var pack = if (cls.parentModule == null || cls.parentModule.parentPack == null) "" else cls.parentModule.parentPack.name;
		return (pack == "flash.net" || pack == "openfl.net" || pack == "") && cls.name == "URLStream";
	}
}
