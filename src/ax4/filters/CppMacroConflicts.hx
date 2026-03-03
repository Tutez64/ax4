package ax4.filters;

import ax4.TypedTree;
import ax4.Token;
import ax4.TokenTools;
import ax4.TypedTreeTools.*;

typedef CppMacroFieldRenames = Map<TClassOrInterfaceDecl, Map<String, String>>;
typedef CppMacroDeclRenames = Map<TDecl, {oldName:String, newName:String}>;

class DetectCppMacroConflicts extends AbstractFilter {
	public final classFieldRenames:CppMacroFieldRenames = new Map();
	public final moduleDeclRenames:CppMacroDeclRenames = new Map();

	override function processModule(mod:TModule) {
		detectModuleDeclRenames(mod);
		super.processModule(mod);
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		var usedNames = collectClassFieldNames(c);
		var redefs = classFieldRenames[c];

		for (member in c.members) {
			switch member {
				case TMField(field):
					var name = getFieldName(field);
					if (!isCppMacroConflict(name)) {
						continue;
					}
					if (redefs == null) {
						redefs = new Map();
						classFieldRenames[c] = redefs;
					}
					if (!redefs.exists(name)) {
						redefs[name] = makeUniqueName(name, usedNames);
					}
				case _:
			}
		}

		super.processClass(c);
	}

	function detectModuleDeclRenames(mod:TModule) {
		var decls = getModuleDecls(mod);
		var usedNames = new Map<String, Bool>();
		for (decl in decls) {
			usedNames[decl.name] = true;
		}

		for (decl in decls) {
			switch decl.kind {
				case TDVar(_) | TDFunction(_):
					var oldName = decl.name;
					if (!isCppMacroConflict(oldName)) {
						continue;
					}
					if (!moduleDeclRenames.exists(decl)) {
						moduleDeclRenames[decl] = {
							oldName: oldName,
							newName: makeUniqueName(oldName, usedNames)
						};
					}
				case _:
			}
		}
	}

	static function getModuleDecls(mod:TModule):Array<TDecl> {
		var decls = [mod.pack.decl];
		for (decl in mod.privateDecls) {
			decls.push(decl);
		}
		return decls;
	}

	static function collectClassFieldNames(c:TClassOrInterfaceDecl):Map<String, Bool> {
		var names = new Map<String, Bool>();
		for (member in c.members) {
			switch member {
				case TMField(field):
					names[getFieldName(field)] = true;
				case _:
			}
		}
		return names;
	}

	static function getFieldName(field:TClassField):String {
		return switch field.kind {
			case TFVar(v): v.name;
			case TFFun(f): f.name;
			case TFGetter(a) | TFSetter(a): a.name;
		}
	}

	static function makeUniqueName(baseName:String, usedNames:Map<String, Bool>):String {
		var suffix = "_cpp";
		var candidate = baseName + suffix;
		var index = 2;
		while (usedNames.exists(candidate) || isCppMacroConflict(candidate)) {
			candidate = baseName + suffix + index;
			index++;
		}
		usedNames[candidate] = true;
		return candidate;
	}

	static inline function isCppMacroConflict(name:String):Bool {
		return cppMacroConflicts.exists(name);
	}

	static final cppMacroConflicts = [
		"CHAR_BIT" => true,
		"SCHAR_MIN" => true,
		"SCHAR_MAX" => true,
		"UCHAR_MAX" => true,
		"CHAR_MIN" => true,
		"CHAR_MAX" => true,
		"MB_LEN_MAX" => true,
		"SHRT_MIN" => true,
		"SHRT_MAX" => true,
		"USHRT_MAX" => true,
		"INT_MIN" => true,
		"INT_MAX" => true,
		"UINT_MAX" => true,
		"LONG_MIN" => true,
		"LONG_MAX" => true,
		"ULONG_MAX" => true,
		"LLONG_MIN" => true,
		"LLONG_MAX" => true,
		"ULLONG_MAX" => true,
		"FLT_MIN" => true,
		"FLT_MAX" => true,
		"DBL_MIN" => true,
		"DBL_MAX" => true,
		"LDBL_MIN" => true,
		"LDBL_MAX" => true,
		"HUGE_VAL" => true,
		"HUGE_VALF" => true,
		"HUGE_VALL" => true,
		"INFINITY" => true,
		"NAN" => true,
		"NULL" => true,
		"EOF" => true,
		"TRUE" => true,
		"FALSE" => true,
		"ERROR" => true,
		"NO_ERROR" => true,
		"MIN" => true,
		"MAX" => true
	];
}

