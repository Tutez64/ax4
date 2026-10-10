import haxe.macro.Context;
import haxe.macro.Expr.Position;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import haxe.macro.TypedExprTools;

using StringTools;

/**
	Counts the compat calls of a converted project by function and static argument types,
	to find coercions the converter could have avoided (e.g. `toInt(Int)`, `toNumber(Float)`).

	Add to the project's own compile arguments:

		-cp <ax4>/tools
		--no-inline
		--no-output
		--macro CompatAudit.init("src/", "compat-audit.txt")

	`--no-inline` keeps the inline compat helpers as calls. Only classes whose file path starts
	with the first argument are scanned. The report lists `count<TAB>call(argument types)`,
	most frequent first, with sample positions (an optional third argument sets how many, 4 by default).
**/
class CompatAudit {
	static var prefix:String;
	static var maxSamples:Int;
	static var counts = new Map<String, Int>();
	static var samples = new Map<String, Array<String>>();

	public static function init(srcPrefix:String, outFile:String, samplesPerCall:Int = 4) {
		prefix = srcPrefix;
		maxSamples = samplesPerCall;
		Context.onGenerate(types -> {
			for (t in types) {
				switch t {
					case TInst(c, _):
						var cl = c.get();
						if (!Context.getPosInfos(cl.pos).file.startsWith(prefix)) continue;
						for (f in cl.fields.get().concat(cl.statics.get())) scanField(f);
						if (cl.constructor != null) scanField(cl.constructor.get());
					case _:
				}
			}
			writeReport(outFile);
		});
	}

	static function scanField(f:ClassField) {
		var e = f.expr();
		if (e != null) walk(e);
	}

	static function walk(e:TypedExpr) {
		switch e.expr {
			case TCall({expr: TField(_, FStatic(c, cf))}, args) if (c.get().name == "ASCompat"):
				var name = cf.get().name;
				if (name == "dynamicAs" || name == "reinterpretAs") {
					// An upcast needs no runtime check at all.
					var upcast = switch args[1].expr {
						case TTypeExpr(TClassDecl(tc)) if (tc.get().params.length == 0 && Context.follow(args[0].t).match(TInst(_, _))):
							Context.unify(args[0].t, TInst(tc, []));
						case _: false;
					}
					note('$name(${typeName(args[0].t)}, ${upcast ? "<supertype>" : "T"})', e.pos);
				} else {
					note('$name(${argTypes(args)})', e.pos);
				}
			case TCall({expr: TField(_, FStatic(c, cf))}, args) if (c.get().name == "ASAny_Impl_"):
				note('ASAny.${cf.get().name}(${argTypes(args)})', e.pos);
			case TCast(inner, null) if (typeName(e.t) == "ASAny" && typeName(inner.t) != "ASAny"):
				note('toASAny(${typeName(inner.t)})', e.pos);
			case _:
		}
		TypedExprTools.iter(e, walk);
	}

	static function typeName(t:Type):String {
		return TypeTools.toString(Context.follow(t, true));
	}

	static function argTypes(args:Array<TypedExpr>):String {
		return [for (a in args) typeName(a.t)].join(", ");
	}

	static function note(key:String, pos:Position) {
		counts[key] = (counts[key] ?? 0) + 1;
		var list = samples[key];
		if (list == null) samples[key] = list = [];
		if (list.length < maxSamples) {
			var p = Context.getPosInfos(pos);
			list.push('${p.file}:${lineOf(p.file, p.min)}');
		}
	}

	static var fileBytes = new Map<String, haxe.io.Bytes>();

	static function lineOf(file:String, offset:Int):Int {
		// Positions are byte offsets.
		var bytes = fileBytes[file];
		if (bytes == null) fileBytes[file] = bytes = sys.io.File.getBytes(file);
		var line = 1;
		for (i in 0...offset) {
			if (bytes.get(i) == "\n".code) line++;
		}
		return line;
	}

	static function writeReport(outFile:String) {
		var keys = [for (k in counts.keys()) k];
		keys.sort((a, b) -> counts[b] - counts[a]);
		var out = new StringBuf();
		for (k in keys) {
			out.add('${counts[k]}\t$k\n');
			for (s in samples[k]) out.add('\t\t$s\n');
		}
		sys.io.File.saveContent(outFile, out.toString());
	}
}
