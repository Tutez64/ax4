# Diagnostics

ax4 often keeps converting when it hits awkward or weakly typed AS3: it emits Haxe that follows **AVM2 / AS3 semantics**, even when the pattern looks like a bug or a typing smell. Those sites are reported as **warnings** (file, line, message) so they stay visible without stopping the run.

At the end of a successful run, a **summary** groups those messages by kind (with counts). Site-specific details (local names, concrete types, …) are collapsed so related warnings appear as one row.

```text
diagnostics: 1690 total (22 kinds)
See docs/Diagnostics.md for descriptions and recommendations.
  595	Inferred local var type <name> as <Type> (was ASAny)
  283	IMPORTANT: Untyped method call. This can cause possible slowdowns!
  ...
```

Use the per-line log to locate a concrete site; use the summary to prioritize what to review.

Fatal `assert` aborts (incomplete rewrite) stop the run and do **not** produce a summary.

---

## Categories

Each catalogue entry is tagged with one primary category:

| Category | Meaning |
|----------|---------|
| **Noise** | High volume, usually low decision value; skim the count, dig in only if something breaks |
| **Performance** | Converted, but may be slow or opaque at runtime |
| **Typing** | Weak / surprising types; may affect Haxe output quality more than AS3 semantics |
| **Fidelity** | Odd-looking AS3 that ax4 preserves on purpose (AVM2 rules) |
| **Suspicious** | Often inconsistent with author intent, but still valid AS3/AVM2 — converted faithfully |
| **Risk** | Easy to get wrong at runtime; inspect before trusting the port |
| **Gap** | Converter limitation; may abort or leave a weak rewrite |

These are judgment labels for triage, not strict severity levels. The same warning can matter more in a hot path than elsewhere.

**About decompiled input:** names like `_loc1_` are typical of bytecode decompilation (locals recovered without original identifiers). That does **not** mean every warning on such code is a decompiler mistake — many patterns exist in hand-written AS3 too (`*`, `Object`, missing `break`, `void` used as value). When unsure, treat the **SWF/ABC semantics** as ground truth, not the prettiness of the `.as` text.

---

## Catalogue

### Noise

#### `Inferred local var type <name> as <Type> (was ASAny)`

- **Meaning:** A `*` / untyped local was narrowed to a concrete Haxe type.
- **Category:** Noise (especially when names are `_locN_` and counts are huge).
- **Notes:** The warning is about ax4’s inference, not about a failed rewrite. Volume is common on decompiled trees because temps are often untyped/`*`; the same diagnostic appears on hand-written `var x:*` once narrowed.
- **Recommendation:** Don’t triage occurrence-by-occurrence. Spot-check only if a narrowed type looks implausible for that site.

#### `Useless vector casting`

- **Meaning:** A redundant `Vector.<T>` cast was noted/removed.
- **Category:** Noise.
- **Recommendation:** Ignore unless the generated code looks wrong.

---

### Performance

#### `IMPORTANT: Untyped method call. This can cause possible slowdowns!`

- **Meaning:** Call on a weakly typed receiver (`*`, `Object`, unresolved, …).
- **Category:** Performance (+ Typing).
- **Recommendation:** Prioritize hot paths. Prefer a typed receiver in AS3 when you can; otherwise accept reflection-style dispatch in Haxe.

---

### Typing

#### `Missing type coercion: expected=<Type>, actual=<Type>`

- **Meaning:** Expected/actual types still disagree after filters.
- **Category:** Typing (possible Gap).
- **Recommendation:** Inspect the site; may need an ax4 fix or an explicit cast in AS3/Haxe.

#### `Dynamic array access?` / `Untyped array access`

- **Meaning:** Indexing through a dynamic/untyped value.
- **Category:** Typing (may become reflection-style access).
- **Recommendation:** If indexing misbehaves at runtime, give the container a real type in AS3 or adjust the Haxe.

#### `untyped hasOwnProperty detected` / `hasOwnProperty on class instance detected`

- **Meaning:** `hasOwnProperty` on an untyped value or class instance (broader than typical Haxe practice).
- **Category:** Typing.
- **Recommendation:** Prefer `Dictionary` / dynamic objects for string-key maps when that was the intent.

#### `Attempting to get field on type <Type>` / `unknown callable type: <Type>` / `Unknown field <name> on type <Type>`

- **Meaning:** Field or call resolved against an unexpected or incomplete type.
- **Category:** Typing (possible Gap or incomplete SWC/model).
- **Recommendation:** Check library typings (`swc`), the expression’s inferred type, and the generated call.

#### `Unknown Array instance field <name>` / `Unknown Vector instance field <name>`

- **Meaning:** Member not in ax4’s Array/Vector API model.
- **Category:** Typing / Risk (depends whether the member exists at runtime).
- **Recommendation:** Confirm the API is real for your runtime; replace with a supported equivalent if not.

#### `Unhandled Array.concat() call (possibly untyped?). Leaving as is.`

- **Meaning:** This `concat` shape was not specially rewritten.
- **Category:** Typing / Risk.
- **Recommendation:** Compare generated Haxe with AS3 intent at that site.

#### `Unknown to string coercion (actual type is <Type>)` / `Unknown parameter type for the Date constructor: <Type>`

- **Meaning:** Coercion/constructor path without a dedicated rewrite rule.
- **Category:** Typing.
- **Recommendation:** Verify the generated Haxe for that expression.

---

### Fidelity

#### `Dynamic + operation!` / `Dynamic arithmetic operation!`

