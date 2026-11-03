package ax4.filters;

typedef FieldRedefinitions = Map<TClassOrInterfaceDecl, Map<String, String>>;

class DetectFieldRedefinitions extends AbstractFilter {
	public final redefinitions = new FieldRedefinitions();

	override function processClass(c:TClassOrInterfaceDecl) {
		switch c.kind {
			case TInterface(_) | TClass({extend: null}):
				// nothing to do for interfaces and parent-less classes
			case TClass(info):
				for (m in c.members) {
					switch m {
						case TMField(field):
							switch (field.kind) {
								case TFVar({name: name}) | TFFun({name: name}) | TFGetter({name: name}) | TFSetter({name: name}):
									markRedefinition(c, info.extend.superClass, name);
							}
						case _:
					}
				}
		}
	}

	function markRedefinition(subClass:TClassOrInterfaceDecl, superClass:TClassOrInterfaceDecl, name:String) {
		var parentDefinition = superClass.findFieldInHierarchy(name, false);
		if (parentDefinition == null) {
			// no redefinition
			return;
		}

		var c = parentDefinition.declaringClass;

		var field = parentDefinition.field;
		var isPrivate = Lambda.exists(field.modifiers, m -> m.match(FMPrivate(_)));
		// AS3 keeps the internal fields of each package apart too (a SWC's fields have no modifiers)
		var isInternal = !c.parentModule.isExtern && !Lambda.exists(field.modifiers, m -> m.match(FMPublic(_) | FMPrivate(_) | FMProtected(_)));
		var otherPackage = c.parentModule == null || subClass.parentModule == null || c.parentModule.parentPack.name != subClass.parentModule.parentPack.name;

		if (!isPrivate && !(isInternal && otherPackage)) {
			// not a problem
			return;
		}

		// register
		var fields = redefinitions[c];
		if (fields == null) {
			fields = redefinitions[c] = new Map();
		}
		if (fields.exists(name)) {
			// already mangled
			return;
		}
		var qualifier = if (c.parentModule.parentPack.name == "") c.name else StringTools.replace(c.parentModule.parentPack.name, ".", "_") + "_" + c.name;
		var mangledName = name + "__" + qualifier; // should be pretty unique
		fields[name] = mangledName;
	}
}

class RenameRedefinedFields extends AbstractFilter {
	public final redefinitions:FieldRedefinitions;
	var redefinedFields:Null<Map<String,String>>;
	var thisClass:Null<TClassOrInterfaceDecl>;

	public function new(context, detector:DetectFieldRedefinitions) {
		super(context);
		this.redefinitions = detector.redefinitions;
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		// every class is processed, as the classes of an internal field's package read it too
		if (redefinitions.iterator().hasNext()) {
			redefinedFields = redefinitions[c];
			thisClass = c;
			super.processClass(c);
			redefinedFields = null;
			thisClass = null;
		}
	}

	inline function maybeMangle(name:String, f:(mangledName:String)->Void) {
		var mangledName = if (redefinedFields == null) null else redefinedFields[name];
		if (mangledName != null) f(mangledName);
	}

	/** The new name of the renamed field that `name` reads on an instance of `cls`, or null. **/
	function findMangledName(cls:TClassOrInterfaceDecl, name:String):Null<String> {
		while (cls != null) {
			var fields = redefinitions[cls];
			if (fields != null && fields.exists(name)) {
				return fields[name];
			}
			if (cls.findField(name, false) != null) {
				return null;
			}
			cls = switch cls.kind {
				case TClass({extend: extend}) if (extend != null): extend.superClass;
				case _: null;
			}
		}
		return null;
	}

	static inline function changeToken(t:Token, name:String):Token {
		return new Token(t.pos, TkIdent, name, t.leadTrivia, [new Trivia(TrBlockComment, "/*redefined private*/")].concat(t.trailTrivia));
	}

	override function processClassField(field:TClassField) {
		switch (field.kind) {
			case TFVar(v):
				maybeMangle(v.name, mangledName -> {
					v.name = mangledName;
					v.syntax.name = changeToken(v.syntax.name, mangledName);
				});
			case TFFun(field):
				maybeMangle(field.name, mangledName -> {
					field.name = mangledName;
					field.syntax.name = changeToken(field.syntax.name, mangledName);
				});

			case TFGetter(field) | TFSetter(field):
				maybeMangle(field.name, mangledName -> {
					field.name = mangledName;
					field.syntax.name = changeToken(field.syntax.name, mangledName);
				});
		}

		super.processClassField(field); // recurse into expressions
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEField(obj = {type: TTInst(c)}, fieldName, fieldToken) if (findMangledName(c, fieldName) != null):
				var mangledName = findMangledName(c, fieldName);
				e.with(kind = TEField(obj, mangledName, fieldToken.with(TkIdent, mangledName)));
			case _:
				e;
		}
	}
}