package ax4.filters;

/**
	Gives the branches of `c ? a : b` and `a ?? b` a type Haxe unifies, as AS3 mixes any types there:

	- branches of different kinds (a class instance and a Boolean: `cached ?? false`,
	  `found ? file : false`) are retyped to the expected type, or ASAny;
	- the left side of `??` that reads a String field of an API class is retyped `(x : String)`:
	  OpenFL types such fields with abstracts (TextFormat.align is a TextFormatAlign), which `??`
	  does not convert implicitly.
**/
class UnifyBranchTypes extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TETernary(t) if (!unify(t.ethen.type, t.eelse.type)):
				var target = targetType(e, t.ethen, t.eelse);
				e.with(kind = TETernary({syntax: t.syntax, econd: t.econd, ethen: retype(t.ethen, target), eelse: retype(t.eelse, target)}), type = target);

			case TEBinop(a, op = OpNullCoalesce(_), b) if (!unify(a.type, b.type)):
				var target = targetType(e, a, b);
				e.with(kind = TEBinop(retype(a, target), op, retype(b, target)), type = target);

			case TEBinop(a, op = OpNullCoalesce(_), b) if (a.type == TTString && isApiField(a)):
				e.with(kind = TEBinop(mk(TEHaxeRetype(a), TTString, TTString), op, b));

			case _:
				e;
		}
	}

	static function kind(t:TType):Int {
		return switch t {
			case TTAny | TTObject(TTAny) | TTVoid: 0; // unifies with anything
			case TTBoolean: 1;
			case TTInt | TTUint | TTNumber: 2;
			case TTString: 3;
			case _: 4;
		}
	}

	static function unify(a:TType, b:TType):Bool {
		var ka = kind(a), kb = kind(b);
		return ka == 0 || kb == 0 || ka == kb;
	}

	static function targetType(e:TExpr, a:TExpr, b:TExpr):TType {
		var expected = e.expectedType;
		return if (expected != TTVoid && (typeEq(expected, a.type) || typeEq(expected, b.type))) expected else TTAny;
	}

	static function retype(e:TExpr, target:TType):TExpr {
		return if (typeEq(e.type, target)) e else mk(TEHaxeRetype(e), target, target);
	}

	static function isApiField(e:TExpr):Bool {
		return switch skipParens(e).kind {
			case TEField({type: TTInst(cls)}, _, _): cls.parentModule != null && cls.parentModule.isExtern;
			case _: false;
		}
	}
}
