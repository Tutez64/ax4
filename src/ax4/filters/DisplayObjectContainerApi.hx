package ax4.filters;

class DisplayObjectContainerApi extends AbstractFilter {
	var displayObjectDecl:Null<TDecl>;
	var displayObjectClass:Null<TClassOrInterfaceDecl>;
	var containerDecl:Null<TDecl>;
	var containerClass:Null<TClassOrInterfaceDecl>;

	override public function run(tree:TypedTree) {
		this.tree = tree;
		displayObjectDecl = try tree.getDecl("flash.display", "DisplayObject") catch (_:Dynamic) null;
		displayObjectClass = switch displayObjectDecl {
			case {kind: TDClassOrInterface(c)}: c;
			case _: null;
		}
		containerDecl = try tree.getDecl("flash.display", "DisplayObjectContainer") catch (_:Dynamic) null;
		containerClass = switch containerDecl {
			case {kind: TDClassOrInterface(c)}: c;
			case _: null;
		}
		super.run(tree);
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEField(obj, fieldName, fieldToken):
				if (!needsContainerCast(obj.type, fieldName)) {
					e;
				} else {
					switch obj.kind {
						case TOExplicit(dot, eobj):
							if (containerClass == null || containerDecl == null) {
								e;
							} else {
								var targetType = TTInst(containerClass);
								var casted = wrapCast(eobj, targetType, containerClass, containerDecl);
								var nextObj:TFieldObject = {type: targetType, kind: TOExplicit(dot, casted)};
								e.with(kind = TEField(nextObj, fieldName, fieldToken));
							}
						case _:
							e;
					}
				}
			case _:
				e;
		}
	}

	function needsContainerCast(t:TType, fieldName:String):Bool {
		if (!isContainerField(fieldName)) return false;
		return switch t {
			case TTInst(c) if (displayObjectClass != null && c == displayObjectClass):
				true;
			case TTAny | TTObject(TTAny):
				true;
			case _:
				false;
		}
	}

	static function isContainerField(fieldName:String):Bool {
		return fieldName == "setChildIndex" || fieldName == "getChildByName" || fieldName == "numChildren";
	}

	function wrapCast(e:TExpr, targetType:TType, targetClass:TClassOrInterfaceDecl, targetDecl:TDecl):TExpr {
		var lead = removeLeadingTrivia(e);
		var trail = removeTrailingTrivia(e);
		var eMethod = mkBuiltin("cast", TTFunction, lead);
		var path = dotPathFromString(targetClass.parentModule.parentPack.name + "." + targetClass.name, []);
		var eType = mkDeclRef(path, targetDecl, null);
		return mk(TECall(eMethod, {
			openParen: mkOpenParen(),
			args: [
				{expr: e, comma: commaWithSpace},
				{expr: eType, comma: null}
			],
			closeParen: mkCloseParen(trail)
		}), targetType, targetType);
	}

	function dotPathFromString(path:String, lead:Array<Trivia>):DotPath {
		var parts = path.split(".");
		var first = mkIdent(parts[0], lead, []);
		var rest = [];
		for (i in 1...parts.length) {
			rest.push({sep: mkDot(), element: mkIdent(parts[i])});
		}
		return {first: first, rest: rest};
	}
}
