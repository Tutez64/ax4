package ax4.filters;

/**
	`catch (e:Error)` becomes `catch (e:Dynamic)`, as outside flash a runtime error, such as a null
	access, is not an `Error`, while AS3 catches them all as errors.

	The body still reads `e` as an `Error`: each read becomes `ASCompat.asError(e)`, which turns any
	other value into an `Error` with its message, so that `e.message`, `e.errorID` or passing `e` where
	an `Error` is expected work on any caught value. `e.message` and `e.name` read as Strings. A rethrow
	(`throw e`) and an assignment to `e` keep the caught value itself.

	It runs before the API filters, which then see these reads.
**/
class RewriteErrorCatch extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TETry(t):
				var changed = false;
				var catches = [for (c in t.catches) {
					if (isCatchErrorType(c.v.type)) {
						changed = true;
						rewriteErrorCatch(c);
					} else {
						c;
					}
				}];
				if (changed) e.with(kind = TETry(t.with(catches = catches))) else e;
			case _:
				e;
		}
	}

	static function rewriteErrorCatch(c:TCatch):TCatch {
		var lead = ParseTree.getSyntaxTypeLeadingTrivia(c.syntax.type.type);
		var trail = ParseTree.getSyntaxTypeTrailingTrivia(c.syntax.type.type);
		var dynamicToken = new Token(0, TkIdent, "Dynamic", lead, trail);
		var caught = c.v;
		var dynamicVar = c.v.with(type = TTAny);
		var errorType = c.v.type;

		function raw(e:TExpr):TExpr {
			return switch e.kind {
				case TELocal(token, v) if (v == caught): e.with(kind = TELocal(token, dynamicVar), type = TTAny);
				case _: e;
			}
		}

		function asError(e:TExpr):TExpr {
			return switch e.kind {
				case TELocal(token, v) if (v == caught):
					var local = e.with(kind = TELocal(new Token(token.pos, token.kind, token.text, [], []), dynamicVar), type = TTAny, expectedType = TTAny);
					var call = mkCall(mkBuiltin("ASCompat.asError", TTFun([TTAny], errorType), token.leadTrivia), [local], errorType, token.trailTrivia);
					call.with(expectedType = e.expectedType);
				case TEField(obj = {kind: TOExplicit(dot, inner = {kind: TELocal(_, v)})}, fieldName = "message" | "name", fieldToken) if (v == caught):
					// declared untyped (*) in AS3, but a String on the converted Error, as the API filters
					// that follow need to know (a RegExp replace on the message)
					var eObj = asError(inner);
					e.with(kind = TEField(obj.with(kind = TOExplicit(dot, eObj), type = eObj.type), fieldName, fieldToken), type = TTString);
				case TEThrow(keyword, value):
					var inner = raw(value);
					if (inner != value) e.with(kind = TEThrow(keyword, inner)) else mapExpr(asError, e);
				case TEBinop(a, op = OpAssign(_), b):
					var target = raw(a);
					if (target != a) e.with(kind = TEBinop(target, op, asError(b))) else mapExpr(asError, e);
				case _:
					mapExpr(asError, e);
			}
		}

		return c.with(
			v = dynamicVar,
			syntax = c.syntax.with(type = c.syntax.type.with(type = TPath({first: dynamicToken, rest: []}))),
			expr = asError(c.expr)
		);
	}

	static function isCatchErrorType(t:TType):Bool {
		return switch t {
			case TTInst(cls):
				if (cls.name != "Error") {
					false;
				} else {
					var packName = if (cls.parentModule == null) "" else cls.parentModule.parentPack.name;
					packName == "flash.errors" || packName == "openfl.errors" || packName == "";
				}
			case _:
				false;
		}
	}
}
