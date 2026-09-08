import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
function walk(d, out=[]) {
  for (const e of readdirSync(d, { withFileTypes: true })) {
    const p = join(d, e.name);
    if (e.isDirectory()) { if (e.name !== "node_modules") walk(p, out); }
    else if (e.name === "bridge.mbti") out.push(p);
  }
  return out;
}
let totalEnums = 0, totalRet = 0, broken = 0;
const byPkg = [];
for (const mbti of walk("_build")) {
  const js = mbti.replace(/bridge\.mbti$/, "bridge.js");
  let jsSrc = ""; try { jsSrc = readFileSync(js, "utf8"); } catch { continue; }
  const src = readFileSync(mbti, "utf8");
  // tagged-union enum names: `pub(all) enum X {` where a case has a payload
  // Only PAYLOAD-BEARING enums. A payload-free enum (`enum Mode { Read
  // Write }`, from a TS numeric enum) is an integer tag on the MoonBit side,
  // so a raw numeric passthrough is the correct wrapper -- counting those was
  // the probe's own bug.
  const enums = new Set();
  for (const m of src.matchAll(/^pub\(all\) enum ([A-Za-z_][\w]*) \{\n((?:  .*\n)*)\}/gm)) {
    if (/^  [A-Za-z_][\w]*\(/m.test(m[2])) enums.add(m[1]);
  }
  totalEnums += enums.size;
  const bad = [];
  for (const m of src.matchAll(/^declare pub fn ([A-Za-z_][\w]*)\(.*?\) -> ([A-Za-z_][\w]*)\??$/gm)) {
    const [, fn, ret] = m;
    if (!enums.has(ret)) continue;
    totalRet += 1;
    // snake_case the fn name the way the emitter does, then look for a
    // `_from_js` call or an inline `$tag` construction in its wrapper.
    const snake = fn.replace(/([a-z0-9])([A-Z])/g, "$1_$2").replace(/[^A-Za-z0-9]/g, "_").toLowerCase();
    const re = new RegExp("export function __ts_mbt_" + snake + "\\(([^)]*)\\) \\{([^\\n]*)", "m");
    const w = jsSrc.match(re);
    if (!w) continue;
    const body = w[2];
    if (!/_from_js\(|"\$tag"/.test(body)) { broken += 1; bad.push({ fn, ret }); }
  }
  if (bad.length) byPkg.push({ pkg: mbti.replace(/^_build\//, "").replace(/\/bridge\.mbti$/, ""), bad });
}
console.log(`tagged-union enums declared:            ${totalEnums}`);
console.log(`fns returning one:                      ${totalRet}`);
console.log(`...whose wrapper builds no enum value:  ${broken}`);
for (const p of byPkg) {
  console.log(`\n  ${p.pkg}`);
  for (const b of p.bad.slice(0, 8)) console.log(`    ${b.fn} -> ${b.ret}`);
  if (p.bad.length > 8) console.log(`    ... +${p.bad.length - 8} more`);
}
