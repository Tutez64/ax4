# Config examples

These examples are intentionally practical. Start from one and adapt.

## Minimal conversion

```json
{
  "src": "src-as3",
  "hxout": "src-hx",
  "swc": [
    "lib/playerglobal32_0.swc"
  ]
}
```
All non-AS files found under src are copied into hxout (same relative paths).


## Multiple source roots

```json
{
  "src": [
    "project/src",
    "project/generated"
  ],
  "hxout": "out/hx",
  "swc": [
    "lib/playerglobal32_0.swc"
  ]
}
```

## Project with compat copy and package rename

```json
{
  "src": "C:/work/game/src",
  "hxout": "C:/work/game-haxe/src",
  "copy": [
    { "unit": "compat", "to": "C:/work/game-haxe/compat" }
  ],
  "swc": [
    "lib/airglobal.swc",
    "lib/FRESteamWorks.swc"
  ],
  "packagePartRenames": {
    "floor": "game_floor"
  },
  "settings": {
    "checkNullIteratee": true
  }
}
```

All non-AS files found under `src` are copied into `hxout` (same relative paths).

## Non-AS copy redirected to `dataout`

```json
{
  "src": "src-as3",
  "hxout": "out/hx",
  "swc": [
    "lib/playerglobal32_0.swc"
  ],
  "dataout": "out/data"
}
```

All non-AS files from `src` are copied into `out/data` instead of `out/hx`.

## Filtered non-AS copy (`dataext` and `datafiles`)

```json
{
  "src": "src-as3",
  "hxout": "out/hx",
  "swc": [
    "lib/playerglobal32_0.swc"
  ],
  "dataout": "out/data",
  "dataext": ["xml", "png", "json"],
  "datafiles": [
    "config/live-ops.json"
  ]
}
```

Only non-AS files matching `dataext` and/or listed in `datafiles` are copied.

## Disable non-AS copy from `src`

```json
{
  "src": "src-as3",
  "hxout": "out/hx",
  "swc": [
    "lib/playerglobal32_0.swc"
  ],
  "copyNonAs": false
}
```

This restores the old behavior where non-AS files discovered under `src` are ignored.

## SWC type overrides (`haxeTypes`)

```json
{
  "src": "src-as3",
  "hxout": "out/hx",
  "swc": [
    "lib/playerglobal32_0.swc"
  ],
  "haxeTypes": {
    "flash.display.DisplayObject.filters$get": "return:Array<flash.filters.BitmapFilter>",
    "flash.display.DisplayObject.filters$set": "p1:Array<flash.filters.BitmapFilter>"
  }
}
```

## Root imports aggregation

`root-imports.hx`:

```haxe
import my.runtime.Globals;
using my.runtime.Extensions;
```

`config.json`:

```json
{
  "src": "src-as3",
  "hxout": "out/hx",
  "swc": ["lib/playerglobal32_0.swc"],
  "rootImports": "root-imports.hx"
}
```

This content is appended to generated `out/hx/import.hx` under `#if !macro`.
