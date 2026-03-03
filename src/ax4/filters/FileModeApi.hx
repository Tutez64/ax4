package ax4.filters;

class FileModeApi extends AbstractFilter {
	var fileModeDecl:Null<TDecl>;
	var fileModeClass:Null<TClassOrInterfaceDecl>;

	override public function run(tree:TypedTree) {
		this.tree = tree;
		fileModeDecl = try tree.getDecl("flash.filesystem", "FileMode") catch (_:Dynamic) null;
		fileModeClass = switch fileModeDecl {
			case {kind: TDClassOrInterface(c)}: c;
			case _: null;
		}
		super.run(tree);
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		if (fileModeClass == null) return e;
		return switch e.kind {
			case TECall(eobj, args):
				if (!isFileStreamCall(eobj) || args.args.length < 2) {
					e;
				} else {
					var arg = args.args[1];
					var modeName = extractFileMode(arg.expr);
					if (modeName == null) {
						e;
					} else {
						var nextExpr = mkFileModeExpr(modeName, arg.expr);
						var nextArgs = args.args.copy();
						nextArgs[1] = {expr: nextExpr, comma: arg.comma};
						e.with(kind = TECall(eobj, args.with(args = nextArgs)));
					}
				}
			case _:
				e;
		}
	}

	function isFileStreamCall(eobj:TExpr):Bool {
		return switch eobj.kind {
			case TEField(obj, name, _):
				(name == "open" || name == "openAsync") && isFileStreamType(obj.type);
			case _:
				false;
		}
	}

	function isFileStreamType(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				cls.name == "FileStream" && cls.parentModule.parentPack.name == "flash.filesystem";
			case _:
				false;
		}
	}

	function extractFileMode(e:TExpr):Null<String> {
		return switch e.kind {
			case TELiteral(TLString(t)):
				var value = t.text;
				// strip quotes if present
				if (value.length >= 2 && (value.charAt(0) == "\"" || value.charAt(0) == "'")) {
					value = value.substr(1, value.length - 2);
				}
				switch value.toLowerCase() {
					case "read": "READ";
					case "write": "WRITE";
					case "append": "APPEND";
					case "update": "UPDATE";
					case _: null;
				}
			case _:
				null;
		}
	}

	function mkFileModeExpr(modeName:String, original:TExpr):TExpr {
		var lead = removeLeadingTrivia(original);
		var trail = removeTrailingTrivia(original);

		var path:DotPath = {
			first: mkIdent("flash"),
			rest: [
				{sep: mkDot(), element: mkIdent("filesystem")},
				{sep: mkDot(), element: mkIdent("FileMode")}
			]
		};
		var declRef = mkDeclRef(path, (fileModeDecl:TDecl), null);
		var obj:TFieldObject = {type: declRef.type, kind: TOExplicit(mkDot(), declRef)};
		var fieldExpr = mk(TEField(obj, modeName, mkIdent(modeName)), TTInst(fileModeClass), TTInst(fileModeClass));
		processLeadingToken(t -> t.leadTrivia = lead.concat(t.leadTrivia), fieldExpr);
		processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), fieldExpr);
		return fieldExpr;
	}
}
