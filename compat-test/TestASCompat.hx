import utest.Assert.*;

class TestASCompat extends utest.Test {
	function testProcessNull() {
		equals(0, ASCompat.processNull((null : Null<Int>)));
		equals(0, ASCompat.processNull((null : Null<UInt>)));

		equals(false, ASCompat.processNull((null : Null<Bool>)));

		floatEquals(0, ASCompat.processNull((null : Null<Float>)));

		var undefined = new ASDictionary<Int,Float>()[10];
		floatEquals(Math.NaN, ASCompat.processNull((undefined : Null<Float>)));
	}

	function testIsAnyVector() {
		isTrue(ASCompat.isVector(new flash.Vector<String>(), (_:ASAny)));
	}

	function testVectorSpliceInsert() {
		var v = new flash.Vector<Int>();
		v.push(1);
		v.push(2);
		v.push(3);

		var removed = ASCompat.vectorSplice(v, 1, 1, [9, 8]);
		equals(1, removed.length);
		equals(2, removed[0]);
		equals(4, v.length);
		equals(1, v[0]);
		equals(9, v[1]);
		equals(8, v[2]);
		equals(3, v[3]);
	}

	function testArraySortWithOptions() {
		var values = [3, 1, 2];
		ASCompat.ASArray.sortWithOptions(values, ASCompat.ASArray.NUMERIC | ASCompat.ASArray.DESCENDING);
		equals(3, values[0]);
		equals(2, values[1]);
		equals(1, values[2]);
	}

	function testArraySortOn() {
		var values = [{n: "b"}, {n: "A"}, {n: "c"}];
		ASCompat.ASArray.sortOn(values, "n", ASCompat.ASArray.CASEINSENSITIVE);
		equals("A", values[0].n);
		equals("b", values[1].n);
		equals("c", values[2].n);
	}

	function testArraySortOnMulti() {
		var values = [
			{a: 1, b: 2},
			{a: 1, b: 1},
			{a: 0, b: 5}
		];
		ASCompat.ASArray.sortOn(values, ["a", "b"], [ASCompat.ASArray.NUMERIC, ASCompat.ASArray.NUMERIC | ASCompat.ASArray.DESCENDING]);
		equals(0, values[0].a);
		equals(2, values[1].b);
		equals(1, values[2].b);
	}

	function testArraySortReturnIndexed() {
		var values = ["b", "a", "c"];
		var indices:Array<Int> = cast ASCompat.ASArray.sortWithOptions(values, ASCompat.ASArray.RETURNINDEXEDARRAY);
		equals("b", values[0]);
		equals(1, indices[0]);
		equals(0, indices[1]);
		equals(2, indices[2]);
	}

	function testArraySortMethodClosureKeepsThis() {
		var owner = new TestASCompatComparatorOwner(5);
		var values = [3, 1, 2];
		var cmp:Dynamic = owner.compareInts;
		ASCompat.ASArray.sort(values, cmp);
		equals(1, values[0]);
		equals(2, values[1]);
		equals(3, values[2]);
		isTrue(owner.calls > 0);
	}

	function testVectorSortMethodClosureKeepsThis() {
		var owner = new TestASCompatComparatorOwner(9);
		var values = new flash.Vector<Int>();
		values.push(4);
		values.push(1);
		values.push(3);
		var cmp:Dynamic = owner.compareInts;
		ASCompat.ASVector.sort(values, cmp);
		equals(1, values[0]);
		equals(3, values[1]);
		equals(4, values[2]);
		isTrue(owner.calls > 0);
	}

	function testArrayReverseMapSomeSort() {
		var reversed = [1, 2, 3];
		var reversedResult = ASCompat.ASArray.reverse(reversed);
		isTrue(reversedResult == reversed);
		equals(3, reversed[0]);
		equals(1, reversed[2]);

		var values = [1, 2, 3];
		var ctx = new TestASCompatSumCtx();
		var found = ASCompat.ASArray.some(values, ctx.test, ctx);
		isTrue(found);
		equals(3, ctx.sum);

		var mapped = ASCompat.ASArray.map(values, function(value:Int, index:Int, array:Array<Int>):Int {
			return value * 2;
		});
		equals(3, mapped.length);
		equals(2, mapped[0]);
		equals(6, mapped[2]);

		var sortable = [3, 1, 2];
		ASCompat.ASArray.sort(sortable, function(a:Int, b:Int):Dynamic {
			return (a > b) ? 1.0 : -1.0;
		});
		equals(1, sortable[0]);
		equals(3, sortable[2]);
	}

