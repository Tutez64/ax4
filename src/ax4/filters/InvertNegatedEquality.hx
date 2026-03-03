package ax4.filters;

class InvertNegatedEquality extends AbstractFilter {
	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch (e.kind) {
			case TEPreUnop(PreNot(notToken), e2):

				function moveTrivia(a:TExpr) {
					processLeadingToken(t -> t.leadTrivia = notToken.leadTrivia.concat(notToken.trailTrivia).concat(t.leadTrivia), a);
				}

				var target = e2;
				var parenLead:Array<Trivia> = [];
				var parenTrail:Array<Trivia> = [];
				switch e2.kind {
					case TEParens(openParen, inner, closeParen):
						parenLead = openParen.leadTrivia.concat(openParen.trailTrivia);
						parenTrail = closeParen.leadTrivia.concat(closeParen.trailTrivia);
						target = inner;
					case _:
				}

				switch (target.kind) {
					case TEBinop(a, OpEquals(t), b):
						if (parenLead.length > 0) {
							processLeadingToken(token -> token.leadTrivia = parenLead.concat(token.leadTrivia), target);
						}
						if (parenTrail.length > 0) {
							processTrailingToken(token -> token.trailTrivia = token.trailTrivia.concat(parenTrail), target);
						}
						moveTrivia(a);
						var t = new Token(t.pos, TkExclamationEquals, "!=", t.leadTrivia, t.trailTrivia);
						e.with(kind = TEBinop(a, OpNotEquals(t), b));

					case TEBinop(a, OpNotEquals(t), b):
						if (parenLead.length > 0) {
							processLeadingToken(token -> token.leadTrivia = parenLead.concat(token.leadTrivia), target);
						}
						if (parenTrail.length > 0) {
							processTrailingToken(token -> token.trailTrivia = token.trailTrivia.concat(parenTrail), target);
						}
						moveTrivia(a);
						var t = new Token(t.pos, TkEqualsEquals, "==", t.leadTrivia, t.trailTrivia);
						e.with(kind = TEBinop(a, OpEquals(t), b));

					case _:
						e;
				}
			case _:
				e;
		}
	}
}
