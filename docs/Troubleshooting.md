# Troubleshooting

## `invalid args`

Cause:

- Converter expects exactly one CLI argument.

Fix:

```bash
java -jar converter.jar config.json
```

## `<field> not set` (`src`, `hxout`, `swc`)

Cause:

- Required config field missing.

Fix:

- Add all required keys to `config.json`.
- Validate JSON syntax.

## `no library.swf found`

Cause:

- File in `swc` is not a valid SWC archive (or wrong file path).

Fix:

- Verify the file is an SWC.
- Verify path and slash style.

## Files are unexpectedly skipped or not skipped

Cause:

- `skipFiles` uses exact path matching.

Fix:

- Use exact walked file path format.
- Prefer forward slashes in config values.

## Haxe output has too many or too few explicit type hints

Cause:

- `keepTypes` influences type hint omission in generated vars.

Fix:

- Set `"keepTypes": true` to preserve hints.
- Set `"keepTypes": false` (or omit) to allow cleaner inferred output.

## `for...in` / `for each` behavior differs

Cause:

- Loop rewrite depends on inferred iteratee type and `settings.checkNullIteratee`.

Fix:

- Try enabling/disabling `settings.checkNullIteratee`.
- Inspect generated imports for `ASCompat.checkNullIteratee`.

## Conversion succeeds but generated project does not compile

Typical symptoms:

- `Type not found` / `Unknown identifier` in generated `.hx`
- Missing members after conversion (`field ... is not found`)
- Errors around AS3 runtime concepts (`Dictionary`, XML, dynamic access, Proxy-like behavior)
- Missing classes from external SDKs/extensions

Common causes and fixes:

1. Pattern not handled (or partially handled) by current filters
   - Cause: generated Haxe is syntactically valid, but semantic rewrite is incomplete for this AS3 construct.
   - Fix:
     - Reduce to the smallest reproducible AS3 sample in `tests/src/`.
     - Name it according to conventions (`TestFilter...` for filter-specific cases).
     - Add comments describing expected output/behavior.
     - Implement or adjust filter/typer logic, then re-run converter.

2. `compat/` runtime not included in the target Haxe project
   - Cause: converted code references compatibility helpers that are not on classpath.
   - Fix:
     - Copy/include `compat/` in your output project (for example via `copy` config option).
     - Ensure the build classpath includes that folder.
     - If `compat/` was modified, run compatibility tests:

```bash
npx haxe test-compat.hxml
```

3. External dependency mismatch (SWC / ANE / platform libs)
   - Cause: conversion used SWC declarations, but compile target does not provide equivalent Haxe-side types/runtime.
   - Fix:
     - Verify required SWCs are listed in converter config (`swc`) so typing is correct.
     - Verify target project has corresponding Haxe libraries/externs.
     - For ANE/native APIs, provide or adapt extern wrappers on the Haxe side.

4. Project integration mismatch after generation
   - Cause: generated sources compile in isolation but fail in the real project due to classpath/import/config differences.
   - Fix:
     - Compare your real project settings with the minimal test setup.
     - Check generated `import.hx` and `rootImports` usage.
     - Use `haxeTypes` overrides when specific external signatures need correction.

Recommended diagnostic workflow:

1. Fix the first compile error first (later errors are often cascades).
2. Open the generated `.hx` line reported by compiler and map it back to source AS3.
3. Classify the issue quickly:
   - missing compat,
   - missing extern/library,
   - unsupported rewrite pattern.
4. If it is a converter issue, create a focused repro in `tests/src/` and iterate there before patching production code.

## Formatter step fails silently

Cause:

- `formatter` option shells out to `haxelib run formatter` and does not hard-fail conversion output.

Fix:

- Run formatter manually to inspect errors.
- Ensure formatter is installed and available to `haxelib`.
