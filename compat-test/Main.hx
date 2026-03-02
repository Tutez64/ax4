class Main {
	static function main() {
		var runner = new utest.Runner();
		for (testCase in [
			new TestASAny(),
			new TestXML(),
			new TestASCompat(),
			new TestASArrayBase(),
			new TestASDictionary(),
			new TestASProxyBase(),
			new TestRegExp(),
		]) {
			runner.addCase(testCase);
		}

		#if flash
		FlashTestOutput.install(runner);
		new utest.ui.text.PrintReport(runner);
		#else
		utest.ui.Report.create(runner);
		#end
		runner.run();
	}
}

#if flash
private class FlashTestOutput {
	static var tf = new flash.text.TextField();
	static var progressToken = 0;
	static var done = false;

	public static function install(runner:utest.Runner):Void {
		var current = flash.Lib.current;
		tf.defaultTextFormat = new flash.text.TextFormat("_sans", 12, 0x111111);
		tf.multiline = true;
		tf.wordWrap = true;
		tf.selectable = true;
		tf.background = true;
		tf.backgroundColor = 0xF2F2F2;
		tf.border = true;
		tf.borderColor = 0x999999;
		tf.x = 8;
		tf.y = 8;
		tf.width = current.stage != null ? Math.max(200, current.stage.stageWidth - 16) : 1000;
		tf.height = current.stage != null ? Math.max(120, current.stage.stageHeight - 16) : 700;
		current.addChild(tf);

		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos):Void {
			tf.text += infos.className + ":" + infos.lineNumber + ": " + v;
		};

		runner.onTestStart.add(function(handler):Void {
			var currentTest = Type.getClassName(Type.getClass(handler.fixture.target)) + '.' + handler.fixture.method;
			var token = ++progressToken;
			haxe.Timer.delay(function():Void {
				if (token == progressToken && !done) {
					tf.text += 'Fatal error? Stalled on ' + currentTest;
				}
			}, 100);
		});

		runner.onComplete.add(function(_):Void { done = true; });
	}
}
#end
