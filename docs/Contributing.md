# Contributing and tests

## Build

```bash
npm i lix
npx lix download
npx haxe build.hxml
```

`npx haxe run.hxml` also builds `run.n`, which `haxelib run ax4` needs when the clone is installed with `haxelib dev ax4 .`.

## Run converter on test workspace

```bash
java -jar converter.jar tests/config.json
```

## Compatibility tests

```bash
npx haxe test-compat.hxml
```

`compat/` is the runtime compatibility layer used by converted projects.
`compat-test/` is its test suite, run on JS (Node), C++ (libhxcpp) and Flash (`test.swf`, opened with the system's Flash Player). `test.swf` traces its results, which the Flash Player content debugger writes to `~/.macromedia/Flash_Player/Logs/flashlog.txt` when `~/mm.cfg` has `TraceOutputFileEnable=1`. When you change anything in `compat/`, update tests in `compat-test/` and run `npx haxe test-compat.hxml`.

## Test case conventions

- Put AS3 input in `tests/src/`.
- Generated Haxe goes to `tests/out/`.
- Every test source file should explain case and expected behavior in comments.
- Filter tests naming convention:
  - `TestFilter{FilterName}.as`
  - Example: `RewriteAs.hx` -> `TestFilterRewriteAs.as`
- Other tests can use `Test{Feature}.as`.

`tests/` is checked by inspecting `tests/out`. The two suites below run converted code and compare what it prints.

## Converted AS3 run against Flash

`tests-as3/` checks that converted code behaves as in Flash Player.

- `src/checks/` holds AS3 checks that push `name=value` lines.
- `tests-as3/build.sh <air-sdk> <flashplayerdebugger>` compiles them with the AIR SDK's mxmlc, turns its ABC 47.16 into the 46.16 that Flash Player 32 reads (`abc46.py`), runs them in the Flash Player projector content debugger and writes its traces to `expected.txt`. Rerun it after changing `src/`.
- `npx haxe test-as3.hxml` converts them, then runs the converted checks against `expected.txt` on JS and C++.
- `known-js.txt` and `known-cpp.txt` list, as printed, the lines where a target is known to differ from Flash. Another difference fails, and so does a listed line that is no longer printed: update the list when a fix changes it.
- Forms ax4 stops on are left out, with a comment saying so.

## Code compiled with Haxe

`tests-haxe/` covers [programs compiled with Haxe](Config.md#programs-compiled-with-haxe).

- `hx/` holds Haxe sources. `tests-haxe/build.sh <ffdec.jar>` compiles them to a SWC, decompiles it with JPEXS FFDec and splits it into `src/`, `src-bytecode/` and `lib/bytecode.swc` as a decompiled game would be, and writes `expected.txt` from the Haxe sources (`--interp`). Rerun it after changing `hx/`.
- `npx haxe test-haxe.hxml` converts them, then runs the converted checks against `expected.txt` on JS and C++.
- Their inputs are real Haxe output, so the filters' reports of unhandled forms are not triggered there.

## Error coverage policy

- Non-blocking `reportError` paths should be intentionally covered by tests.
- Do not trigger `throwError` in normal conversion/regression suites because it aborts the converter.
- Add dedicated negative tests for `throwError` paths only when you are explicitly working on that specific failure mode.
- If a `reportError` path effectively throws in practice, treat it as a throw case.

## Suggested workflow for a bug fix

1. Reproduce with smallest possible AS3 sample under `tests/src/`.
2. Run converter and inspect `tests/out/`.
3. Implement filter/typer/gen fix.
4. Re-run converter.
5. Run `npx haxe test-compat.hxml` if compat/runtime was touched, and `npx haxe test-as3.hxml` and `npx haxe test-haxe.hxml`.

## Auditing compat calls in a converted project

`tools/CompatAudit.hx` counts the `ASCompat`/`ASAny` calls of a converted project by static argument types, so coercions on already-typed values (`toInt(Int)`, `toNumber(Float)`...) show up as converter work. Usage is in its header comment.

## Releasing

Set `version` and `releasenote` in `haxelib.json`, commit, then push a matching `vX.Y.Z` tag. The Release workflow rebuilds `converter.jar` and `run.n`, converts the test workspace, submits the package to lib.haxe.org (repository secret `HAXELIB_PASSWORD`) and attaches it to a GitHub release. Running the workflow by hand builds the package without publishing it.
