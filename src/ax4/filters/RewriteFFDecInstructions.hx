package ax4.filters;

/**
	Emulates the AVM2 instructions that JPEXS FFDec prints as `§§name(...)` when ActionScript cannot
	express them, which code compiled with Haxe uses to iterate the storage of its maps:

	- `§§hasnext(o, i)`, with locals (the hasnext2 instruction, which moves the index register to
	  the next property), is `(i = ASCompat.nextIndex(o, i)) != 0`. hasnext2 also sets the object
	  register to null at the end, which is not emulated (Haxe's code iterates copies).
	- `§§nextname(i, o)` and `§§nextvalue(i, o)` call ASCompat.nextName and nextValue.

	The others stop the conversion.
**/
class RewriteFFDecInstructions extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		// the calls are rewritten before processing their operands, which would report the instruction
		return switch e.kind {
			case TECall({kind: TEBuiltin(_, "§§hasnext")}, {args: [{expr: obj}, {expr: index = {kind: TELocal(_, v)}}]}):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var eMethod = mkBuiltin("ASCompat.nextIndex", TTFun([TTAny, TTInt], TTInt), lead);
				var call = mkCall(eMethod, [processExpr(obj), index.with(kind = TELocal(mkIdent(v.name), v))], TTInt);
				var assign = mk(TEBinop(mk(TELocal(mkIdent(v.name), v), v.type, v.type), OpAssign(mkTokenWithSpaces(TkEquals, "=")), call), TTInt, TTInt);
				var parens = mk(TEParens(mkOpenParen(), assign, mkCloseParen()), TTInt, TTInt);
				var zero = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), TTInt, TTInt);
				mk(TEBinop(parens, OpNotEquals(mkNotEqualsToken()), zero), TTBoolean, e.expectedType);

			case TECall({kind: TEBuiltin(_, name = "§§nextname" | "§§nextvalue")}, {args: [{expr: index}, {expr: obj}]}):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var method = if (name == "§§nextname") "ASCompat.nextName" else "ASCompat.nextValue";
				var eMethod = mkBuiltin(method, TTFun([TTAny, TTInt], TTAny), lead);
				mkCall(eMethod, [processExpr(obj), processExpr(index)], TTAny, trail).with(expectedType = e.expectedType);

			case TEBuiltin(token, name) if (StringTools.startsWith(name, "§§")):
				throwError(token.pos, "Unhandled FFDec instruction " + name);

			case _:
				mapExpr(processExpr, e);
		}
	}
}