	function testArrayForEach() {
		var values = [1, 2, 3];
		var sum = 0;
		ASCompat.ASArray.forEach(values, function(value:Int, index:Int, array:Array<Int>):Void {
			sum += value;
			equals(value, array[index]);
		});
		equals(6, sum);
	}

	function testArrayPushUnshiftMultiple() {
		var items = [1];
		var len = ASCompat.ASArray.pushMultiple(items, 2, 3, 4);
		equals(4, len);
		equals(4, items[3]);

		len = ASCompat.ASArray.unshiftMultiple(items, -1, -2);
		equals(6, len);
		equals(-1, items[0]);
		equals(-2, items[1]);
	}

	function testArraySpliceHelpers() {
		var items = [1, 2, 3, 4];
		var newLen = ASCompat.arraySetLength(items, 2);
		equals(2, newLen);
		equals(2, items.length);

		items = [1, 2, 3, 4];
		var removedAll = ASCompat.arraySpliceAll(items, 2);
		equals(2, removedAll.length);
		equals(3, removedAll[0]);
		equals(2, items.length);

		items = [1, 2, 3];
		var removed = ASCompat.arraySplice(items, 1, 1, [9, 8]);
		equals(1, removed.length);
		equals(2, removed[0]);
		equals(4, items.length);
		equals(1, items[0]);
		equals(9, items[1]);
		equals(8, items[2]);
		equals(3, items[3]);
	}

	function testVectorCompatHelpers() {
		var v = new flash.Vector<Int>();
		v.push(1);
		v.push(2);
		v.push(3);

		ASCompat.ASVector.reverse(v);
		equals(3, v[0]);
		equals(1, v[2]);

		var mapped = ASCompat.ASVector.map(v, function(value:Int, index:Int, vector:flash.Vector<Int>):Int {
			return value + 1;
		});
		equals(3, mapped.length);
		equals(4, mapped[0]);
		equals(2, mapped[2]);

		ASCompat.ASVector.sort(v, function(a:Int, b:Int):Dynamic {
			return (a > b) ? 1.0 : -1.0;
		});
		equals(1, v[0]);
		equals(3, v[2]);
	}

	function testVectorForEach() {
		var v = new flash.Vector<Int>();
		v.push(1);
		v.push(2);
		v.push(3);

		var sum = 0;
		ASCompat.ASVector.forEach(v, function(value:Int, index:Int, vector:flash.Vector<Int>):Void {
			sum += value;
			equals(value, vector[index]);
		});
		equals(6, sum);
	}

	function testFilterXmlList() {
		var x = new compat.XML('<root><a id="1"/><b/><a id="2"/></root>');
		var list = x.children();
		var filtered = ASCompat.filterXmlList(list, function(node) return node.name() == "a");
		equals('<a id="1"/>\n<a id="2"/>', filtered.toXMLString());
	}

	function testXmlToList() {
		var x = new compat.XML("<root/>");
		var list = ASCompat.xmlToList(x);
		equals("<root/>", list.toXMLString());
	}

	function testTextFieldGetXMLText() {
		var field = new flash.text.TextField();
		field.text = "abcd";
		#if flash
		var xml = ASCompat.textFieldGetXMLText(field);
		isTrue(xml.indexOf("abcd") != -1);
		#else
		equals("bc", ASCompat.textFieldGetXMLText(field, 1, 3));
		#end
	}

	function testSetIntervalAndTimeoutWithoutExtraArgs() {
		var ranInterval = false;
		var intervalId = ASCompat.setInterval(function() {
			ranInterval = true;
		}, 1000);
		isTrue(intervalId > 0);
		ASCompat.clearInterval(intervalId);
		isFalse(ranInterval);

		var ranTimeout = false;
		var timeoutId = ASCompat.setTimeout(function() {
			ranTimeout = true;
		}, 1000);
		isTrue(timeoutId > 0);
		ASCompat.clearTimeout(timeoutId);
		isFalse(ranTimeout);
	}

