package ax4.filters;

class TextFieldApi extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TECall({kind: TEField({kind: TOExplicit(dot, eText = {type: TTInst(cls)})}, "getXMLText", _)}, args)
				if (isTextField(cls)):
				var eCompat = mkBuiltin("ASCompat.textFieldGetXMLText", TTFunction, removeLeadingTrivia(eText));
				var newArgs = [{expr: eText, comma: if (args.args.length > 0) commaWithSpace else null}].concat(args.args);
				mk(TECall(eCompat, args.with(args = newArgs)), TTString, TTString);

			case _:
				e;
		}
	}

	static inline function isTextField(cls:TClassOrInterfaceDecl):Bool {
		return cls.name == "TextField" && cls.parentModule.parentPack.name == "flash.text";
	}
}
