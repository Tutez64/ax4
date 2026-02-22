import utest.Assert.*;

class TestASDictionary extends utest.Test {
	function testAsDictionary() {
		var dict = new ASDictionary<Int, String>();
		equals(dict, ASDictionary.asDictionary(dict));
	}

	function testPrimitiveKeysLookup() {
		var dict = new ASDictionary<Dynamic, String>();
		dict[1] = "one";
		dict[true] = "bool";
		dict["1"] = "string-one";
		dict[1.5] = "float";

		equals("string-one", dict[1]);
		equals("bool", dict[true]);
		equals("string-one", dict["1"]);
		equals("float", dict[1.5]);
		isTrue(dict.exists(1));
		isTrue(dict.exists(true));
		isTrue(dict.exists("1"));
		isTrue(dict.exists(1.5));
	}

	function testPrimitiveKeysDoNotCollide() {
		var dict = new ASDictionary<Dynamic, String>();
		dict[1] = "int";
		dict["1"] = "string";

		equals("string", dict[1]);
		equals("string", dict["1"]);
	}

	function testPrimitiveKeyRemove() {
		var dict = new ASDictionary<Dynamic, String>();
		dict[123] = "value";
		isTrue(dict.exists(123));
		isTrue(dict.remove(123));
		isFalse(dict.exists(123));
	}

	function testPrimitiveKeysIteratorsIncludeEntries() {
		var dict = new ASDictionary<Dynamic, String>();
		dict[7] = "seven";
		dict["seven"] = "s";

		var keys:Array<Dynamic> = [for (k in dict.keys()) k];
		var values:Array<String> = [for (v in dict.iterator()) v];
		isTrue(keys.indexOf(7) != -1);
		isTrue(keys.indexOf("seven") != -1);
		isTrue(values.indexOf("seven") != -1);
		isTrue(values.indexOf("s") != -1);

		var pairCount = 0;
		for (pair in dict.keyValueIterator()) {
			if (pair != null) pairCount++;
		}
		isTrue(pairCount >= 2);
	}
}
