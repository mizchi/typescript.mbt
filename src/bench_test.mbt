///|
fn make_large_source(funcs : Int) -> String {
  let sb = StringBuilder::new()
  let mut i = 0
  while i < funcs {
    sb..write_string("function f")
      ..write_string(i.to_string())
      ..write_string("(x) { return x + ")
      ..write_string(i.to_string())
      ..write_string("; }\n")
    i = i + 1
  }
  sb..write_string("function main() {\n")
    ..write_string("  let acc = 0;\n")
  let mut j = 0
  while j < funcs {
    sb..write_string("  acc += f")
      ..write_string(j.to_string())
      ..write_string("(")
      ..write_string(j.to_string())
      ..write_string(");\n")
    j = j + 1
  }
  sb..write_string("  return acc;\n")
    ..write_string("}\n")
  sb.to_string()
}

///|
let parser_small_src : String =
  #|function fib(n) {
  #|  if (n <= 1) return n;
  #|  return fib(n - 1) + fib(n - 2);
  #|}
  #|function main() {
  #|  let sum = 0;
  #|  for (let i = 0; i < 20; i++) { sum += fib(i); }
  #|  return sum;
  #|}

///|
let parser_large_src : String = make_large_source(200)

///|
let runtime_small_src : String =
  #|function sum(n) {
  #|  let s = 0;
  #|  for (let i = 0; i < n; i++) { s += i; }
  #|  return s;
  #|}
  #|function main() {
  #|  let total = 0;
  #|  for (let i = 0; i < 200; i++) { total += sum(200); }
  #|  return total;
  #|}

///|
let runtime_large_src : String = make_large_source(200)

///|
test "bench parser tokenize small" (b : @bench.T) {
  b.bench(
    () => {
      let lexer = @parser.Lexer::new(parser_small_src)
      let _ = lexer.tokenize()
    },
    name="parser.tokenize.small",
    count=10,
  )
}

///|
test "bench parser module small" (b : @bench.T) {
  b.bench(
    () => {
      let parser = @parser.Parser::from_source(parser_small_src)
      let _ = try! parser.parse_module()
    },
    name="parser.module.small",
    count=5,
  )
}

///|
test "bench parser module large" (b : @bench.T) {
  b.bench(
    () => {
      let parser = @parser.Parser::from_source(parser_large_src)
      let _ = try! parser.parse_module()
    },
    name="parser.module.large",
    count=1,
  )
}

///|
test "bench runtime run small" (b : @bench.T) {
  b.bench(
    () => {
      let interp = @runtime.JSInterpreter::new()
      let _ = try! interp.run(runtime_small_src)
    },
    name="runtime.run.small",
    count=1,
  )
}

///|
test "bench runtime run large" (b : @bench.T) {
  b.bench(
    () => {
      let interp = @runtime.JSInterpreter::new()
      let _ = try! interp.run(runtime_large_src)
    },
    name="runtime.run.large",
    count=1,
  )
}

///|
/// TypeScript d.ts parsing benchmark
let ts_dts_src : String =
  #|interface Array<T> {
  #|    readonly length: number;
  #|    toString(): string;
  #|    toLocaleString(): string;
  #|    pop(): T | undefined;
  #|    push(...items: T[]): number;
  #|    concat(...items: ConcatArray<T>[]): T[];
  #|    concat(...items: (T | ConcatArray<T>)[]): T[];
  #|    join(separator?: string): string;
  #|    reverse(): T[];
  #|    shift(): T | undefined;
  #|    slice(start?: number, end?: number): T[];
  #|    sort(compareFn?: (a: T, b: T) => number): this;
  #|    splice(start: number, deleteCount?: number): T[];
  #|    splice(start: number, deleteCount: number, ...items: T[]): T[];
  #|    unshift(...items: T[]): number;
  #|    indexOf(searchElement: T, fromIndex?: number): number;
  #|    lastIndexOf(searchElement: T, fromIndex?: number): number;
  #|    every<S extends T>(predicate: (value: T, index: number, array: T[]) => value is S, thisArg?: any): this is S[];
  #|    every(predicate: (value: T, index: number, array: T[]) => unknown, thisArg?: any): boolean;
  #|    some(predicate: (value: T, index: number, array: T[]) => unknown, thisArg?: any): boolean;
  #|    forEach(callbackfn: (value: T, index: number, array: T[]) => void, thisArg?: any): void;
  #|    map<U>(callbackfn: (value: T, index: number, array: T[]) => U, thisArg?: any): U[];
  #|    filter<S extends T>(predicate: (value: T, index: number, array: T[]) => value is S, thisArg?: any): S[];
  #|    filter(predicate: (value: T, index: number, array: T[]) => unknown, thisArg?: any): T[];
  #|    reduce(callbackfn: (previousValue: T, currentValue: T, currentIndex: number, array: T[]) => T): T;
  #|    reduce(callbackfn: (previousValue: T, currentValue: T, currentIndex: number, array: T[]) => T, initialValue: T): T;
  #|    reduce<U>(callbackfn: (previousValue: U, currentValue: T, currentIndex: number, array: T[]) => U, initialValue: U): U;
  #|    reduceRight(callbackfn: (previousValue: T, currentValue: T, currentIndex: number, array: T[]) => T): T;
  #|    reduceRight(callbackfn: (previousValue: T, currentValue: T, currentIndex: number, array: T[]) => T, initialValue: T): T;
  #|    reduceRight<U>(callbackfn: (previousValue: U, currentValue: T, currentIndex: number, array: T[]) => U, initialValue: U): U;
  #|    readonly [n: number]: T;
  #|}
  #|
  #|type Partial<T> = {
  #|    [P in keyof T]?: T[P];
  #|};
  #|
  #|type Required<T> = {
  #|    [P in keyof T]-?: T[P];
  #|};
  #|
  #|type Omit<T, K extends keyof any> = Pick<T, Exclude<keyof T, K>>;

///|
test "bench parser typescript dts" (b : @bench.T) {
  b.bench(
    () => {
      let parser = @parser.Parser::from_source(ts_dts_src)
      let _ = try! parser.parse_module()
    },
    name="parser.typescript.dts",
    count=5,
  )
}
