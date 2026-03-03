package ax4.filters;

import ax4.ParseTree.Binop;

class DateApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		return switch e.kind {
			case TECall(eobj = {kind: TEField({kind: TOExplicit(_, eDate = {type: TTInst({name: "Date", parentModule: {parentPack: {name: ""}}})})}, fieldName, fieldToken)}, args):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var dateExpr = processExpr(eDate);
				if (lead.length == 0) lead = removeLeadingTrivia(dateExpr) else removeLeadingTrivia(dateExpr);
				removeTrailingTrivia(dateExpr);
				args = mapCallArgs(processExpr, args);
				switch fieldName {
					case "setTime"
					   | "setFullYear"
					   | "setMonth"
					   | "setDate"
					   | "setHours"
					   | "setMinutes"
					   | "setSeconds"
					   | "setMilliseconds"
					   | "getMilliseconds"
					   | "getUTCMilliseconds"
					   :
						var eMethod = mkBuiltin("ASCompat.ASDate." + fieldName, TTFunction, lead);
						var newArgs = if (args == null) {
							{openParen: mkOpenParen(), args: [{expr: dateExpr, comma: null}], closeParen: mkCloseParen(trail)}
						} else if (args.args.length == 0) {
							var updatedArgs = args.with(args = [{expr: dateExpr, comma: null}]);
							updatedArgs.closeParen.trailTrivia = trail;
							updatedArgs;
						} else {
							var updatedArgs = args.with(args = [{expr: dateExpr, comma: commaWithSpace}].concat(args.args));
							updatedArgs.closeParen.trailTrivia = trail;
							updatedArgs;
						}
						e.with(kind = TECall(eMethod, newArgs));
					case _:
						mapExpr(processExpr, e);
				}

			case TECall(eobj = {kind: TEField({kind: TOExplicit(_, eDate = {type: TTStatic({name: "Date", parentModule: {parentPack: {name: ""}}})})}, fieldName, fieldToken)}, args) if (fieldName == "UTC"):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var dateExpr = processExpr(eDate);
				if (lead.length == 0) lead = removeLeadingTrivia(dateExpr) else removeLeadingTrivia(dateExpr);
				removeTrailingTrivia(dateExpr);
				args = mapCallArgs(processExpr, args);
				var eMethod = mkBuiltin("ASCompat.ASDate.UTC", TTFunction, lead);
				var newArgs = if (args == null) {
					{openParen: mkOpenParen(), args: [], closeParen: mkCloseParen(trail)};
				} else {
					args.closeParen.trailTrivia = trail;
					args;
				}
				e.with(kind = TECall(eMethod, newArgs));

			case TENew(keyword, TNType(ref = {type: TTInst(dateCls = {name: "Date", parentModule: {parentPack: {name: ""}}})}), args):
				args = mapCallArgs(processExpr, args);
				switch args {
					case null | {args: []}: // no arg ctor: rewrite to Date.now()
						var tDate = TTStatic(dateCls);
						var eDate = mk(TEDeclRef(switch ref.syntax { case TPath(p): p; case _: throw "assert";}, {name: "Date", kind: TDClassOrInterface(dateCls)}), tDate, tDate);

						processLeadingToken(t -> t.leadTrivia = t.leadTrivia.concat(keyword.leadTrivia), eDate);

						if (args == null) args = {
							openParen: mkOpenParen(),
							args: [],
							closeParen: mkCloseParen(removeTrailingTrivia(e))
						}
						var eNowField = mk(TEField({kind: TOExplicit(mkDot(), eDate), type: tDate}, "now", mkIdent("now")), TTFunction, TTFunction);
						e.with(kind = TECall(eNowField, args));

					case {args: [arg]}: // single-arg - rewrite to Date.fromTime(arg)
						var tDate = TTStatic(dateCls);
						var eDate = mk(TEDeclRef(switch ref.syntax { case TPath(p): p; case _: throw "assert";}, {name: "Date", kind: TDClassOrInterface(dateCls)}), tDate, tDate);

						processLeadingToken(t -> t.leadTrivia = t.leadTrivia.concat(keyword.leadTrivia), eDate);
						var efromTimeMethod = mk(TEField({kind: TOExplicit(mkDot(), eDate), type: tDate}, "fromTime", mkIdent("fromTime")), TTFunction, TTFunction);

						switch arg.expr.type {
							case TTInst(cls) if (cls == dateCls):
								// rewrite `new Date(otherDate)` to `Date.fromTime(otherDate.getTime())`
								var eGetTimeMethod = mk(TEField({kind: TOExplicit(mkDot(), arg.expr), type: arg.expr.type}, "getTime", mkIdent("getTime")), TTFunction, TTFunction);
								arg.expr = mk(TECall(eGetTimeMethod, {openParen: mkOpenParen(), args: [], closeParen: mkCloseParen()}), TTNumber, TTNumber);

							case TTInt | TTUint | TTNumber:
								// exactly what we want

							case other:
								// other types can break stuff, report, but continue
								reportError(exprPos(arg.expr), "Unknown parameter type for the Date constructor: " + other);
						}

						e.with(kind = TECall(efromTimeMethod, args));

					case _:
						e;
				}

			case TEBinop({kind: TEField({kind: TOExplicit(dot, eDate = {type: TTInst({name: "Date", parentModule: {parentPack: {name: ""}}})})}, fieldName, fieldToken)}, op = OpAssign(_) | OpAssignOp(_), expr):
				if (e.expectedType != TTVoid) {
					// this is annoying, because these `set*` methods return a timestamp instead of the passed value,
					// so we'll have to handle this specifically if we have a codebase that depends on this
					throwError(exprPos(e), "Using Date property assignments as values are not yet implemented");
				}

