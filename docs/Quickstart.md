# Quickstart

This guide gets you from zero to a first AS3 -> Haxe conversion.

## Prerequisites

- Java runtime (the converter is `converter.jar`)
- Haxe and haxelib, to install it from lib.haxe.org
- Node.js and npm, only to build it from source (Haxe dependencies are managed by Lix)

## Install

From lib.haxe.org:

```bash
haxelib install ax4
```

Or build it from source in a clone of this repository:

```bash
npm i lix
npx lix download
npx haxe build.hxml
```

Expected output: `converter.jar`.

## Minimal project layout

Example:

```text
my-project/
  as3-src/
  lib/
    playerglobal.swc
  config.json
```

## Minimal `config.json`

```json
{
  "src": "as3-src",
  "hxout": "haxe-out",
  "swc": [
    "lib/playerglobal.swc"
  ]
}
```

Use forward slashes (`/`) in paths even on Windows.

The converted code needs the compatibility runtime (`compat/`). With the haxelib install, add `-lib ax4` to your Haxe build. Otherwise, add this field to copy it next to the output:

```json
"copy": [
  { "unit": "path/to/ax4/compat", "to": "haxe-out/compat" }
]
```

## Run conversion

From the project directory:

```bash
haxelib run ax4 config.json
```

With a source build, run the jar instead:

```bash
java -jar path/to/ax4/converter.jar config.json
```

Either way, paths in `config.json` are relative to the directory you run it from.

The converter will:

1. Parse `.as` files under `src`
2. Type and rewrite code
3. Write `.hx` files into `hxout`
4. Copy non-AS assets from `src` into `dataout` (or `hxout` when `dataout` is not set)

## Typical iteration loop

1. Run converter
2. Fix unsupported AS3 constructs or add targeted rewrites
3. Re-run converter
4. Compile generated Haxe project

## Next

- Use [Config reference](Config.md) for all options
- Use [Examples](Examples.md) for practical templates
- Use [Troubleshooting](Troubleshooting.md) for common failures