	function testPauseForGCIfCollectionImminent() {
		ASCompat.pauseForGCIfCollectionImminent();
		ASCompat.pauseForGCIfCollectionImminent(0.5);
		ASCompat.pauseForGCIfCollectionImminent(-1);
		ASCompat.pauseForGCIfCollectionImminent(2);
		pass();
	}

	function testTypeof() {
		equals("function", ASCompat.typeof(function() {}));
		equals("number", ASCompat.typeof(1));
		equals("boolean", ASCompat.typeof(true));
		equals("string", ASCompat.typeof("test"));
		equals("object", ASCompat.typeof(null));
	}

	function testDescribeTypeBasicContract() {
		var info = ASCompat.describeType(new TestASCompatDescribeTarget());
		equals("type", info.name());
		equals("false", info.attribute("isStatic"));
		isTrue(info.attribute("name").length > 0);

		var classInfo = ASCompat.describeType(TestASCompatDescribeTarget);
		equals("type", classInfo.name());
		equals("true", classInfo.attribute("isStatic"));
		isTrue(classInfo.child("factory").length() == 1);
	}

	#if !flash
	function testDescribeTypeNonFlashMembers() {
		var dynamicObj:ASObject = {
			count: 3,
			run: function() return 1
		};
		var dynamicInfo = ASCompat.describeType(dynamicObj);
		equals("true", dynamicInfo.attribute("isDynamic"));
		isTrue(xmlListHasNodeWithName(dynamicInfo.child("variable"), "count"));
		isTrue(xmlListHasNodeWithName(dynamicInfo.child("method"), "run"));

		var info = ASCompat.describeType(new TestASCompatDescribeTarget());
		isTrue(xmlListHasNodeWithName(info.child("accessor"), "readOnly"));
		isTrue(xmlListHasNodeWithName(info.child("accessor"), "readWrite"));
		isTrue(info.child("extendsClass").length() >= 1);
	}
	#end

	function testAsOperator() {
		equals("test", ASCompat.asString("test"));
		equals(null, ASCompat.asString(123));
		equals(null, ASCompat.asString(function() {}));

		equals(123, ASCompat.asInt(123));
		equals(null, ASCompat.asInt(123.4));
		equals(null, ASCompat.asInt("123"));

		equals(123, ASCompat.asUint(123));
		equals(null, ASCompat.asUint(-1));
		equals(null, ASCompat.asUint(123.4));

		equals(123.4, ASCompat.asNumber(123.4));
		equals(123, ASCompat.asNumber(123));
		equals(null, ASCompat.asNumber("123.4"));

		equals(true, ASCompat.asBool(true));
		equals(false, ASCompat.asBool(false));
		equals(null, ASCompat.asBool(1));

		var xml = new compat.XML("<root/>");
		equals(xml, ASCompat.asXML(xml));
		equals(null, ASCompat.asXML("test"));

		var xmlList = xml.children();
		equals(xmlList, ASCompat.asXMLList(xmlList));
		equals(null, ASCompat.asXMLList(xml));
	}

	function testIsByteArray() {
		var bytes = new flash.utils.ByteArray();
		isTrue(ASCompat.isByteArray(bytes));
		isFalse(ASCompat.isByteArray("test"));
		isFalse(ASCompat.isByteArray(null));
	}

	function testAsByteArray() {
		var bytes = new flash.utils.ByteArray();
		equals(bytes, ASCompat.asByteArray(bytes));
		equals(null, ASCompat.asByteArray("test"));
		equals(null, ASCompat.asByteArray(null));
	}

	function testRestToArray() {
		var empty = ASCompat.restToArray(null);
		equals(0, empty.length);

		var arr = [1, 2];
		var fromArray = ASCompat.restToArray(arr);
		equals(2, fromArray.length);
		equals(1, fromArray[0]);
		equals(2, fromArray[1]);

		var fromToArray = ASCompat.restToArray({
			toArray: function() return [3, 4]
		});
		equals(2, fromToArray.length);
		equals(3, fromToArray[0]);
		equals(4, fromToArray[1]);

		var fromScalar = ASCompat.restToArray(5);
		equals(1, fromScalar.length);
		equals(5, fromScalar[0]);
	}

