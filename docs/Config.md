# Config reference

`ax4` expects exactly one argument: path to a JSON config file.

```bash
java -jar converter.jar config.json
```

## Required fields

| Key     | Type                   | Description                              |
|---------|------------------------|------------------------------------------|
| `src`   | `string` or `string[]` | AS3 source root(s).                      |
| `hxout` | `string`               | Output directory for generated Haxe.     |
| `swc`   | `string[]`             | SWC files loaded as extern/type sources. |

## Optional fields

| Key                  | Type                             | Default                       | Description                                                                          |
|----------------------|----------------------------------|-------------------------------|--------------------------------------------------------------------------------------|
| `skipFiles`          | `string[]`                       | `null`                        | Exact file paths to skip during source walk.                                         |
| `packagePartRenames` | `{ [name: string]: string }`     | `null`                        | Package segment rename map after normalization.                                      |
| `injection`          | object                           | `null`                        | Configuration used by metadata rewrite filter.                                       |
| `haxeTypes`          | `{ [path: string]: string }`     | `null`                        | Type/signature overrides for SWC declarations.                                       |
| `rootImports`        | `string`                         | `null`                        | File whose content is appended to generated `import.hx`.                             |
| `settings`           | object                           | `{ flashProperties: "none" }` | Filter-specific switches.                                                            |
| `keepTypes`          | `bool`                           | `false`                       | Keep explicit type hints that could be inferred.                                     |
| `dataout`            | `string`                         | `hxout`                       | Output directory for non-AS files copied from `src`.                                 |
| `dataext`            | `string[]`                       | `null`                        | Optional extension allow-list (without dot, example: `["png","xml"]`).               |
| `datafiles`          | `string[]`                       | `null`                        | Optional explicit file allow-list plus explicit extra files to copy.                 |
| `copyNonAs`          | `bool`                           | `true`                        | Copy non-AS files discovered under `src` during walk.                                |
| `unpackout`          | `string`                         | `null`                        | Directory where `library.swf` extracted from SWCs is written.                        |
| `unpackswc`          | `string[]`                       | `null`                        | SWC files to unpack into `unpackout`.                                                |
| `hxoutClean`         | `bool`                           | `false`                       | Delete `hxout` contents before conversion.                                           |
| `dataoutClean`       | `bool`                           | `false`                       | Delete `dataout` contents before conversion (only when `dataout` is explicitly set). |
| `formatter`          | `bool`                           | `false`                       | Run `haxelib run formatter -s <hxout>` after generation.                             |
| `testCloneExpr`      | `bool`                           | `false`                       | Internal diagnostic switch for clone-expression smoke checks.                        |
| `copy`               | `{ unit: string, to: string }[]` | `null`                        | Copy files/directories before conversion.                                            |

## `settings` fields

| Key                 | Type                                   | Default  | Description                                                                       |
|---------------------|----------------------------------------|----------|-----------------------------------------------------------------------------------|
| `checkNullIteratee` | `bool`                                 | `false`  | Adds `ASCompat.checkNullIteratee(...)` guards in rewritten `for...in`/`for each`. |
| `haxeRobotlegs`     | `bool`                                 | `false`  | Enables Robotlegs-specific typing behavior.                                       |
| `flashProperties`   | `"none" \| "externInterface" \| "all"` | `"none"` | Controls `@:flash.property` metadata generation.                                  |

## `injection` object

| Key                | Type       | Required if `injection` is set | Description                                                     |
|--------------------|------------|--------------------------------|-----------------------------------------------------------------|
| `magicInterface`   | `string`   | Yes                            | Fully-qualified interface path.                                 |
| `magicBaseClasses` | `string[]` | Yes                            | Base classes/interfaces exempted from auto-implement injection. |

Example:

```json
{
  "injection": {
    "magicInterface": "my.di.ITypeAware",
    "magicBaseClasses": [
      "my.di.BaseMediator",
      "my.di.BaseCommand"
    ]
  }
}
```

## Non-AS copy behavior

The converter walks `src` recursively:

- `.as` files are parsed and converted.
- Non-AS files are copied according to the rules below.

Rules:

1. Target directory is `dataout` when provided, otherwise `hxout`.
2. `copyNonAs = false` disables copy of non-AS files discovered under `src`.
3. When `copyNonAs = true`:
   - If neither `dataext` nor `datafiles` is provided: all non-AS files from `src` are copied.
   - If `dataext` and/or `datafiles` is provided: only matching files are copied.
4. `datafiles` entries are always copied explicitly to the same target directory.
5. Relative paths are preserved for files inside `src`.

`dataoutClean` note:

- `dataoutClean` only applies when `dataout` is explicitly configured.
- If `dataout` is omitted, non-AS files go to `hxout` and cleanup is controlled by `hxoutClean`.

## `haxeTypes` format

`haxeTypes` keys target SWC declarations:

- Class field: `package.Class.field`
- Getter override: `package.Class.field$get`
- Setter override: `package.Class.field$set`
- Constructor override: `package.Class.new`

Values are parsed as either:

- Type hint: `"Array<Int>"`, `"my.pkg.CustomType"`, `"Dictionary<String, Dynamic>"`
- Signature override: `"p1:Int|p2:String|return:Bool"`

Example:

```json
{
  "haxeTypes": {
    "flash.display.DisplayObject.filters$get": "return:Array<flash.filters.BitmapFilter>",
    "flash.display.DisplayObject.filters$set": "p1:Array<flash.filters.BitmapFilter>"
  }
}
```

## Path and platform notes

- Prefer forward slashes (`/`) in config paths on all platforms.
- `skipFiles` must match the walked file path exactly.
- `unpackout` and `unpackswc` must be used together.
- For `copy`, directory entries are copied recursively; file entries expect `to` as a full destination file path.

## Full example

```json
{
  "src": [
    "project/src",
    "project/generated"
  ],
  "hxout": "out/hx",
  "swc": [
    "lib/playerglobal32_0.swc",
    "lib/FRESteamWorks.swc"
  ],
  "skipFiles": [
    "project/src/legacy/DoNotConvert.as"
  ],
  "packagePartRenames": {
    "floor": "floorpkg"
  },
  "settings": {
    "checkNullIteratee": true,
    "haxeRobotlegs": false,
    "flashProperties": "externInterface"
  },
  "haxeTypes": {
    "flash.display.DisplayObject.filters$get": "return:Array<flash.filters.BitmapFilter>",
    "flash.display.DisplayObject.filters$set": "p1:Array<flash.filters.BitmapFilter>"
  },
  "rootImports": "config/root-imports.hx",
  "keepTypes": true,
  "copy": [
    { "unit": "compat", "to": "out/compat" }
  ],
  "copyNonAs": true,
  "dataout": "out/data",
  "dataext": ["xml", "png", "json"],
  "datafiles": [
    "config/game-config.json"
  ],
  "hxoutClean": true,
  "dataoutClean": true,
  "formatter": true,
  "unpackout": "out/unpacked",
  "unpackswc": [
    "lib/playerglobal32_0.swc"
  ]
}
```
