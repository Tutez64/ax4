package ax4.filters;

class ArrayApi extends AbstractFilter {
	static final tResize = TTFun([TTInt], TTVoid);
	static final tSortOn = TTFun([TTArray(TTAny), TTAny, TTAny], TTArray(TTAny));
	static final tInsert = TTFun([TTInt, TTAny], TTVoid);
	static final eReflectCompare = mkBuiltin("Reflect.compare", TTFun([TTAny, TTAny], TTInt));

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			// slice with no args (Array/Vector) -> slice(0)
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eArray = {type: TTArray(_) | TTVector(_)})}, "slice", _)}, args) if (args.args.length == 0):
				var zeroExpr = mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt);
				var newArgs = args.with(args = [{expr: zeroExpr, comma: null}]);
				e.with(kind = TECall(mk(TEField(fieldObj, "slice", mkIdent("slice")), TTFunction, TTFunction), newArgs));

			// reverse (Array/Vector)
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_) | TTVector(_)})}, "reverse", _)}, args) if (args.args.length == 0):
				var isVector = eArray.type.match(TTVector(_));
				var compatName = if (isVector) "ASCompat.ASVector" else "ASCompat.ASArray";
				var eCompat = mkBuiltin(compatName, TTBuiltin, removeLeadingTrivia(eArray));
				var fieldObj = {kind: TOExplicit(mkDot(), eCompat), type: eCompat.type};
				var eMethod = mk(TEField(fieldObj, "reverse", mkIdent("reverse")), TTFunction, TTFunction);
				e.with(kind = TECall(eMethod, args.with(args = [{expr: eArray, comma: null}])));

			// Array.some -> ASCompat.ASArray.some
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "some", _)}, args):
				var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
				var fieldObj = {kind: TOExplicit(mkDot(), eCompatArray), type: eCompatArray.type};
				var eMethod = mk(TEField(fieldObj, "some", mkIdent("some")), TTFunction, TTFunction);
				e.with(kind = TECall(eMethod, args.with(args = [{expr: eArray, comma: commaWithSpace}].concat(args.args))));

			// Array.map / Vector.map -> compat (preserve AS3 callback signature + thisArg)
			case TECall({kind: TEField({kind: TOExplicit(dot, eArr = {type: TTArray(_) | TTVector(_)})}, "map", _)}, args):
				var isVector = eArr.type.match(TTVector(_));
				var compatName = if (isVector) "ASCompat.ASVector" else "ASCompat.ASArray";
				var eCompat = mkBuiltin(compatName, TTBuiltin, removeLeadingTrivia(eArr));
				var fieldObj = {kind: TOExplicit(mkDot(), eCompat), type: eCompat.type};
				var methodName = switch args.args {
					case [eCallback, _] | [eCallback]:
						switch eCallback.expr.type {
							case TTFun(_, TTVoid, _): "forEach";
							case _: "map";
						}
					case _: "map";
				}
				var eMethod = mk(TEField(fieldObj, methodName, mkIdent(methodName)), TTFunction, TTFunction);
				e.with(kind = TECall(eMethod, args.with(args = [{expr: eArr, comma: commaWithSpace}].concat(args.args))));

			// sort constants
			case TEField({kind: TOExplicit(dot, {kind: TEBuiltin(arrayToken, "Array")})}, fieldName = "CASEINSENSITIVE" | "DESCENDING" | "NUMERIC" | "RETURNINDEXEDARRAY" | "UNIQUESORT", fieldToken):
				var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, arrayToken.leadTrivia, arrayToken.trailTrivia);
				var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: TTBuiltin};
				e.with(kind = TEField(fieldObj, fieldName, fieldToken));

			// sortOn
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "sortOn", fieldToken)}, args):
				switch args.args {
					case [eFieldName = {expr: {type: TTString | TTArray(_) | TTAny | TTObject(TTAny)}}, eOptions = {expr: {type: TTInt | TTUint | TTArray(_) | TTAny | TTObject(TTAny)}}]:
						var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
						var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: eCompatArray.type};
						var eMethod = mk(TEField(fieldObj, "sortOn", fieldToken), tSortOn, tSortOn);
						e.with(kind = TECall(eMethod, args.with(args = [
							{expr: eArray, comma: commaWithSpace}, eFieldName, eOptions
						])));
					case [eFieldName = {expr: {type: TTString | TTArray(_) | TTAny | TTObject(TTAny)}}]:
						var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
						var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: eCompatArray.type};
						var eMethod = mk(TEField(fieldObj, "sortOn", fieldToken), tSortOn, tSortOn);
						var trail = removeTrailingTrivia(eFieldName.expr);
						var eDefaultOptions = {
							expr: mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], trail))), TTInt, TTInt),
							comma: null
						};
						var eFieldNameArg = {expr: eFieldName.expr, comma: commaWithSpace};
						e.with(kind = TECall(eMethod, args.with(args = [
							{expr: eArray, comma: commaWithSpace}, eFieldNameArg, eDefaultOptions
						])));
					case _:
						throwError(exprPos(e), "Unsupported Array.sortOn arguments");
				}

			// Vector/Array.sort
			case TECall(obj = {kind: TEField({kind: TOExplicit(dot, eVector = {type: TTVector(_) | TTArray(_)})}, "sort", _)}, args):
				// TODO: refactor this a bit, too much duplication here
				var kind = if (eVector.type.match(TTVector(_))) "Vector" else "Array";
				switch args.args {
					case [] if (kind == "Array"):
						var reflectCompareArg = {expr: eReflectCompare, comma: null};
						if (e.expectedType != TTVoid) {
							var eCompatVector = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eVector));
							e.with(kind = TECall(
								mk(TEField({kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type}, "sort", mkIdent("sort")), TTFunction, TTFunction),
								args.with(args = [{expr: eVector, comma: commaWithSpace}, reflectCompareArg])
							));
						} else {
							e.with(kind = TECall(obj, args.with(args = [reflectCompareArg])));
						}

					case [{expr: {type: TTFunction | TTFun(_)}}]:
						// Always route through compat to allow comparator return values that are not Int.
						var eCompatVector = mkBuiltin("ASCompat.AS" + kind, TTBuiltin, removeLeadingTrivia(eVector));
						e.with(kind = TECall(
							mk(TEField({kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type}, "sort", mkIdent("sort")), TTFunction, TTFunction),
							args.with(args = [{expr: eVector, comma: commaWithSpace}, args.args[0]])
						));

					case [eOptions = {expr: {type: TTInt | TTUint}}]:
						var eCompatVector = mkBuiltin("ASCompat.AS" + kind, TTBuiltin, removeLeadingTrivia(eVector));
						e.with(kind = TECall(
							mk(TEField({kind: TOExplicit(dot, eCompatVector), type: eCompatVector.type}, "sortWithOptions", mkIdent("sortWithOptions")), TTFunction, TTFunction),
							args.with(args = [
								{expr: eVector, comma: commaWithSpace},
								eOptions
							])
						));

					case _:
						throwError(exprPos(e), 'Unsupported $kind.sort arguments');
				}

			case TECall(eConcatMethod = {kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_)})}, "concat", fieldToken)}, args):
				switch args.args {
					case []: // concat with no args is just a copy
						var fieldObj = {kind: TOExplicit(dot, eArray), type: eArray.type};
						var eMethod = mk(TEField(fieldObj, "copy", mkIdent("copy", fieldToken.leadTrivia, fieldToken.trailTrivia)), eArray.type, eArray.type);
						e.with(kind = TECall(eMethod, args));

					case [{expr: {type: TTArray(_)}}]:
						// concat with another array - same behaviour as Haxe
						e;

					case [nonArray] if (!nonArray.expr.type.match(TTAny | TTObject(TTAny))):
						// concat with non-array is like a push, that creates a new array instead of mutating the old one
						// Haxe doesn't have this, but we can rewrite it to `a.concat([b])`
						var eArrayDecl = mk(TEArrayDecl({
							syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
							elements: [nonArray]
						}), TTArray(nonArray.expr.type), eArray.type);
						e.with(kind = TECall(eConcatMethod, args.with(args = [{expr: eArrayDecl, comma: null}])));

					case _:
						reportError(exprPos(e), "Unhandled Array.concat() call (possibly untyped?). Leaving as is.");
						e;
				}

			// join with no args
			case TECall(eMethod = {kind: TEField({type: TTArray(_)}, "join", fieldToken)}, args = {args: []}):
				e.with(kind = TECall(eMethod, args.with(args = [
					{expr: mk(TELiteral(TLString(mkString(','))), TTString, TTString), comma: null}
				])));

			// push with multiple arguments
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_) | TTVector(_)})}, methodName = "push" | "unshift", fieldToken)}, args) if (args.args.length > 1):
				var eCompatArray = mkBuiltin("ASCompat.ASArray", TTBuiltin, removeLeadingTrivia(eArray));
				var fieldObj = {kind: TOExplicit(dot, eCompatArray), type: eCompatArray.type};
				var eMethod = mk(TEField(fieldObj, methodName + "Multiple", fieldToken), TTFunction, TTFunction);
				e.with(kind = TECall(eMethod, args.with(args = [{expr: eArray, comma: commaWithSpace}].concat(args.args))));

			// push/unshift with no arguments -> no-op, return length
			case TECall({kind: TEField({kind: TOExplicit(dot, eArray = {type: TTArray(_) | TTVector(_)})}, methodName = "push" | "unshift", _)}, args) if (args.args.length == 0):
				var lead = removeLeadingTrivia(e);
				var trail = removeTrailingTrivia(e);
				// normalize trivia so we don't end up with indentation between object and `.length`
				processLeadingToken(t -> t.leadTrivia = lead, eArray);
				processTrailingToken(t -> t.trailTrivia = [], eArray);
				var fieldObj = {kind: TOExplicit(mkDot(), eArray), type: eArray.type};
				var eLength = mk(TEField(fieldObj, "length", mkIdent("length")), TTInt, TTInt);
				processTrailingToken(t -> t.trailTrivia = t.trailTrivia.concat(trail), eLength);
				eLength;

			// set length
			case TEBinop({kind: TEField(to = {kind: TOExplicit(dot, eArray), type: TTArray(_)}, "length", _)}, op = OpAssign(_), eNewLength):
				if (e.expectedType == TTVoid) {
					// block-level length assignment - safe to just call Haxe's "resize" method
					e.with(
						kind = TECall(
							mk(TEField(to, "resize", mkIdent("resize")), tResize, tResize),
							{
								openParen: mkOpenParen(),
								closeParen: mkCloseParen(),
								args: [{expr: eNewLength, comma: null}]
							}
						)
					);
				} else {
					// possibly value-level length assignment - need to call compat method
					var eCompatMethod = mkBuiltin("ASCompat.arraySetLength", TTFunction, removeLeadingTrivia(eArray), []);
					e.with(kind = TECall(eCompatMethod, {
						openParen: mkOpenParen(),
						closeParen: mkCloseParen(),
						args: [
							{expr: eArray, comma: commaWithSpace},
							{expr: eNewLength, comma: null}
						]
					}));
				}

			// insertAt
			case TECall(eInsertAtMethod = {kind: TEField(fieldObj = {type: TTArray(_)}, "insertAt", insertAtToken)}, args):
				var insertToken = insertAtToken.with(TkIdent, "insert");
				var eInsertMethod = eInsertAtMethod.with(kind = TEField(fieldObj, "insert", insertToken));
				e.with(kind = TECall(eInsertMethod, args));

			// splice
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eArray), type: t = TTArray(_) | TTVector(_)}, "splice", _)}, args):
				var isVector = t.match(TTVector(_));
				var methodNamePrefix = if (isVector) "vector" else "array";

				switch args.args {
					case [eIndex, {expr: {kind: TELiteral(TLInt({text: "0"}))}}, eInserted]:
						// this is a special case that we want to rewrite to a nice `array.insert(pos, elem)`
						// but only if the value is not used (because `insert` returns Void, while splice returns `Array`)
						if (e.expectedType == TTVoid) {
							var methodName = if (isVector) "insertAt" else "insert";
							var eMethod = mk(TEField(fieldObj, methodName, mkIdent(methodName)), tInsert, tInsert);
							mk(TECall(eMethod, args.with(args = [eIndex, eInserted])), TTVoid, TTVoid);
						} else {
							e;
						}

					case [_, _]:
						// just two arguments - no inserted values, so it's a splice just like in Haxe, leave as is
						e;

					case [eIndex]: // single arg - remove everything beginning with the given index
						var eCompatMethod = mkBuiltin('ASCompat.${methodNamePrefix}SpliceAll', TTFunction, removeLeadingTrivia(eArray), []);
						e.with(kind = TECall(eCompatMethod, args.with(
							args = [
								{expr: eArray, comma: commaWithSpace},
								eIndex
							]
						)));

					case _:
						if (args.args.length < 3) throw "assert";

						// rewrite anything else to a compat call
						var eCompatMethod = mkBuiltin('ASCompat.${methodNamePrefix}Splice', TTFunction, removeLeadingTrivia(eArray), []);

						var newArgs = [
							{expr: eArray, comma: commaWithSpace}, // array instance
							args.args[0], // index
							args.args[1], // delete count
							{
								expr: mk(TEArrayDecl({
									syntax: {
										openBracket: mkOpenBracket(),
										closeBracket: mkCloseBracket()
									},
									elements: [for (i in 2...args.args.length) args.args[i]]
								}), tUntypedArray, tUntypedArray),
								comma: null,
							}
						];

						e.with(kind = TECall(eCompatMethod, args.with(args = newArgs)));
				}

			// Handle array methods on TTAny/ASAny objects (dynamic array access)
			// These are transformed to ASCompat.dyn* calls

			// dynPush with single argument
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "push", fieldToken)}, args) if (args.args.length == 1 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynPush", TTFunction, removeLeadingTrivia(eObj), []);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [{expr: eObj, comma: commaWithSpace}, args.args[0]]
				}));

			// dynPush with multiple arguments
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "push", fieldToken)}, args) if (args.args.length > 1 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynPushMultiple", TTFunction, removeLeadingTrivia(eObj), []);
				var restArgs = args.args.slice(1);
				var eRestArray = mk(TEArrayDecl({
					syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
					elements: restArgs
				}), tUntypedArray, tUntypedArray);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [
						{expr: eObj, comma: commaWithSpace},
						args.args[0],
						{expr: eRestArray, comma: null}
					]
				}));

			// dynPop
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "pop", fieldToken)}, args) if (args.args.length == 0 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynPop", TTFunction, removeLeadingTrivia(eObj), []);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [{expr: eObj, comma: null}]
				}));

			// dynShift
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "shift", fieldToken)}, args) if (args.args.length == 0 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynShift", TTFunction, removeLeadingTrivia(eObj), []);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [{expr: eObj, comma: null}]
				}));

			// dynUnshift with single argument
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "unshift", fieldToken)}, args) if (args.args.length == 1 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynUnshift", TTFunction, removeLeadingTrivia(eObj), []);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [{expr: eObj, comma: commaWithSpace}, args.args[0]]
				}));

			// dynUnshift with multiple arguments
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "unshift", fieldToken)}, args) if (args.args.length > 1 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynUnshiftMultiple", TTFunction, removeLeadingTrivia(eObj), []);
				var restArgs = args.args.slice(1);
				var eRestArray = mk(TEArrayDecl({
					syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
					elements: restArgs
				}), tUntypedArray, tUntypedArray);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [
						{expr: eObj, comma: commaWithSpace},
						args.args[0],
						{expr: eRestArray, comma: null}
					]
				}));

			// dynReverse
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "reverse", fieldToken)}, args) if (args.args.length == 0 && isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynReverse", TTFunction, removeLeadingTrivia(eObj), []);
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: [{expr: eObj, comma: null}]
				}));

			// dynSplice
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "splice", fieldToken)}, args) if (isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynSplice", TTFunction, removeLeadingTrivia(eObj), []);
				var newArgs:Array<{expr:TExpr, comma:Null<Token>}> = [{expr: eObj, comma: commaWithSpace}];
				// startIndex
				if (args.args.length > 0) {
					newArgs.push(args.args[0]);
				} else {
					newArgs.push({expr: mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt), comma: commaWithSpace});
				}
				// deleteCount (optional)
				if (args.args.length > 1) {
					var arg = args.args[1];
					var comma = if (args.args.length > 2) commaWithSpace else null;
					newArgs.push({expr: arg.expr, comma: comma});
				}
				// values to insert (optional, as array)
				if (args.args.length > 2) {
					var insertArgs = args.args.slice(2);
					var eInsertArray = mk(TEArrayDecl({
						syntax: {openBracket: mkOpenBracket(), closeBracket: mkCloseBracket()},
						elements: insertArgs
					}), tUntypedArray, tUntypedArray);
					newArgs.push({expr: eInsertArray, comma: null});
				}
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: newArgs
				}));

			// dynConcat
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "concat", fieldToken)}, args) if (isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynConcat", TTFunction, removeLeadingTrivia(eObj), []);
				var newArgs:Array<{expr:TExpr, comma:Null<Token>}> = [{expr: eObj, comma: args.args.length > 0 ? commaWithSpace : null}];
				if (args.args.length > 0) {
					var arg = args.args[0];
					newArgs.push({expr: arg.expr, comma: null});
				}
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: newArgs
				}));

			// dynJoin
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "join", fieldToken)}, args) if (isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynJoin", TTFunction, removeLeadingTrivia(eObj), []);
				var newArgs:Array<{expr:TExpr, comma:Null<Token>}> = [{expr: eObj, comma: args.args.length > 0 ? commaWithSpace : null}];
				if (args.args.length > 0) {
					var arg = args.args[0];
					newArgs.push({expr: arg.expr, comma: null});
				}
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: newArgs
				}));

			// dynSlice
			case TECall({kind: TEField(fieldObj = {kind: TOExplicit(dot, eObj)}, "slice", fieldToken)}, args) if (isAnyType(eObj.type)):
				var eCompatMethod = mkBuiltin("ASCompat.dynSlice", TTFunction, removeLeadingTrivia(eObj), []);
				var newArgs:Array<{expr:TExpr, comma:Null<Token>}> = [{expr: eObj, comma: commaWithSpace}];
				// startIndex
				if (args.args.length > 0) {
					var arg = args.args[0];
					newArgs.push({expr: arg.expr, comma: args.args.length > 1 ? commaWithSpace : null});
				} else {
					newArgs.push({expr: mk(TELiteral(TLInt(new Token(0, TkDecimalInteger, "0", [], []))), TTInt, TTInt), comma: null});
				}
				// endIndex (optional)
				if (args.args.length > 1) {
					var arg = args.args[1];
					newArgs.push({expr: arg.expr, comma: null});
				}
				e.with(kind = TECall(eCompatMethod, {
					openParen: mkOpenParen(),
					closeParen: mkCloseParen(),
					args: newArgs
				}));

			case _:
				e;
		}
	}

	static function isAnyType(t:TType):Bool {
		return switch t {
			case TTAny: true;
			case TTObject(TTAny): true;
			case _: false;
		}
	}
}