	function testToString() {
		equals("123", ASCompat.toString(123));
		equals("true", ASCompat.toString(true));
		equals("null", ASCompat.toString(null));
	}

	function testGetQualifiedClassName() {
		equals("int", ASCompat.getQualifiedClassName(123));
		equals("Number", ASCompat.getQualifiedClassName(123.5));
		equals("Boolean", ASCompat.getQualifiedClassName(true));
		equals("String", ASCompat.getQualifiedClassName("test"));
		equals("Array", ASCompat.getQualifiedClassName([1, 2, 3]));
		equals("null", ASCompat.getQualifiedClassName(null));
	}

	function testShowRedrawRegions() {
		ASCompat.showRedrawRegions(false, 0);
		pass();
	}

	function testToNumberField() {
		// Test with existing field - should return the numeric value
		var obj:ASObject = {value: 42};
		floatEquals(42, ASCompat.toNumberField(obj, "value"));

		// Test with existing field "length" on an array
		var arr:Array<Int> = [1, 2, 3];
		floatEquals(3, ASCompat.toNumberField(arr, "length"));

		// Test with non-existing field - should return NaN (not 0)
		floatEquals(Math.NaN, ASCompat.toNumberField(obj, "nonExistent"));

		// Test with null object - should return NaN
		var nullObj:ASObject = null;
		floatEquals(Math.NaN, ASCompat.toNumberField(nullObj, "value"));

		// Test with undefined-like scenario (field access on object without the field)
		var emptyObj:ASObject = {};
		floatEquals(Math.NaN, ASCompat.toNumberField(emptyObj, "missingField"));

		// Test comparison behavior: NaN <= 0 should be false, not true
		// This is the key difference: toNumberField returns NaN for missing fields,
		// while toNumber would return 0 for null
		var result = ASCompat.toNumberField(emptyObj, "length") <= 0;
		isFalse(result);
	}

	function testDynamicPropertyOnMovieClip() {
		var target = new flash.display.MovieClip();
		isFalse(ASCompat.hasProperty(target, "extra"));

		ASCompat.setProperty(target, "extra", 42);
		equals(42, ASCompat.getProperty(target, "extra"));
		isTrue(ASCompat.hasProperty(target, "extra"));

		ASCompat.setProperty(target, "extra", null);
		equals(null, ASCompat.getProperty(target, "extra"));
		isTrue(ASCompat.hasProperty(target, "extra"));

		isTrue(ASCompat.deleteProperty(target, "extra"));
		equals(null, ASCompat.getProperty(target, "extra"));
		isFalse(ASCompat.hasProperty(target, "extra"));

		ASCompat.setProperty(target, "name", "renamed");
		equals("renamed", target.name);
	}

	function testApplyBoundMethod() {
		var target = new TestASCompatApplyTarget();
		var pushed = ASCompatMacro.applyBoundMethod(target, "pushValues", [1, 2, 3]);
		equals(null, pushed);
		equals(3, target.values.length);
		equals(1, target.values[0]);
		equals(3, target.values[2]);

		var sum = ASCompatMacro.applyBoundMethod(target, "sum", [4, 5]);
		equals(9, sum);

		ASCompatMacro.applyBoundMethod(target, "touch", []);
		equals(1, target.touchCount);
	}

