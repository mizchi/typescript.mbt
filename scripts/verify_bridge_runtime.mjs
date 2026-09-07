#!/usr/bin/env node
// Run the generated `bridge.js` converters under Node.
//
// Every other bridge harness in this repo asks whether the generated
// package COMPILES (`verify-scaffolds`, `verify-generated-fixtures`,
// `verify-examples`) or whether a REJECTED export is budgeted
// (`bridge_quality_report.sh`). Nothing asked whether the code we emit for
// an ACCEPTED export runs, and the answer was no: a tagged-union case whose
// payload is `Named(N)` is discriminated with `N instanceof`, and `N` is a
// TypeScript type as often as it is a runtime class. An interface, a type
// alias, an enum and a type parameter are all erased, so the emitted
// predicate is a `ReferenceError` on its first call.
//
// Two checks, because neither alone is complete:
//
//   static  — every `instanceof X` in a generated `bridge.js` must have `X`
//             either a JS global or bound in that module. This is the
//             COMPLETE check: it sees a site whichever arm of the converter
//             the probe value happens to reach.
//   runtime — import each `bridge.js` and call every exported
//             `__ts_mbt_tagged_union_*_from_js` over a value battery. A
//             `ReferenceError` is a failure; the converter's own
//             `unexpected <Alias> value` throw is the designed no-match
//             path and passes. This is what proves the static list is real
//             rather than a grep artifact.
//
// Usage: node scripts/verify_bridge_runtime.mjs [--json <path>] [--verbose]
//
// Exits non-zero when a generated module references an unbound
// `instanceof` target, or when a converter throws a ReferenceError.

