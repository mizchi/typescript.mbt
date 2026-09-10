// A class property whose type is a heterogeneous union — the TAGGED-UNION
// enum family, not the literal-union one `class-property-entry.d.ts` covers.
//
// Both members carry a runtime discriminator (`typeof === "string"` and a
// global `URL` constructor), so the alias gets a working `_from_js` as well as
// a `_to_js`, and every accessor path has to route through them: the MoonBit
// side of `Key` is `{ "$tag": i, "_0": v }` and the JS side is the bare value.
export type Key = string | URL;

// The negative control. `Level` is the OTHER enum family — a literal union,
// which lowers to a generated enum whose converters are MoonBit functions in
// `converters.mbt`. Its accessors must convert on the MoonBit side and leave
// the JS body a bare property read, so a property must not come out converted
// twice.
export type Level = "low" | "high";

export declare class Holder {
  key: Key;
  level: Level;
  static staticKey: Key;
  static staticLevel: Level;
}
