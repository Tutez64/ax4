package ax4;

import ax4.Utils.print;

using StringTools;

/**
	Collects conversion diagnostics (warnings) printed during a run and prints an
	aggregated summary at the end. See docs/Diagnostics.md.
**/
class DiagnosticStats {
	final counts = new Map<String,Int>();
	public var total(default, null) = 0;

	public function new() {}

	public function record(message:String):Void {
		var key = normalizeMessage(message);
		var n = counts.get(key);
		counts.set(key, if (n == null) 1 else n + 1);
		total++;
	}

	public function printSummary():Void {
		if (total == 0) {
			print("diagnostics: none");
			return;
		}

		var entries = [for (key => count in counts) {key: key, count: count}];
		entries.sort(function(a, b) {
			if (a.count != b.count) return b.count - a.count;
			return Reflect.compare(a.key, b.key);
		});

		print('diagnostics: $total total (${entries.length} kinds)');
		print("See docs/Diagnostics.md for descriptions and recommendations.");
		for (e in entries) {
			print('  ${e.count}\t${e.key}');
		}
	}

	/**
		Collapse site-specific details so the summary groups related warnings.
	**/
	public static function normalizeMessage(message:String):String {
		if (~/^Inferred local var type "[^"]+" as .+ \(was ASAny\)$/.match(message)) {
			return "Inferred local var type <name> as <Type> (was ASAny)";
		}
		if (~/^Unknown Array instance field .+$/.match(message)) {
			return "Unknown Array instance field <name>";
		}
		if (~/^Unknown Vector instance field .+$/.match(message)) {
			return "Unknown Vector instance field <name>";
		}
		if (~/^Unknown field .+ on type .+$/.match(message)) {
			return "Unknown field <name> on type <Type>";
		}
		if (~/^Attempting to get field on type .+$/.match(message)) {
			return "Attempting to get field on type <Type>";
		}
		if (~/^unknown callable type: .+$/.match(message)) {
			return "unknown callable type: <Type>";
		}
		if (~/^Unknown metadata: .+$/.match(message)) {
			return "Unknown metadata: <name>";
		}
		if (~/^Unknown mimeType: .+$/.match(message)) {
			return "Unknown mimeType: <name>";
		}
		if (~/^Unknown to string coercion \(actual type is .+\)$/.match(message)) {
			return "Unknown to string coercion (actual type is <Type>)";
		}
		if (~/^Unknown parameter type for the Date constructor: .+$/.match(message)) {
			return "Unknown parameter type for the Date constructor: <Type>";
		}
		if (~/^Unsupported iteratee type: .+$/.match(message)) {
			return "Unsupported iteratee type: <Type>";
		}
		if (~/^Missing type coercion: expected=.+, actual=.+$/.match(message)) {
			return "Missing type coercion: expected=<Type>, actual=<Type>";
		}
		if (~/^E4X syntax is used on non-XML expression \(type: .+\)$/.match(message)) {
			return "E4X syntax is used on non-XML expression (type: <Type>)";
		}
		if (~/^Invalid dictionary key type, expected .+, got .+$/.match(message)) {
			return "Invalid dictionary key type, expected <Type>, got <Type>";
		}
		if (~/^Builtin .+ used as a switch case value$/.match(message)) {
			return "Builtin <name> used as a switch case value";
		}
		if (~/^unknown builtin: .+$/.match(message)) {
			return "unknown builtin: <name>";
		}
		if (~/^unknown declaration: .+$/.match(message)) {
			return "unknown declaration: <name>";
		}
		if (~/^Unsupported number of arguments for Number\..+$/.match(message)) {
			return "Unsupported number of arguments for Number.<method>";
		}
		if (~/^closure on String\..+$/.match(message)) {
			return "closure on String.<method>";
		}
		if (~/^closure on Function\..+$/.match(message)) {
			return "closure on Function.<method>";
		}
		if (~/^Unsupported \$kind\.sort arguments$/.match(message)) {
			return message; // already uses interpolated kind in source; leave as-is if literal
		}
		if (~/^Trying to call an expression of type .+$/.match(message)) {
			return "Trying to call an expression of type <Type>";
		}
		return message;
	}
}