				eDate = processExpr(eDate);
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				if (lead.length == 0) lead = removeLeadingTrivia(eDate) else removeLeadingTrivia(eDate);
				removeTrailingTrivia(eDate);
				expr = processExpr(expr);

				switch op {
					case OpAssignOp(aop):
						if (!canBeRepeated(eDate)) throwError(exprPos(eDate), "Assign-op on complex Date expressions are not supported");
						var newOp:Binop = switch aop {
							case AOpAdd(t): OpAdd(t.with(TkPlus, "+"));
							case AOpSub(t): OpSub(t.with(TkMinus, "-"));
							case AOpMul(t): OpMul(t.with(TkAsterisk, "*"));
							case AOpDiv(t): OpDiv(t.with(TkSlash, "/"));
							case AOpMod(t): OpMod(t.with(TkPercent, "%"));
							case AOpBitAnd(t): OpBitAnd(t.with(TkAmpersand, "&"));
							case AOpBitOr(t): OpBitOr(t.with(TkPipe, "|"));
							case AOpBitXor(t): OpBitXor(t.with(TkCaret, "^"));
							case AOpShl(t): OpShl(t.with(TkLtLt, "<<"));
							case AOpShr(t): OpShr(t.with(TkGtGt, ">>"));
							case AOpUshr(t): OpUshr(t.with(TkGtGtGt, ">>>"));
							case AOpAnd(t) | AOpOr(t):
								throwError(t.pos, "Unsupported operation on Date properties");
						}
						var clonedDate = cloneExpr(eDate);
						removeLeadingTrivia(clonedDate);
						removeTrailingTrivia(clonedDate);
						var getterCall = if (fieldName == "milliseconds") {
							var eMethod = mkBuiltin("ASCompat.ASDate.getMilliseconds", TTFunction);
							e.with(kind = TECall(eMethod, {openParen: mkOpenParen(), args: [{expr: clonedDate, comma: null}], closeParen: mkCloseParen()}));
						} else {
							var methodName = "get" + fieldName.charAt(0).toUpperCase() + fieldName.substring(1);
							var eMethod = mk(TEField({kind: TOExplicit(mkDot(), clonedDate), type: eDate.type}, methodName, mkIdent(methodName)), TTFunction, TTFunction);
							e.with(kind = TECall(eMethod, {openParen: mkOpenParen(), args: [], closeParen: mkCloseParen()}));
						}
						expr = expr.with(kind = TEBinop(getterCall, newOp, expr));
					case _:
				}

				var to = {kind: TOExplicit(dot, eDate), type: eDate.type};
				switch fieldName {
					case "date"
					   | "fullYear"
					   | "hours"
					   | "milliseconds"
					   | "minutes"
					   | "month"
					   | "seconds"
					   | "time"
					   :
						var methodName = "set" + fieldName.charAt(0).toUpperCase() + fieldName.substring(1);
						var eMethod = mkBuiltin("ASCompat.ASDate." + methodName, TTFunction, lead);
						e.with(kind = TECall(eMethod, {
							openParen: mkOpenParen(),
							args: [{expr: eDate, comma: commaWithSpace}, {expr: expr, comma: null}],
							closeParen: mkCloseParen(trail)
						}));

					case _:
						e;
				}

			case TEField({kind: TOExplicit(dot, eDate = {type: TTInst({name: "Date", parentModule: {parentPack: {name: ""}}})})}, fieldName, fieldToken):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				var dateExpr = processExpr(eDate);
				if (lead.length == 0) lead = removeLeadingTrivia(dateExpr) else removeLeadingTrivia(dateExpr);
				removeTrailingTrivia(dateExpr);
				var to = {kind: TOExplicit(dot, dateExpr), type: eDate.type};
				switch fieldName {
					case "date"
					   | "day"
					   | "fullYear"
					   | "hours"
					   | "minutes"
					   | "month"
					   | "seconds"
					   | "time"
					   | "timezoneOffset"
					   :
						var methodName = "get" + fieldName.charAt(0).toUpperCase() + fieldName.substring(1);
						var eMethod = mk(TEField(to, methodName, mkIdent(methodName, lead)), TTFunction, TTFunction);
						e.with(kind = TECall(eMethod, {
							openParen: mkOpenParen(),
							args: [],
							closeParen: mkCloseParen(trail)
						}));

					case "milliseconds":
						var eMethod = mkBuiltin("ASCompat.ASDate.getMilliseconds", TTFunction, lead);
						e.with(kind = TECall(eMethod, {
							openParen: mkOpenParen(),
							args: [{expr: dateExpr, comma: null}],
							closeParen: mkCloseParen(trail)
						}));

					case "valueOf":
						e.with(kind = TEField(to, "getTime", new Token(fieldToken.pos, TkIdent, "getTime", fieldToken.leadTrivia, fieldToken.trailTrivia)));

					case "dateUTC":
						var methodName = "getUTCDate";
						var eMethod = mk(TEField(to, methodName, mkIdent(methodName, lead)), TTFunction, TTFunction);
						e.with(kind = TECall(eMethod, {
							openParen: mkOpenParen(),
							args: [],
							closeParen: mkCloseParen(trail)
						}));

					case _:
						mapExpr(processExpr, e);
				}

			case _:
				mapExpr(processExpr, e);
		}
	}
}
