# ax4 documentation

This documentation is for users migrating ActionScript 3 projects to Haxe with `ax4`.

## Start here

1. Read [Quickstart](Quickstart.md)
2. Prepare your `config.json` using [Config reference](Config.md)
3. Compare with [Examples](Examples.md)
4. If conversion fails, check [Troubleshooting](Troubleshooting.md)

## Technical references

- [Filters overview](Filters.md)
- [Contributing](Contributing.md)
- [GitHub wiki setup and sync](Wiki.md)

## Scope

`ax4` behaves more like a compiler than a text converter:

1. Parse AS3 syntax (`ParseTree`)
2. Load SWC declarations
3. Resolve symbols and types (`TypedTree`)
4. Run filter pipeline
5. Generate Haxe modules

The main pipeline lives in `src/ax4/Main.hx`.
