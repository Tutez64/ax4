# Contributing and tests

## Build

```bash
npm i lix
npx lix download
npx haxe build.hxml
```

## Run converter on test workspace

```bash
java -jar converter.jar tests/config.json
```

## Compatibility tests

```bash
npx haxe test-compat.hxml
```

`compat/` is the runtime compatibility layer used by converted projects.
`compat-test/` is its test suite. When you change anything in `compat/`, update tests in `compat-test/` and run `npx haxe test-compat.hxml`.

## Test case conventions

- Put AS3 input in `tests/src/`.
- Generated Haxe goes to `tests/out/`.
- Every test source file should explain case and expected behavior in comments.
- Filter tests naming convention:
  - `TestFilter{FilterName}.as`
  - Example: `RewriteAs.hx` -> `TestFilterRewriteAs.as`
- Other tests can use `Test{Feature}.as`.

Current state:

- Most converter tests are still manual/inspection-based (`tests/src` -> run converter -> inspect `tests/out`).

Future direction:

- Move toward automated checks (expected output diff, compile smoke tests, and execution tests where relevant) so regressions are caught in CI.

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
5. Run `npx haxe test-compat.hxml` if compat/runtime was touched.