	function testDateApi() {
		var dTime = Date.fromTime(0);
		ASCompat.ASDate.setTime(dTime, 1234567);
		floatEquals(1234567, dTime.getTime());

		var dFull = Date.fromTime(0);
		ASCompat.ASDate.setFullYear(dFull, 2020, 1, 2);
		#if (js || flash || python)
		var dFullExpected = Date.fromTime(0);
		untyped dFullExpected.setFullYear(2020, 1, 2);
		floatEquals(dFullExpected.getTime(), dFull.getTime());
		#else
		floatEquals(DateTools.makeUtc(2020, 1, 2, 0, 0, 0), dFull.getTime());
		#end

		var dMonth = Date.fromTime(0);
		ASCompat.ASDate.setMonth(dMonth, 5, 6);
		#if (js || flash || python)
		var dMonthExpected = Date.fromTime(0);
		untyped dMonthExpected.setMonth(5, 6);
		floatEquals(dMonthExpected.getTime(), dMonth.getTime());
		#else
		floatEquals(DateTools.makeUtc(1970, 5, 6, 0, 0, 0), dMonth.getTime());
		#end

		var dDate = Date.fromTime(0);
		ASCompat.ASDate.setDate(dDate, 7);
		#if (js || flash || python)
		var dDateExpected = Date.fromTime(0);
		untyped dDateExpected.setDate(7);
		floatEquals(dDateExpected.getTime(), dDate.getTime());
		#else
		floatEquals(DateTools.makeUtc(1970, 0, 7, 0, 0, 0), dDate.getTime());
		#end

		var dHours = Date.fromTime(0);
		ASCompat.ASDate.setHours(dHours, 8, 9, 10, 11);
		#if (js || flash || python)
		var dHoursExpected = Date.fromTime(0);
		untyped dHoursExpected.setHours(8, 9, 10, 11);
		floatEquals(dHoursExpected.getTime(), dHours.getTime());
		#else
		floatEquals(DateTools.makeUtc(1970, 0, 1, 8, 9, 10) + 11, dHours.getTime());
		#end

		var dMinutes = Date.fromTime(0);
		ASCompat.ASDate.setMinutes(dMinutes, 12, 13, 14);
		#if (js || flash || python)
		var dMinutesExpected = Date.fromTime(0);
		untyped dMinutesExpected.setMinutes(12, 13, 14);
		floatEquals(dMinutesExpected.getTime(), dMinutes.getTime());
		#else
		floatEquals(DateTools.makeUtc(1970, 0, 1, 0, 12, 13) + 14, dMinutes.getTime());
		#end

		var dSeconds = Date.fromTime(0);
		ASCompat.ASDate.setSeconds(dSeconds, 15, 16);
		#if (js || flash || python)
		var dSecondsExpected = Date.fromTime(0);
		untyped dSecondsExpected.setSeconds(15, 16);
		floatEquals(dSecondsExpected.getTime(), dSeconds.getTime());
		#else
		floatEquals(DateTools.makeUtc(1970, 0, 1, 0, 0, 15) + 16, dSeconds.getTime());
		#end

		var dMs = Date.fromTime(0);
		ASCompat.ASDate.setMilliseconds(dMs, 123);
		#if (js || flash || python)
		var dMsExpected = Date.fromTime(0);
		untyped dMsExpected.setMilliseconds(123);
		floatEquals(dMsExpected.getTime(), dMs.getTime());
		floatEquals(untyped dMsExpected.getMilliseconds(), ASCompat.ASDate.getMilliseconds(dMs));
		#else
		floatEquals(123, dMs.getTime());
		floatEquals(123, ASCompat.ASDate.getMilliseconds(dMs));
		#end

		var dUtcMs = Date.fromTime(0);
		#if (js || flash || python)
		untyped dUtcMs.setUTCMilliseconds(321);
		floatEquals(untyped dUtcMs.getUTCMilliseconds(), ASCompat.ASDate.getUTCMilliseconds(dUtcMs));
		#else
		ASCompat.ASDate.setUTCMilliseconds(dUtcMs, 321);
		floatEquals(321, ASCompat.ASDate.getUTCMilliseconds(dUtcMs));
		#end

		var utcValue = ASCompat.ASDate.UTC(2020, 0, 2, 3, 4, 5, 6);
		#if (js || flash || python)
		var utcExpected:Float = untyped Date.UTC(2020, 0, 2, 3, 4, 5, 6);
		floatEquals(utcExpected, utcValue);
		#else
		isTrue(utcValue >= 0 || utcValue <= 0);
		#end
	}

	// Tests for dynamic array methods (dyn*)
	function testDynPush() {
		var arr:Array<Int> = [];
		var len = ASCompat.dynPush(arr, 1);
		equals(1, len);
		equals(1, arr[0]);

		len = ASCompat.dynPush(arr, 2);
		equals(2, len);
		equals(2, arr[1]);
	}

	function testDynPushMultiple() {
		var arr:Array<Int> = [];
		var len = ASCompat.dynPushMultiple(arr, 1, [2, 3]);
		equals(3, len);
		equals(1, arr[0]);
		equals(2, arr[1]);
		equals(3, arr[2]);
	}

	function testDynPop() {
		var arr:Array<Int> = [1, 2, 3];
		var val = ASCompat.dynPop(arr);
		equals(3, val);
		equals(2, arr.length);
	}