- **Meaning:** `+` or other arithmetic with a dynamic operand (AVM2 ToPrimitive / ToNumber / concat rules).
- **Category:** Fidelity.
- **Recommendation:** Usually leave as-is. Tighten AS3 types if you want clearer static Haxe.

#### `Boolean + operation!` / `Boolean arithmetic operation!`

- **Meaning:** Boolean used in numeric arithmetic (`true`→1, `false`→0), e.g. `0 + (x == y)`.
- **Category:** Fidelity (can also be Suspicious if it looks accidental).
- **Recommendation:** Preserve for behavioral parity. Change the AS3 only if you have decided the boolean-arithmetic behavior is undesired.

#### `Array access using Number index` / `ByteArray access using Number index` / `Dictionary access using Number index`

- **Meaning:** Non-integer numeric index on a typed container.
- **Category:** Fidelity.
- **Recommendation:** Coercion is expected; check NaN / fractional edge cases if relevant.

#### `Non-integer index used for array access on Array/Vector, coercing to Int`

- **Meaning:** An explicit Int coercion was inserted for the index.
- **Category:** Fidelity.
- **Recommendation:** Confirm truncation matches AS3 for that site.

#### `Switch case fall-through (rewritten by duplicating subsequent case body)`

- **Meaning:** AS3 case fall-through rewritten for Haxe by duplicating the executed suffix (empty case labels still group with `|`).
- **Category:** Fidelity (often Suspicious when a `break` looks forgotten).
- **Notes:** Fall-through is valid AS3. When present in ABC, it is not “ax4 inventing” control flow. Whether a missing `break` was accidental is a project decision; ax4 keeps AVM2 behavior.
- **Recommendation:** Keep for parity. Edit the AS3 (add/remove `break`s) only when you intentionally change control flow.

---

### Suspicious

#### `void used as Bool (undefined → false)`

- **Meaning:** A `void`-returning call is used where a Boolean is expected (e.g. `if (f())`). In AVM2, a `returnvoid` read as a value is `undefined` (falsy). ax4 emits `{ f(); false; }` so **side effects run** and the condition is **always false**.
- **Category:** Suspicious.
- **Notes:** Using `void` as a condition is almost never a deliberate style; it is still well-defined. Changing the callee to return `Boolean` / `true` / `false` **changes** runtime behavior relative to the SWF — do that only as an intentional project fix, after checking ABC (signature + `returnvoid` vs `returnvalue`).
- **Recommendation:** Default: keep ax4’s rewrite for parity. If the `then` branch should be reachable, fix the AS3 contract (return type and returned value) to match the intended logic, then reconvert.

#### `Field initializer depends on a slot assigned in the constructor (ASC uses the default value)`

- **Meaning:** An instance field initializer reads a slot that the constructor also assigns. ASC runs field initializers **before** the constructor body, so the initializer sees the **default** value, not that assignment. By default ax4 keeps that ASC order when moving the init into the Haxe constructor (init at the start of the ctor body).
- **Category:** Suspicious.
- **Notes:** Valid AS3 with defined semantics, but pairing a field init with a later ctor assign to the same slot is rarely deliberate ASC style (the init would not see that value). `settings.reorderFieldInitsForCtorDeps` places the moved init after pre-`super()` assigns to those slots instead (and may keep related base-field assigns before `super()`). That usually matches the likely intended runtime; it diverges from strict ASC/SWF field-init ordering.
- **Recommendation:** Default: keep ASC-faithful placement. If the default value looks wrong, enable `reorderFieldInitsForCtorDeps` or move the logic into the constructor body in AS3, then reconvert.

---

### Risk

#### `String index used for array access on Array. Did you mean to use Dictionary/Object? Falling back to reflection.`

- **Meaning:** String key used on a value typed as `Array` → reflection fallback in Haxe.
- **Category:** Risk.
- **Notes:** Can come from AS3 using `Array` where `Object`/`Dictionary` was meant, from weak typing, or from imperfect recovered types. Do not assume a single root cause.
- **Recommendation:** Check the real container type and runtime keys; adjust AS3 types or structure if wrong.

#### `String index used for array access on Vector. Reflection doesn't currently work consistently on this`

- **Meaning:** String key on `Vector` — poorly supported path.
- **Category:** Risk.
- **Recommendation:** Inspect and fix; do not ignore.

#### `delete on array?`

- **Meaning:** `delete` applied to an array-like value.
- **Category:** Risk.
- **Recommendation:** Confirm intent (`delete` slot vs `splice` / assign `null`) against AS3 semantics you need.

---

### Gap

#### `Unsupported + operation` / `Unsupported arithmetic operation`

- **Meaning:** Operand combination ax4 does not accept yet.
- **Category:** Gap (often followed by fatal `assert`).
- **Recommendation:** File/fix converter coverage for that pattern.

#### `Non-terminal expression inside a switch case, possible fall-through?`

- **Meaning:** Older fatal path when fall-through could not be rewritten.
- **Category:** Gap (should be rare after fall-through support).
- **Recommendation:** If this still appears, treat it as an ax4 bug and provide a minimal repro.

---

## Adding new diagnostics

When introducing a new `reportError` / warning string:

1. Prefer a **stable message text** (put variable bits in a consistent place).
2. If the message embeds names/types, extend `DiagnosticStats.normalizeMessage`.
3. Document it here with: meaning, category, notes (only when evidence-backed), recommendation.
4. Avoid project-specific advice (one app’s manual patch is not a general rule). Prefer AVM2/AS3 facts and “parity vs intentional change”.
