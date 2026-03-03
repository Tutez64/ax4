# Differences from ax3

This page summarizes the main changes introduced in this fork (`ax4`) compared to upstream `ax3`.
It is a high-level overview based on recent development history (roughly the latest 150 commits), not a line-by-line changelog.

## At a glance

- ax3 was primarily used for HTML5 migration; this fork is primarily optimized for C++ migration while still supporting HTML5.
- Stronger conversion reliability for real-world AS3 code (fewer "unknown identifier/field" and conversion edge-case failures).
- Much broader non-Flash target support, especially C++/hxcpp-oriented compatibility behavior.
- Significant expansion of compatibility runtime (`compat/`) and tests (`compat-test/`).
- Better handling of dynamic access, dictionary/object semantics, XML/E4X patterns, arrays/vectors, and coercions.
- More practical project tooling/docs (new docs set, troubleshooting guidance, wiki sync workflow).

## Converter and filter improvements

Main areas improved in typing/filtering/generation:

- Dynamic property access and assignments:
  - safer rewrites for reads/writes/compound assignments on dynamic values
  - improved `hasOwnProperty` handling and undefined lookup rewrites
- Type inference and coercions:
  - better local inference in loops and cyclic flows
  - improved numeric/bitwise coercions and Any/Object conversions
- Class/constructor handling:
  - fixes for ctor initialization ordering and super-call placement
  - better handling of class casts and `new` on dynamic/callable values
- API-specific rewrites:
  - improvements for Array/Vector APIs, function apply/call, URL loading patterns, Embed handling, flash/global utility shims
- E4X/XML support:
  - expanded parser/filter/runtime handling for XML/XMLList and related patterns

## Runtime compatibility layer (`compat/`)

`compat/` has grown substantially and now covers more AS3 behavior used by converted output, including:

- `ASAny`, `ASDictionary`, `ASArrayBase`, `ASProxyBase` behavior refinements
- non-Flash parity for dynamic/property access semantics
- additional XML/XMLList, RegExp, describeType, ByteArray, and related utility behavior

`compat-test/` includes dedicated tests for this layer and should be updated together with runtime changes.

## Target support and portability

Compared to baseline ax3 usage, target priorities are different:

- Primary focus: C++/hxcpp migration and runtime parity.
- Secondary but still supported target: HTML5.

To support that, this fork includes more explicit effort toward non-Flash portability:

- multiple fixes targeting C++/hxcpp behavior
- fallback paths for non-Flash runtime semantics
- adjustments to avoid target-specific pitfalls (closure binding, varargs wrapping, numeric corner cases)

## Configuration and workflow changes

Notable workflow/config changes include:

- project renamed to `ax4`
- non-AS asset handling improvements:
  - `copyNonAs` option (default `true`)
  - `dataout` fallback behavior and filtering with `dataext` / `datafiles`
- added docs structure under `docs/` and one-way wiki sync

## Migration notes for ax3 users

If you are coming from ax3:

1. Read [Quickstart](Quickstart.md) and [Config reference](Config.md) first.
2. Ensure `compat/` is included in your target project.
3. Re-check any custom assumptions around dynamic behavior, array/vector helpers, and XML/E4X conversions.
4. If output still fails to compile, use [Troubleshooting](Troubleshooting.md) and reduce to a repro in `tests/src/`.