	function testDynShift() {
		var arr:Array<Int> = [1, 2, 3];
		var val = ASCompat.dynShift(arr);
		equals(1, val);
		equals(2, arr.length);
		equals(2, arr[0]);
	}

	function testDynUnshift() {
		var arr:Array<Int> = [2, 3];
		var len = ASCompat.dynUnshift(arr, 1);
		equals(3, len);
		equals(1, arr[0]);
	}

	function testDynUnshiftMultiple() {
		var arr:Array<Int> = [3];
		var len = ASCompat.dynUnshiftMultiple(arr, 1, [2]);
		equals(3, len);
		equals(1, arr[0]);
		equals(2, arr[1]);
		equals(3, arr[2]);
	}

	function testDynReverse() {
		var arr:Array<Int> = [1, 2, 3];
		ASCompat.dynReverse(arr);
		equals(3, arr[0]);
		equals(1, arr[2]);
	}

	function testDynSplice() {
		var arr:Array<Int> = [1, 2, 3, 4, 5];
		var removed = ASCompat.dynSplice(arr, 1, 2);
		equals(2, removed.length);
		equals(3, arr.length);
		equals(1, arr[0]);
		equals(4, arr[1]);

		// Test with insertion
		arr = [1, 2, 3];
		removed = ASCompat.dynSplice(arr, 1, 1, [9, 8]);
		equals(1, removed.length);
		equals(4, arr.length);
		equals(1, arr[0]);
		equals(9, arr[1]);
		equals(8, arr[2]);
		equals(3, arr[3]);
	}

	function testDynConcat() {
		var arr:Array<Int> = [1, 2];
		var result:Array<Int> = ASCompat.dynConcat(arr, [3, 4]);
		equals(4, result.length);
		equals(1, result[0]);
		equals(4, result[3]);
		// Original array unchanged
		equals(2, arr.length);
	}

	function testDynJoin() {
		var arr:Array<Int> = [1, 2, 3];
		var str = ASCompat.dynJoin(arr, ",");
		equals("1,2,3", str);
	}

	function testDynSlice() {
		var arr:Array<Int> = [1, 2, 3, 4, 5];
		var result:Array<Int> = ASCompat.dynSlice(arr, 1, 3);
		equals(2, result.length);
		equals(2, result[0]);
		equals(3, result[1]);
	}

	static function xmlListHasNodeWithName(nodes:compat.XMLList, expectedName:String):Bool {
		for (node in nodes) {
			if (node.attribute("name") == expectedName) {
				return true;
			}
		}
		return false;
	}
}

private class TestASCompatSumCtx {
	public var sum:Int = 0;

	public function new() {}

	public function test(value:Int, index:Int, array:Array<Int>):Bool {
		sum += value;
		return value == 2;
	}
}

private class TestASCompatDescribeBase {
	public var baseValue:Int = 10;

	public function new() {}

	public function baseMethod():Int {
		return baseValue;
	}
}

private class TestASCompatDescribeTarget extends TestASCompatDescribeBase {
	public static var staticValue:Int = 42;

	public var value:Int = 7;
	public var readOnly(get, never):Int;
	public var readWrite(get, set):Int;

	var _readWrite:Int = 0;

	public function new() {
		super();
	}

	function get_readOnly():Int {
		return value;
	}

	function get_readWrite():Int {
		return _readWrite;
	}

	function set_readWrite(v:Int):Int {
		_readWrite = v;
		return v;
	}

	public static function staticMethod():Int {
		return staticValue;
	}

	public function instanceMethod():Int {
		return value;
	}
}

private class TestASCompatApplyTarget {
	public var values:Array<Int> = [];
	public var touchCount:Int = 0;

	public function new() {}

	public function pushValues(...rest:Dynamic):Void {
		values = cast rest.toArray();
	}

	public function sum(a:Int, b:Int):Int {
		return a + b;
	}

	public function touch():Void {
		touchCount++;
	}
}

private class TestASCompatComparatorOwner {
	public var bias:Int;
	public var calls:Int = 0;

	public function new(bias:Int) {
		this.bias = bias;
	}

	public function compareInts(a:Int, b:Int):Int {
		calls++;
		return (a + bias) - (b + bias);
	}
}
