package ax4.filters;

import ax4.TypedTree;
import ax4.TypedTreeTools.*;
import ax4.Token;
import ax4.TokenTools;

typedef ConflictRedefinitions = Map<TClassOrInterfaceDecl, Map<String, String>>;

class DetectStaticInstanceConflicts extends AbstractFilter {
	public final instanceRedefinitions = new ConflictRedefinitions();
	public final staticRedefinitions = new ConflictRedefinitions();

	override function processClass(c:TClassOrInterfaceDecl) {
		switch c.kind {
			case TInterface(_): return;
			case TClass(_):
		}

		var staticFields = new Map<String, Bool>();
		for (m in c.members) {
			switch m {
				case TMField(f) if (isFieldStatic(f)):
					var name = getFieldName(f);
					staticFields[name] = true;
					if (name == "toString" || name == "valueOf") {
						markRedefinition(staticRedefinitions, c, name, name + "_static");
					}
				case _:
			}
		}

		if (!staticFields.iterator().hasNext()) return;

		checkConflicts(c, staticFields);
	}

	function checkConflicts(c:TClassOrInterfaceDecl, staticFields:Map<String, Bool>) {
		var current = c;
		while (current != null) {
			for (m in current.members) {
				switch m {
					case TMField(f) if (!isFieldStatic(f)):
						var name = getFieldName(f);
						if (staticFields.exists(name)) {
							// Conflict found!
							resolveConflict(c, current, name);
						}
					case _:
				}
			}

			switch current.kind {
				case TClass(info) if (info.extend != null):
					current = info.extend.superClass;
				case _:
					current = null;
			}
		}
	}

	function resolveConflict(staticClass:TClassOrInterfaceDecl, instanceClass:TClassOrInterfaceDecl, name:String) {
		// Determine if instanceClass is modifiable (not extern)
		if (isExtern(instanceClass)) {
			// Cannot rename instance field -> Rename STATIC field in staticClass
			markRedefinition(staticRedefinitions, staticClass, name, name + "_static");
		} else {
			// Can rename instance field -> Rename INSTANCE field in instanceClass
			markRedefinition(instanceRedefinitions, instanceClass, name, "_" + name);
		}
	}

	function isExtern(c:TClassOrInterfaceDecl):Bool {
		return c.parentModule.isExtern;
	}

	function markRedefinition(map:ConflictRedefinitions, c:TClassOrInterfaceDecl, name:String, newName:String) {
		var fields = map[c];
		if (fields == null) {
			fields = map[c] = new Map();
		}
		if (!fields.exists(name)) {
			fields[name] = newName;
		}
	}

	function getFieldName(f:TClassField):String {
		return switch f.kind {
			case TFFun(fn): fn.name;
			case TFVar(v): v.name;
			case TFGetter(a) | TFSetter(a): a.name;
		}
	}
}

class RenameStaticInstanceConflicts extends AbstractFilter {
	var instanceRedefinitions:ConflictRedefinitions;
	var staticRedefinitions:ConflictRedefinitions;

	public function new(context, detector:DetectStaticInstanceConflicts) {
		super(context);
		this.instanceRedefinitions = detector.instanceRedefinitions;
		this.staticRedefinitions = detector.staticRedefinitions;
	}

    var currentClass:TClassOrInterfaceDecl;

	override function processClass(c:TClassOrInterfaceDecl) {
        currentClass = c;
		// Apply definition renames
		applyRenames(c, instanceRedefinitions, false);
		applyRenames(c, staticRedefinitions, true);
		super.processClass(c);
	}

	function applyRenames(c:TClassOrInterfaceDecl, map:ConflictRedefinitions, applyToStatic:Bool) {
		if (map.exists(c)) {
			var redefs = map[c];
			for (m in c.members) {
				switch m {
					case TMField(f):
                        if (isFieldStatic(f) == applyToStatic) {
                            var name = getFieldName(f);
                            if (redefs.exists(name)) {
                                renameField(f, redefs[name]);
                            }
                        }
					case _:
				}
			}
		}
	}

	function getFieldName(f:TClassField):String {
		return switch f.kind {
			case TFFun(fn): fn.name;
			case TFVar(v): v.name;
			case TFGetter(a) | TFSetter(a): a.name;
		}
	}

	function renameField(f:TClassField, newName:String) {
		switch f.kind {
			case TFVar(v):
				v.name = newName;
				v.syntax.name = changeToken(v.syntax.name, newName);
			case TFFun(field):
				field.name = newName;
				field.syntax.name = changeToken(field.syntax.name, newName);
			case TFGetter(field) | TFSetter(field):
				field.name = newName;
				field.syntax.name = changeToken(field.syntax.name, newName);
		}
	}

	static inline function changeToken(t:Token, name:String):Token {
		return new Token(t.pos, TkIdent, name, t.leadTrivia, [new Trivia(TrBlockComment, "/*renamed*/")].concat(t.trailTrivia));
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);
		return switch e.kind {
			case TEField(obj, fieldName, fieldToken):
				// Check if this field access needs renaming
				var resolvedName = resolveRename(obj, fieldName);
				if (resolvedName != null) {
					e.with(kind = TEField(obj, resolvedName, fieldToken.with(TkIdent, resolvedName)));
				} else {
					e;
				}
			case _: e;
		}
	}

	function resolveRename(obj:TFieldObject, name:String):String {
		switch obj.type {
			case TTInst(c):
                // Instance access -> check instanceRedefinitions
                return findRenameInHierarchy(c, name, instanceRedefinitions);
			case TTStatic(c):
                // Static access -> check staticRedefinitions
                if (staticRedefinitions.exists(c) && staticRedefinitions[c].exists(name)) {
                    return staticRedefinitions[c][name];
                }
            case _:
		}
        return null;
	}

	function findRenameInHierarchy(c:TClassOrInterfaceDecl, name:String, map:ConflictRedefinitions):String {
		var current = c;
		while (current != null) {
			if (map.exists(current) && map[current].exists(name)) {
				return map[current][name];
			}
			switch current.kind {
				case TClass(info) if (info.extend != null):
					current = info.extend.superClass;
				case _:
					return null;
			}
		}
		return null;
	}
}
