# ax4

ax4 is an ActionScript 3 to Haxe converter that tries to be very smart and precise about rewriting code.
To achieve that, it actually resembles the typical compiler a lot, so here's how it works:

- parse AS3 modules into the ParseTree structure, containing all the syntactic information
- load classes and signatures from the SWC libraries so we have the external type information
- process ParseTree and build the TypedTree, resolving all imports and type references and assigning type to every piece of code
- run a sequence of "filters" which analyze and re-write the TypedTree structures to adapt the code for Haxe
- generate Haxe modules from the processed TypedTree

## Disclaimer

This is a fork of [ax3](https://github.com/innogames/ax3) and [this other fork](https://github.com/addreality/ax3).
My initial goal is to make a fully working (fan-made) [Dungeon Rampage](https://store.steampowered.com/app/3053950/Dungeon_Rampage/) C++ version, after which I would like to convert another game and to keep this project alive, but since I'm doing it in my free time, this isn't a guarantee.

## Quick start

### 1) Prerequisites

- Java runtime (to run `converter.jar`)
- Node.js + npm (for Lix-based Haxe toolchain setup)

### 2) Build

```bash
npm i lix
npx lix download
npx haxe build.hxml
```

This produces `converter.jar`.

### 3) Create a minimal `config.json`

```json
{
  "src": "path/to/as3/src",
  "hxout": "path/to/haxe/out",
  "swc": [
    "path/to/playerglobal.swc"
  ]
}
```

### 4) Run conversion

```bash
java -jar converter.jar config.json
```

## Documentation

- [Home](docs/Home.md)
- [Quickstart](docs/Quickstart.md)
- [Config reference](docs/Config.md)
- [Config examples](docs/Examples.md)
- [Differences from ax3](docs/ForkDifferences.md)
- [Filters overview](docs/Filters.md)
- [Troubleshooting](docs/Troubleshooting.md)
- [Contributing](docs/Contributing.md)
- [GitHub wiki setup and sync](docs/Wiki.md)

## Compat runtime

- `compat/` contains AS3 compatibility/runtime helpers used by generated Haxe code (`ASAny`, `ASDictionary`, XML helpers, etc.).
- In most real migrations, converted code depends on this layer. Plan to include/copy `compat/` into your Haxe project.
- `compat-test/` contains tests for the compatibility layer itself and is not meant to be shipped with production output.
- If you modify `compat/`, update `compat-test/` and run:

```bash
npx haxe test-compat.hxml
```

## Conversion Pipeline

The pipeline is implemented in `src/ax4/Main.hx`:

1. Parse AS3 into `ParseTree`
2. Load SWC externs/signatures
3. Type into `TypedTree`
4. Run rewrite filters
5. Generate Haxe modules

## Known limitations

- The parser doesn't currently support ASI (automatic semicolon insertion). The only case where a semicolon can be omitted is the last expression of a block.
- Only a small, most commonly used subset of E4X is supported. It's recommended to rewrite the unsupported things in AS3 sources to adapt it for conversion.

## TODO (probably outdated)

Most of the `TODO`s are actually in the code, so look there too, but still:

- don't parse `*=` as a single token when parsing signatures (fix `a:*=b` parsing without spaces)
- add a "final-step" filter to remove redundant `TEHaxeRetype`s too
- rewrite `arr[arr.length] = value` to `arr.push(value)`
- generate "type patch" files for loaded SWCs, replacing `Object` with `ASObject` and `*` with `ASAny`
- review and cleanup `ASCompat` - rework some things as static extensions (e.g. Vector/Array compat methods)
- add some more empty ctors to work around https://github.com/HaxeFoundation/haxe/issues/8531
- add configuration options for some things (like omitting type hints and `private` keywords)
- fix imports
- add imports for fully-qualified names that can come from `@haxe-type`
- remove duplicate imports (can happen when merging in out-of-package imports)
- maybe add `inline` for arithmetic ops in static var inits where all operands are also static inline
- remove `public` from `@:inject`/`@:postConstruct`/`@:preDestroy` as these should not really be part of public API