class RenameCppMacroConflicts extends AbstractFilter {
	final classFieldRenames:CppMacroFieldRenames;
	final moduleDeclRenames:CppMacroDeclRenames;

	public function new(context, detector:DetectCppMacroConflicts) {
		super(context);
		classFieldRenames = detector.classFieldRenames;
		moduleDeclRenames = detector.moduleDeclRenames;
	}

	override function processModule(mod:TModule) {
		renameModuleDecl(mod.pack.decl);
		for (decl in mod.privateDecls) {
			renameModuleDecl(decl);
		}
		super.processModule(mod);
	}

	override function processClass(c:TClassOrInterfaceDecl) {
		renameClassFields(c);
		super.processClass(c);
	}

	override function processExpr(e:TExpr):TExpr {
		e = mapExpr(processExpr, e);

		return switch e.kind {
			case TEField(obj, fieldName, fieldToken):
				var renamedField = resolveFieldRename(obj, fieldName);
				if (renamedField == null) {
					e;
				} else {
					e.with(kind = TEField(obj, renamedField, fieldToken.with(TkIdent, renamedField)));
				}

			case TEDeclRef(path, decl):
				var rename = moduleDeclRenames[decl];
				if (rename == null) {
					e;
				} else {
					renameDotPathLast(path, rename.oldName, rename.newName);
					e.with(kind = TEDeclRef(path, decl));
				}

			case _:
				e;
		}
	}

	function renameClassFields(c:TClassOrInterfaceDecl) {
		var renames = classFieldRenames[c];
		if (renames == null) {
			return;
		}

		for (member in c.members) {
			switch member {
				case TMField(field):
					var oldName = getFieldName(field);
					var newName = renames[oldName];
					if (newName != null) {
						renameClassField(field, newName);
					}
				case _:
			}
		}
	}

	function renameModuleDecl(decl:TDecl) {
		var rename = moduleDeclRenames[decl];
		if (rename == null) {
			return;
		}
		decl.name = rename.newName;
		switch decl.kind {
			case TDVar(v):
				v.name = rename.newName;
				v.syntax.name = renameToken(v.syntax.name, rename.newName);

			case TDFunction(f):
				f.name = rename.newName;
				f.syntax.name = renameToken(f.syntax.name, rename.newName);

			case _:
		}
	}

	function resolveFieldRename(obj:TFieldObject, fieldName:String):String {
		return switch obj.type {
			case TTInst(c) | TTStatic(c):
				findFieldRenameInHierarchy(c, fieldName);
			case _:
				null;
		}
	}

	function findFieldRenameInHierarchy(c:TClassOrInterfaceDecl, fieldName:String):String {
		var current = c;
		while (current != null) {
			var classRenames = classFieldRenames[current];
			if (classRenames != null && classRenames.exists(fieldName)) {
				return classRenames[fieldName];
			}
			switch current.kind {
				case TClass(info) if (info.extend != null):
					current = info.extend.superClass;
				case _:
					current = null;
			}
		}
		return null;
	}

	function renameClassField(field:TClassField, newName:String) {
		switch field.kind {
			case TFVar(v):
				v.name = newName;
				v.syntax.name = renameToken(v.syntax.name, newName);

			case TFFun(f):
				f.name = newName;
				f.syntax.name = renameToken(f.syntax.name, newName);

			case TFGetter(a) | TFSetter(a):
				a.name = newName;
				a.syntax.name = renameToken(a.syntax.name, newName);
		}
	}

	static function renameDotPathLast(path:DotPath, oldName:String, newName:String) {
		if (path.rest.length == 0) {
			if (path.first.text == oldName) {
				path.first = path.first.with(TkIdent, newName);
			}
			return;
		}
		var last = path.rest[path.rest.length - 1];
		if (last.element.text == oldName) {
			last.element = last.element.with(TkIdent, newName);
		}
	}

	static function getFieldName(field:TClassField):String {
		return switch field.kind {
			case TFVar(v): v.name;
			case TFFun(f): f.name;
			case TFGetter(a) | TFSetter(a): a.name;
		}
	}

	static inline function renameToken(t:Token, name:String):Token {
		return new Token(t.pos, TkIdent, name, t.leadTrivia, [new Trivia(TrBlockComment, "/*cpp macro conflict*/")].concat(t.trailTrivia));
	}
}
