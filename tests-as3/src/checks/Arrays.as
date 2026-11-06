package checks {
	/** Array and Vector methods, holes, sorting and iteration. */
	public class Arrays {
		public static function run(out:Array):void {
			var nested:Array = [[5]];
			var joined:Array = [1].concat([2, 3], 4, nested);
			var untyped:* = [6, 7];
			var fromObject:Object = [8];
			out.push("concat=" + joined.length + "," + joined.join("|") + "," + [0].concat(untyped).length + "," + [0].concat(fromObject).length + "," + [0].concat().length);
			var a:Array = [1, 2, 3, 4];
			var removed:Array = a.splice(1, 2, "x", "y", "z");
			out.push("splice=" + a.join(",") + "|" + removed.join(",") + "|" + a.slice(-2).join(",") + "|" + a.slice(1, -1).join(","));
			out.push("indexOf=" + [1, "1", NaN].indexOf("1") + "," + [NaN].indexOf(NaN) + "," + [1, 2, 1].lastIndexOf(1) + "," + [null].indexOf(undefined));
			out.push("sort=" + [10, 9, 1].sort().join(",") + "|" + [10, 9, 1].sort(Array.NUMERIC).join(",") + "|" + [10, 9, 1].sort(Array.NUMERIC | Array.DESCENDING).join(",")
				+ "|" + ["b", "A", "c"].sort(Array.CASEINSENSITIVE).join(",") + "|" + [3, 1, 2].sort(function(x:int, y:int):int { return y - x; }).join(","));
			var records:Array = [{n: "b", v: 2}, {n: "a", v: 10}, {n: "c", v: 1}];
			records.sortOn("v", Array.NUMERIC);
			var byName:Array = records.concat();
			byName.sortOn("n");
			out.push("sortOn=" + records.map(function(r:Object, ... rest):String { return r.n; }).join("") + "," + byName[0].n);
			var holes:Array = [1];
			holes.length = 3;
			var sparse:Array = [];
			sparse[4] = "e";
			out.push("holes=" + holes.join(",") + "|" + holes.length + "|" + sparse.length + "|" + (sparse[0] === undefined) + "|" + sparse.join("."));
			var stack:Array = [1, 2];
			out.push("stack=" + stack.pop() + "," + stack.shift() + "," + stack.shift() + "," + stack.pop() + "," + stack.push(3, 4) + "," + stack.unshift(0) + "," + stack.reverse().join(""));
			out.push("toString=" + [[1, 2], [3]].toString() + "|" + [undefined, null, 0].join(",") + "|" + [true, "s", 1.5]);
			var ints:Vector.<int> = new Vector.<int>(3);
			ints.push(1.7);
			var nums:Vector.<Number> = new Vector.<Number>(2);
			var strs:Vector.<String> = new Vector.<String>(2);
			var objs:Vector.<Object> = new Vector.<Object>(1);
			out.push("vector=" + ints.join(",") + "|" + nums.join(",") + "|" + strs.join(",") + "|" + objs.join(",") + "|" + ints.indexOf(1) + "|" + ints.length);
			var vec:Vector.<String> = Vector.<String>(["b", "a"]);
			vec.sort(0);
			var fixedLength:Vector.<int> = new Vector.<int>(2, true);
			var fixedFailed:Boolean = false;
			try {
				fixedLength.push(1);
			} catch (e:RangeError) {
				fixedFailed = true;
			}
			out.push("vectorMore=" + vec.join("") + "," + vec.concat(Vector.<String>(["c"])).join("") + "," + fixedFailed + "," + vec.slice(1).join(""));
			var squares:Array = [1, 2, 3].map(function(x:int, i:int, all:Array):int { return x * x + i; });
			var evens:Array = [1, 2, 3, 4].filter(function(x:int, ... rest):Boolean { return x % 2 == 0; });
			var sum:int = 0;
			var addAll:Array = [1, 2, 3];
			addAll.forEach(function(x:int, ... rest):void { sum += x; });
			out.push("callbacks=" + squares.join(",") + "|" + evens.join(",") + "|" + sum + "|" + [1, 2].every(function(x:int, ... rest):Boolean { return x > 0; })
				+ "|" + [1, 2].some(function(x:int, ... rest):Boolean { return x > 1; }));
			var keys:Array = [];
			var values:Array = [];
			var arr:Array = ["p", "q"];
			for (var k:String in arr) {
				keys.push(k);
			}
			for each (var value:String in arr) {
				values.push(value);
			}
			keys.sort();
			out.push("iterate=" + keys.join(",") + "|" + values.join(","));
			var grid:Array = [[1, 2], [3, 4]];
			grid[1][0] += 10;
			var counts:Array = [0];
			counts[0]++;
			out.push("nestedWrite=" + grid.join(";") + "," + counts[0]);
		}
	}
}
