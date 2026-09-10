// An OUTPUT position whose type is an inline union the bridge cannot build at
// runtime, in each of the four places a generated package renders one.
//
// `Alpha` and `Beta` are interfaces, so they are erased: `value instanceof
// Alpha` would throw, no `_from_js` can be emitted, and a declaration that
// promises the enum hands back a raw JS value. The honest answer is `JSValue`.
//
// Each union is mentioned EXACTLY ONCE on purpose. The synthesized alias is
// registered as a side effect of rendering, so a union that also appears as a
// PARAMETER somewhere above happens to be registered by the time a return is
// decided — which is how the first version of this widening fixed one
// declaration and not its neighbour.
export interface Alpha {
  a: number;
}
export interface Beta {
  b: string;
}

export declare function erasedReturn(x: number): Alpha | Beta;
export declare function erasedOptionalReturn(x: number): Alpha | Beta | undefined;

// The negative control: `string` and `URL` discriminate at runtime (`typeof`
// and a real global constructor), so this union keeps its enum and converts.
export declare function buildableReturn(x: number): string | URL;

export interface Bag {
  // Two directions, one written type. `index_get` crosses JS -> MoonBit and
  // has to widen; `index_set` crosses the other way, where `_to_js` reads
  // `$tag` and needs no runtime predicate, so it keeps the enum.
  [key: string]: Alpha | Beta;
}

export interface Service {
  erasedMethod(name: string): Alpha | Beta;
}
