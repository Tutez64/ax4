# ax4

ax4 is an ActionScript 3 to Haxe converter that tries to be very smart and precise about rewriting code.
To achieve that, it actually resembles the typical compiler a lot, so here's how it works:

- parse AS3 modules into the ParseTree structure, containing all the syntactic information
- load classes and signatures from the SWC libraries so we have the external type information
- process ParseTree and build the TypedTree, resolving all imports and type references and assigning type to every piece of code
- run a sequence of "filters" which analyze and re-write the TypedTree structures to adapt the code for Haxe
- generate Haxe modules from the processed TypedTree

## Disclaimer

ax4 is a fork of [ax3](https://github.com/innogames/ax3), created by Dan Korostelev ([nadako](https://github.com/nadako)) at InnoGames, by way of [another fork](https://github.com/addreality/ax3).
I developed ax4 to make a fan-made native port of [Dungeon Rampage](https://store.steampowered.com/app/3053950/Dungeon_Rampage/) (see [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe)).

I may or may not continue to maintain ax4, and port other games in the future.

## Quick start

### 1) Install

With a Java runtime and haxelib:

```bash
haxelib install ax4
```

To build it from source instead, see [Quickstart](https://github.com/Tutez64/ax4/wiki/Quickstart).

### 2) Create a minimal `config.json`

```json
{
  "src": "path/to/as3/src",
  "hxout": "path/to/haxe/out",
  "swc": [
    "path/to/playerglobal.swc"
  ]
}
```

### 3) Run conversion

```bash
haxelib run ax4 config.json
```

## Documentation

- [Home](https://github.com/Tutez64/ax4/wiki)
- [Quickstart](https://github.com/Tutez64/ax4/wiki/Quickstart)
- [Config reference](https://github.com/Tutez64/ax4/wiki/Config)
- [Config examples](https://github.com/Tutez64/ax4/wiki/Examples)
- [Differences from ax3](https://github.com/Tutez64/ax4/wiki/ForkDifferences)
- [Filters overview](https://github.com/Tutez64/ax4/wiki/Filters)
- [Diagnostics catalogue](https://github.com/Tutez64/ax4/wiki/Diagnostics)
- [Troubleshooting](https://github.com/Tutez64/ax4/wiki/Troubleshooting)
- [Contributing](https://github.com/Tutez64/ax4/wiki/Contributing)
- [GitHub wiki setup and sync](https://github.com/Tutez64/ax4/wiki/Wiki)

## Compat runtime

- `compat/` contains AS3 compatibility/runtime helpers used by generated Haxe code (`ASAny`, `ASDictionary`, XML helpers, etc.).
- Converted code depends on this layer: with the haxelib install, add `-lib ax4` to your Haxe build; otherwise copy `compat/` with the `copy` option (see [Quickstart](https://github.com/Tutez64/ax4/wiki/Quickstart)).
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
- XML literals (`<a>...</a>`) are not supported: `skipXmlLiterals` comments them out as `null`.
