# ax4 Codebase Guide for AI Agents

## Overview
ax4 is an ActionScript 3 (AS3) to Haxe converter. It functions similarly to a compiler: parsing AS3 code, resolving types (including from SWC libraries), applying transformation filters, and generating Haxe code.

## Architecture
The conversion pipeline is sequential and defined in `src/ax4/Main.hx`:
1. **Parsing**: AS3 source files are parsed into a `ParseTree` via the typing pass (`Typer.process`), which uses `src/ax4/Parser.hx` internally.
2. **SWC Loading**: External types are loaded from SWC files into the `TypedTree` (`src/ax4/SWCLoader.hx`).
3. **Typing**: The `ParseTree` is processed into a `TypedTree`, resolving imports and types (`src/ax4/Typer.hx`, `src/ax4/ExprTyper.hx`).
4. **Filtering**: A series of filters modify the `TypedTree` to adapt AS3 patterns to Haxe (`src/ax4/Filters.hx`).
5. **Generation**: Haxe code is generated from the modified `TypedTree` (`src/ax4/GenHaxe.hx`).

### Key Data Structures
*   **ParseTree** (`src/ax4/ParseTree.hx`): Represents the raw AST of AS3 code.
*   **TypedTree** (`src/ax4/TypedTree.hx`): A semantic graph of the code with resolved types and symbols. This is the primary structure manipulated by filters.
*   **Token** (`src/ax4/Token.hx`): Represents lexical tokens, preserving whitespace/comments (trivia) for high-fidelity code generation.

## Critical Workflows

### Building
*   **Command**: `npx haxe build.hxml`
*   **Output**: `converter.jar` (JVM target).
*   **Dependencies**: Requires `lix` for Haxe version management (`npm i lix`, `npx lix download`).

### Running
*   **Command**: `java -jar converter.jar config.json`
*   **Config**: JSON file specifying `src` (AS3 sources), `hxout` (Haxe output dir), and `swc` (libraries).
    *   **Optional**: `haxeTypes`, `dataout`, `rootImports`.

### Testing
*   **Compat Tests**: `npx haxe test-compat.hxml` runs compatibility tests (JS then SWF via `--next`).
    *   Validates the `compat/` library (ASAny, ASDictionary, XML, etc.).
*   **Playground/Repro Tests**: `tests/` directory.
    *   Use this folder to create isolated reproduction cases for converter bugs or features.
    *   Structure: `tests/src/` (AS3 input), `tests/out/` (Haxe output), `tests/config.json`.
    *   **Requirement**: Each test file in `tests/src/` **must** include comments explaining the test case and expected behavior (see `tests/src/TestFilterRedundantSuperCtorCall.as` for example).
    *   **Naming**: `tests/src` files for filters must be named `TestFilter{FilterName}.as` (e.g. `src/ax4/filters/RewriteAs.hx` -> `tests/src/TestFilterRewriteAs.as`). Other tests should follow `Test{Feature}.as`.
    *   **Error coverage**: Tests should intentionally trigger every non-blocking `reportError` produced by filters; only `throwError` cases are allowed to remain untested until explicitly targeted.
    *   **`reportError` that throws**: If triggering a `reportError` effectively causes a `throw` (as observed in practice), treat it as a `throwError` case — do not trigger it in tests unless explicitly requested.
    *   **Compat changes**: You may update `compat/` when needed, but you must update `compat-test/` accordingly and verify with `npx haxe test-compat.hxml`.
    *   Run: `java -jar converter.jar tests/config.json`.

### Debugging
*   **Debugging**: `src/ax4/ParseTreeDump.hx` can dump ASTs. `TypedTree.dump()` can visualize the semantic tree.

## Project Patterns & Conventions

### Language & Versioning
*   **Language**: All code, filenames, and comments must be in **English**.
    *   *Exception*: Respond to the user in their preferred language (e.g., French) to facilitate communication.
*   **Haxe Version**: The project uses **Haxe 4.3.7**.
    *   Write modern code compatible with **Haxe 5.0.0**.
    *   Be aware that existing code may be legacy and not reflect current best practices.

### AST & Typing
*   **Trivia Preservation (Crucial)**: The parser attaches leading/trailing whitespace/comments to tokens (`Token.leadTrivia`, `Token.trailTrivia`).
    *   **Rule**: Transformations **must** preserve these to maintain formatting. When replacing a token or node, transfer the trivia from the old token to the new one.
    *   **Tools**: Use `TypedTreeTools.removeLeadingTrivia(expr)` and `removeTrailingTrivia(expr)` to extract and move trivia before replacing nodes.
    *   **Structure**: `Trivia` is an enum (`TrWhitespace`, `TrNewline`, `TrBlockComment`, `TrLineComment`).
*   **Type Resolution**: `Typer` and `ExprTyper` handle type inference. `Context` holds global state.
*   **Immutable-ish AST**: `TypedTreeTools.mk` and `WithMacro.with` are used to create modified copies of AST nodes, though the tree structure itself is mutable during filtering.

### Filters (`src/ax4/filters/`)
*   **Structure**: Filters implement a `run(tree:TypedTree)` method.
*   **Pattern**: Most filters iterate over the `TypedTree`, identify specific patterns (e.g., `RewriteForIn`), and mutate the tree or replace nodes.
*   **Example**: `RewriteVectorDecl.hx` transforms `new Vector.<T>` to Haxe syntax.
*   **Error severity**: Filters use `reportError` for non-blocking diagnostics (conversion continues) and `throwError` for critical errors that stop conversion.

### External Dependencies
*   **format**: Used for reading SWC/SWF files (`format.swf.Reader`).
*   **haxe-type**: Special annotation `@haxe-type` in comments allows manual type overrides in AS3 sources (add it in source code when needed).

## Integration Points
*   **SWC Loading**: `SWCLoader` maps AS3 built-ins (like `Object`, `Array`) to internal types (`tUntypedObject`, `tUntypedArray`) or Haxe equivalents.
*   **Haxe Generation**: `GenHaxe` handles the final printing, including specific Haxe constructs (e.g., `cast`, `Std.int`).

## Essential Files
*   `src/ax4/Main.hx`: Entry point and pipeline definition.
*   `src/ax4/TypedTree.hx`: Core semantic model definition.
*   `src/ax4/ExprTyper.hx`: Logic for typing expressions.
*   `src/ax4/GenHaxe.hx`: Haxe code printer.
*   `src/ax4/Filters.hx`: Registry of all transformation filters.