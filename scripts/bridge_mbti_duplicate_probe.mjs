import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
function walk(d, out = []) {
  for (const e of readdirSync(d, { withFileTypes: true })) {
    const p = join(d, e.name);
    if (e.isDirectory()) { if (e.name !== "node_modules") walk(p, out); }
    else if (e.name === "bridge.mbti") out.push(p);
  }
  return out;
}
let totFns = 0, totDupNames = 0, totExtraLines = 0, pkgs = 0, mismatched = 0;
const detail = [];
for (const mbti of walk("_build")) {
  const src = readFileSync(mbti, "utf8");
  const mbt = (() => { try { return readFileSync(mbti.replace(/mbti$/, "mbt"), "utf8"); } catch { return ""; } })();
  const byName = new Map();
  for (const m of src.matchAll(/^declare pub fn ([A-Za-z_][\w]*)\((.*?)\) -> (.*)$/gm)) {
    const [, name, params, ret] = m;
    if (!byName.has(name)) byName.set(name, []);
    byName.get(name).push(`(${params}) -> ${ret}`);
  }
  const fns = [...byName.values()].reduce((n, v) => n + v.length, 0);
  totFns += fns;
  const dups = [...byName.entries()].filter(([, v]) => v.length > 1);
  if (!dups.length) continue;
  pkgs += 1;
  totDupNames += dups.length;
  totExtraLines += dups.reduce((n, [, v]) => n + v.length - 1, 0);
  // How many of the duplicate signatures have NO counterpart in the impl?
  const orphans = [];
  for (const [name, sigs] of dups) {
    for (const sig of sigs) {
      // the impl spells it `pub extern "js" fn name(...) -> T` or `pub fn name(...) -> T`
      const ret = sig.slice(sig.indexOf(") -> ") + 5);
      const re = new RegExp("fn " + name + "\\(.*\\) -> " + ret.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
      if (!re.test(mbt)) orphans.push(`${name}${sig}`);
    }
  }
  mismatched += orphans.length;
  detail.push({ pkg: mbti.replace(/^_build\//, "").replace(/\/bridge\.mbti$/, ""), dups, orphans });
}
console.log(`packages with duplicates:        ${pkgs}`);
console.log(`duplicated declaration names:    ${totDupNames}`);
console.log(`redundant declare lines:         ${totExtraLines}  (of ${totFns} total -> the report over-counts by this)`);
console.log(`duplicate sigs with NO impl:     ${mismatched}`);
for (const d of detail.slice(0, 4)) {
  console.log(`\n  ${d.pkg}`);
  for (const [name, sigs] of d.dups.slice(0, 4)) {
    console.log(`    ${name}  x${sigs.length}`);
    for (const s of sigs) console.log(`       ${s.length > 96 ? s.slice(0, 96) + "…" : s}`);
  }
  if (d.dups.length > 4) console.log(`    ... +${d.dups.length - 4} more names`);
  if (d.orphans.length) console.log(`    NO IMPL: ${d.orphans.slice(0,3).map(o => o.slice(0,80)).join(" | ")}`);
}