import { readFileSync, existsSync, statSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Names a generated `bridge.js` may use without binding them: JS globals
// plus the Node globals available in an ESM module. `instanceof` against
// any of these is sound wherever the bridge runs.
const JS_GLOBALS = new Set([
  "Array", "Object", "Function", "String", "Number", "Boolean", "Symbol",
  "BigInt", "Date", "RegExp", "Error", "TypeError", "RangeError",
  "SyntaxError", "ReferenceError", "EvalError", "URIError", "AggregateError",
  "Map", "Set", "WeakMap", "WeakSet", "WeakRef", "Promise", "Proxy",
  "ArrayBuffer", "SharedArrayBuffer", "DataView", "Int8Array", "Uint8Array",
  "Uint8ClampedArray", "Int16Array", "Uint16Array", "Int32Array",
  "Uint32Array", "Float32Array", "Float64Array", "BigInt64Array",
  "BigUint64Array", "URL", "URLSearchParams", "Buffer", "AbortController",
  "AbortSignal", "TextEncoder", "TextDecoder", "Blob", "File", "FormData",
  "Headers", "Request", "Response", "ReadableStream", "WritableStream",
  "TransformStream", "MessageChannel", "MessagePort", "Event", "EventTarget",
  "BroadcastChannel", "CompressionStream", "DecompressionStream",
  "CustomEvent", "Worker", "Performance", "Crypto", "CryptoKey", "SubtleCrypto",
]);

// The probe battery. One value per JS runtime type the discriminators can
// test, so a converter that reaches its `instanceof` arm at all reaches it
// for at least one of these.
function probeValues() {
  return [
    ["string", "some/path.txt"],
    ["number", 7],
    ["boolean", true],
    ["bigint", 10n],
    ["null", null],
    ["undefined", undefined],
    ["array", [1, 2]],
    ["object", { encoding: "buffer" }],
    ["function", () => 1],
    ["date", new Date(0)],
    ["regexp", /x/],
  ];
}

function parseArgs(argv) {
  const opts = { json: null, verbose: false };
  for (let i = 2; i < argv.length; i += 1) {
    if (argv[i] === "--json") {
      opts.json = argv[i + 1];
      i += 1;
    } else if (argv[i] === "--verbose") {
      opts.verbose = true;
    } else {
      throw new Error(`unknown flag: ${argv[i]}`);
    }
  }
  return opts;
}

async function findBridgeModules(root) {
  const out = [];
  async function walk(dir) {
    let entries;
    try {
      entries = await readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const e of entries) {
      const p = join(dir, e.name);
      if (e.isDirectory()) {
        // `_build` inside a generated package is MoonBit's own output.
        if (e.name === "node_modules" || e.name === ".git") continue;
        await walk(p);
      } else if (e.isFile() && e.name === "bridge.js") {
        out.push(p);
      }
    }
  }
  await walk(root);
  out.sort();
  return out;
}

// Names the module binds itself, in any of the spellings the emitters use.
function boundNames(src) {
  const bound = new Set();
  const patterns = [
    /^\s*(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=/gm,
    /^\s*(?:export\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(/gm,
    /^\s*(?:export\s+)?class\s+([A-Za-z_$][\w$]*)\b/gm,
    /^\s*import\s+(?:\*\s+as\s+)?([A-Za-z_$][\w$]*)\s+from/gm,
  ];
  for (const re of patterns) {
    for (const m of src.matchAll(re)) bound.add(m[1]);
  }
  // `import { a as b, c } from "m"` — collect the local names.
  for (const m of src.matchAll(/^\s*import\s*\{([^}]*)\}\s*from/gm)) {
    for (const part of m[1].split(",")) {
      const t = part.trim();
      if (!t) continue;
      const as = t.split(/\s+as\s+/);
      bound.add((as.length > 1 ? as[1] : as[0]).trim());
    }
  }
  return bound;
}

function staticCheck(file, src) {
  const bound = boundNames(src);
  const unbound = new Map();
  for (const m of src.matchAll(/instanceof\s+([A-Za-z_$][\w$.]*)/g)) {
    const name = m[1];
    // A qualified target (`ns.Cls`) is bound iff its head is.
    const head = name.split(".")[0];
    if (JS_GLOBALS.has(head) || bound.has(head)) continue;
    unbound.set(name, (unbound.get(name) ?? 0) + 1);
  }
  return { file, unbound: [...unbound.entries()].map(([n, c]) => ({ name: n, count: c })) };
}

async function runtimeCheck(file, opts) {
  const result = { file, loaded: false, loadError: null, calls: 0, failures: [] };
  let mod;
  try {
    mod = await import(pathToFileURL(file).href);
  } catch (e) {
    result.loadError = `${e.constructor?.name ?? "Error"}: ${e.message}`;
    return result;
  }
  result.loaded = true;
  for (const [name, fn] of Object.entries(mod)) {
    if (typeof fn !== "function") continue;
    if (!/^__ts_mbt_tagged_union_.*_from_js$/.test(name)) continue;
    for (const [label, value] of probeValues()) {
      result.calls += 1;
      try {
        fn(value);
      } catch (e) {
        // The converter's own "no case matched" throw is correct behaviour.
        if (e instanceof ReferenceError) {
          result.failures.push({ fn: name, probe: label, error: `ReferenceError: ${e.message}` });
        } else if (!/^unexpected /.test(e.message ?? "")) {
          result.failures.push({ fn: name, probe: label, error: `${e.constructor?.name ?? "Error"}: ${e.message}` });
        }
      }
    }
  }
  if (opts.verbose && result.calls === 0) {
    console.log(`  (no tagged-union converters) ${file}`);
  }
  return result;
}

async function main() {
  const opts = parseArgs(process.argv);
  const buildRoot = join(repoRoot, "_build");
  if (!existsSync(buildRoot) || !statSync(buildRoot).isDirectory()) {
    console.error(
      "no _build directory: run `just verify-scaffolds`, " +
        "`just verify-generated-fixtures` and `just verify-examples` first",
    );
    process.exit(2);
  }

  const files = await findBridgeModules(buildRoot);
  if (files.length === 0) {
    console.error("no generated bridge.js found under _build");
    process.exit(2);
  }

  const staticResults = [];
  const runtimeResults = [];
  for (const file of files) {
    const src = readFileSync(file, "utf8");
    staticResults.push(staticCheck(file, src));
    runtimeResults.push(await runtimeCheck(file, opts));
  }

  const unboundSites = staticResults.reduce(
    (n, r) => n + r.unbound.reduce((m, u) => m + u.count, 0),
    0,
  );
  const unboundNames = new Set();
  for (const r of staticResults) for (const u of r.unbound) unboundNames.add(u.name);
  const loaded = runtimeResults.filter((r) => r.loaded).length;
  const calls = runtimeResults.reduce((n, r) => n + r.calls, 0);
  const failures = runtimeResults.flatMap((r) =>
    r.failures.map((f) => ({ file: r.file, ...f })),
  );

  console.log(`bridge modules found:            ${files.length}`);
  console.log(`bridge modules imported:         ${loaded}`);
  console.log(`converter calls exercised:       ${calls}`);
  console.log(`unbound \`instanceof\` sites:      ${unboundSites} (${unboundNames.size} distinct names)`);
  console.log(`converter runtime failures:      ${failures.length}`);

  if (unboundSites > 0) {
    console.log("\nunbound `instanceof` targets (a ReferenceError if reached):");
    for (const r of staticResults) {
      if (r.unbound.length === 0) continue;
      const rel = r.file.slice(repoRoot.length + 1);
      const names = r.unbound
        .sort((a, b) => b.count - a.count)
        .slice(0, 12)
        .map((u) => (u.count > 1 ? `${u.name} x${u.count}` : u.name));
      const more = r.unbound.length > 12 ? `, +${r.unbound.length - 12} more` : "";
      console.log(`  ${rel}\n    ${names.join(", ")}${more}`);
    }
  }

  if (failures.length > 0) {
    console.log("\nconverter runtime failures:");
    for (const f of failures.slice(0, 40)) {
      console.log(`  ${f.file.slice(repoRoot.length + 1)}\n    ${f.fn}(${f.probe}) -> ${f.error}`);
    }
    if (failures.length > 40) console.log(`  ... +${failures.length - 40} more`);
  }

  const loadErrors = runtimeResults.filter((r) => !r.loaded);
  if (loadErrors.length > 0 && opts.verbose) {
    console.log("\nmodules that could not be imported (not a failure — the");
    console.log("generated package may need a runtime dependency that is not");
    console.log("installed; the static check still covers them):");
    for (const r of loadErrors) {
      console.log(`  ${r.file.slice(repoRoot.length + 1)}\n    ${r.loadError}`);
    }
  } else if (loadErrors.length > 0) {
    console.log(
      `\n${loadErrors.length} module(s) could not be imported (static check ` +
        "still applies; re-run with --verbose for the reasons)",
    );
  }

  if (opts.json) {
    const { writeFileSync } = await import("node:fs");
    writeFileSync(
      opts.json,
      JSON.stringify(
        {
          modules: files.length,
          imported: loaded,
          calls,
          unboundSites,
          unboundNames: [...unboundNames].sort(),
          failures,
          static: staticResults.filter((r) => r.unbound.length > 0),
        },
        null,
        2,
      ),
    );
  }

  if (unboundSites > 0 || failures.length > 0) {
    console.log("\nFAIL");
    process.exit(1);
  }
  console.log("\nOK");
}

await main();
