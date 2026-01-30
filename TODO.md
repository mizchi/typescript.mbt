# test262 Progress

## Current Status (2026-01-31)

Based on `test262.allowlist.txt` (34,268 tests) and `test262.skiplist.txt` (14,029 skipped).

### Overall

| Category | Allowlist | Skipped | Runnable | Notes |
|----------|-----------|---------|----------|-------|
| Total | 34,268 | 14,029 | ~20,000 | |
| built-ins | 17,574 | - | - | |
| language | 13,179 | - | - | |
| intl402 | 1,712 | - | - | Not tested |
| staging | 1,051 | - | - | Not tested |
| annexB | 752 | - | - | Partial |

### Language Features

| Feature | Status | Notes |
|---------|--------|-------|
| expressions | Partial | class, generators, async need work |
| statements | Partial | for-of, generators |
| function-code | Good | |
| arguments-object | Partial | |
| literals | Good | |
| identifiers | Good | |
| module-code | Skipped | ESM not supported |
| eval-code | Partial | Direct eval only |

### Built-in Objects

| Object | Status | Notes |
|--------|--------|-------|
| Object | Good | keys, values, entries, assign, etc. |
| Array | Good | Most methods work |
| String | Good | Most methods work |
| Number | Good | |
| Math | Good | |
| Function | Partial | No dynamic Function() |
| Date | Minimal | Basic operations only |
| RegExp | Minimal | Literal parsing incomplete |
| Promise | Partial | async/await works |
| Proxy | Partial | Basic traps |
| Reflect | Partial | |
| Symbol | Not supported | Using @@iterator workaround |
| Temporal | Not tested | |
| TypedArray | Not tested | |
| WeakMap/Set | Not tested | |

---

## Skip Reasons (14,029 tests)

| Reason | Count | Notes |
|--------|-------|-------|
| flag:async | 5,513 | Async tests (some supported) |
| includes:temporalHelpers.js | 2,690 | Temporal API |
| includes:testTypedArray.js | 1,123 | TypedArray |
| banned:eval | 1,418 | Dynamic eval features |
| includes:regExpUtils.js | 574 | RegExp helpers |
| banned:with | 497 | with statement (deprecated) |
| banned:Function | 322 | Dynamic Function() |
| Other includes | ~1,900 | Various test helpers |

---

## Next Steps

### High Priority

1. **yield\* for async generators**
   - Thenable handling in yield*

2. **iterator.return() / throw()**
   - Cleanup on loop break
   - for-of early termination

3. **RegExp literal parser**
   - `/pattern/flags` syntax

### Medium Priority

4. **Symbol support**
   - Symbol.iterator (currently @@iterator workaround)
   - Well-known symbols

5. **More built-ins**
   - Set, Map
   - WeakMap, WeakSet

### Low Priority (ES2024+)

- `using` declaration
- import defer
- import attributes

---

## Not Supported

These features are intentionally not implemented:

- **with statement** - Deprecated, 497 tests skipped
- **Dynamic eval features** - Limited to direct eval
- **Tail call optimization** - Not implemented
- **ES modules** - Parser accepts but not fully executed

---

## Completed

- Strict mode duplicate parameter validation
- Strict mode eval/arguments assignment prohibition
- for-await-of parser fix
- Async generator basic support
- Line terminator handling (CR, LS, PS)
