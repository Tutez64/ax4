# Filters overview

Filters run after typing, in a fixed sequence declared in `src/ax4/Filters.hx`.

## Why filters matter

AS3 and Haxe are close but not equivalent. Filters bridge semantic and API gaps, for example:

- `for...in` / `for each` rewrites
- Metadata conversion (`[Inject]`, `[Embed]`, etc.)
- API remaps (`Math`, `Date`, `String`, `Array`, display classes)
- Cast normalization and type coercion
- Import and override fixes

## Pipeline characteristics

- Order is significant.
- Some filters are diagnostic and only report issues.
- Some filters are compatibility-oriented and introduce helpers/imports.
- `testCloneExpr` inserts extra smoke filters before and after rewrites.

## Main filter families

1. Early structural and safety passes
2. Expression and syntax rewrites
3. Type and cast normalization
4. API adaptation filters
5. Late consistency fixes (overrides, imports, redundant parenthesis)

## Reading the active list

The canonical source of truth is `src/ax4/Filters.hx`.

Each filter implementation is in `src/ax4/filters/`.

When debugging a behavior change:

1. Locate the responsible filter in `Filters.hx`
2. Open corresponding file in `src/ax4/filters/`
3. Add a minimal test in `tests/src`
4. Re-run conversion with `tests/config.json`
