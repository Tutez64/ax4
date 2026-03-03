# Quickstart

This guide gets you from zero to a first AS3 -> Haxe conversion.

## Prerequisites

- Java runtime (to execute `converter.jar`)
- Node.js and npm
- Haxe dependencies managed by Lix

## Build the converter

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

For most projects, add this field to copy the compatibility runtime:

```json
"copy": [
  { "unit": "compat", "to": "haxe-out/compat" }
]
```

## Run conversion

```bash
java -jar converter.jar config.json
```

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
