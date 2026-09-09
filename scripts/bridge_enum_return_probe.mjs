// Does the JS emitted for a declaration that PROMISES a payload-bearing enum
// actually build one?
//
// A MoonBit `pub(all) enum` with a payload is `{ "$tag": i, "_0": v }` at the
// JS boundary — the repo's own generated constructor says so
// (`__ts_mbt_server_type_from_server(value) { return { "$tag": 0, "_0": value
// }; }`). A wrapper that hands back the raw JS value instead leaves a MoonBit
// `match` reading `$tag` off something that has none.
//
// Two sections, because a declaration's implementation lands in one of two
// places and each needs a different question asked:
//
//   A. a named `bridge.js` wrapper (`export function __ts_mbt_<name>(…)`),
//      which can call the `_from_js` helper by name;
//   B. an `extern "js" fn` whose body is an INLINE lambda (`#| (self) =>
//      self.path`), which cannot import that helper, so the conversion has to
//      be inlined into the body.
//
// The first version of this probe had only section A and matched
// `declare pub fn NAME(`, so every `Type::method` and `fn[T]` form was
// skipped — which is most of what a class-heavy package declares, and all
// four of the accessor sites that turned out to be broken.
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";

function walk(d, out = []) {
  for (const e of readdirSync(d, { withFileTypes: true })) {
    const p = join(d, e.name);
    if (e.isDirectory()) {
      if (e.name !== "node_modules") walk(p, out);
    } else if (e.name === "bridge.mbti") out.push(p);
  }
  return out;
}

const snake = (s) =>
  s
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/[^A-Za-z0-9]/g, "_")
    .toLowerCase();

// Payload-BEARING enums only. A payload-free enum (`enum Mode { Read Write }`,
// from a TS numeric enum) is an integer tag on the MoonBit side, so a raw
// numeric passthrough is the correct wrapper — counting those was this
// probe's own first bug.
function payloadEnums(src) {
  const enums = new Set();
  for (const m of src.matchAll(
    /^pub\(all\) enum ([A-Za-z_][\w]*) \{\n((?:  .*\n)*)\}/gm,
  )) {
    if (/^  [A-Za-z_][\w]*\(/m.test(m[2])) enums.add(m[1]);
  }
  return enums;
}

const APPLIES_CONVERTER = /_from_js|_to_js|\$tag/;

let totalEnums = 0;
let wrapperDecls = 0;
let wrapperBad = 0;
let inlineDecls = 0;
let inlineBad = 0;
const byPkg = [];

for (const mbti of walk("_build")) {
  const dir = dirname(mbti);
  const src = readFileSync(mbti, "utf8");
  const enums = payloadEnums(src);
  totalEnums += enums.size;
  if (enums.size === 0) continue;
  const bad = [];

  // ---- Section A: named bridge.js wrappers -------------------------------
  let jsSrc = "";
  try {
    jsSrc = readFileSync(join(dir, "bridge.js"), "utf8");
  } catch {
    jsSrc = "";
  }
  if (jsSrc) {
    for (const m of src.matchAll(
      /^declare pub fn(?:\[[^\]]*\])? ([A-Za-z_][\w]*(?:::[A-Za-z_][\w]*)?)\(.*?\) -> ([A-Za-z_][\w]*)(\[[^\]]*\])?\??$/gm,
    )) {
      const [, fn, ret, typeArgs] = m;
      // A generic instantiation (`Foo[T]`) is not the bare enum name.
      if (typeArgs || !enums.has(ret)) continue;
      // `Type::method` binds as `__ts_mbt_<type>_<method>`
      // (`ffi_class_method_binding_name`); a plain name as `__ts_mbt_<name>`.
      const binding = fn.includes("::")
        ? "__ts_mbt_" + fn.split("::").map(snake).join("_")
        : "__ts_mbt_" + snake(fn);
      const w = jsSrc.match(
        new RegExp("export function " + binding + "\\(([^)]*)\\) \\{([^\\n]*)", "m"),
      );
      // No named wrapper: this declaration is implemented by an inline
      // extern, which section B reads directly. Not a finding here.
      if (!w) continue;
      wrapperDecls += 1;
      if (!APPLIES_CONVERTER.test(w[2])) {
        wrapperBad += 1;
        bad.push({ kind: "wrapper", fn, ret, detail: `-> ${ret}` });
      }
    }
  }

  // ---- Section B: inline extern lambda bodies ----------------------------
  // Both directions: a return promising the enum, and a parameter declared as
  // the enum whose `{$tag, _0}` is handed to JS unconverted.
  for (const file of readdirSync(dir)) {
    if (!file.endsWith(".mbt")) continue;
    const text = readFileSync(join(dir, file), "utf8");
    for (const m of text.matchAll(
      /^pub extern "js" fn(?:\[[^\]]*\])? ([A-Za-z_][\w:]*)\(([^)]*)\) -> ([A-Za-z_][\w]*)(\[[^\]]*\])?(\??)\s*=\n((?:\s*#\|.*\n)+)/gm,
    )) {
      const [, fn, params, ret, typeArgs, optional, body] = m;
      const hits = [];
      if (!typeArgs && enums.has(ret)) hits.push(`ret ${ret}${optional}`);
      for (const p of params.matchAll(/:\s*([A-Za-z_][\w]*)(\??)\s*(?:,|$)/g)) {
        if (enums.has(p[1])) hits.push(`param ${p[1]}${p[2]}`);
      }
      if (hits.length === 0) continue;
      inlineDecls += 1;
      if (!APPLIES_CONVERTER.test(body)) {
        inlineBad += 1;
        bad.push({ kind: "inline", fn, ret, detail: hits.join(", ") });
      }
    }
  }

  if (bad.length) {
    byPkg.push({
      pkg: mbti.replace(/^_build\//, "").replace(/\/bridge\.mbti$/, ""),
      bad,
    });
  }
}

console.log(`tagged-union enums declared:                  ${totalEnums}`);
console.log(`named bridge.js wrappers crossing one:        ${wrapperDecls}`);
console.log(`...building no enum value:                    ${wrapperBad}`);
console.log(`inline extern bodies crossing one:            ${inlineDecls}`);
console.log(`...applying no converter:                     ${inlineBad}`);
for (const p of byPkg) {
  console.log(`\n  ${p.pkg}`);
  for (const b of p.bad.slice(0, 8)) {
    console.log(`    [${b.kind}] ${b.fn}: ${b.detail}`);
  }
  if (p.bad.length > 8) console.log(`    ... +${p.bad.length - 8} more`);
}
process.exitCode = wrapperBad + inlineBad > 0 ? 1 : 0;
