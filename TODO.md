# test262 修正計画

## 現状サマリー (2026-01-30)

| ステータス | 件数 |
|-----------|------|
| Passed | 12,300 |
| Failed | 2,467 |
| Skipped | 9,109 |
| **Total** | 23,876 |

### 最新の修正 (strict mode + TDZ 対応) - 一部完了
- **compound assignment で未宣言変数を参照するとReferenceError**
  - `x *= 1` で x が存在しない場合、ReferenceError を投げるように修正
  - CompoundAssignExpr (式としての compound assignment) も対応
- **class body は暗黙的に strict mode**
  - class IIFE の先頭に "use strict" を追加
  - class メソッド内での未宣言変数への代入が ReferenceError になる
- **非拡張オブジェクトへのプロパティ追加禁止 (strict mode)**
  - `Object.preventExtensions()` されたオブジェクトに新しいプロパティを追加すると TypeError
- **writable:false プロパティへの代入禁止 (strict mode)**
  - compound assignment (`obj.prop <<= value`) でも set_prop_value を使用
  - PropAccess と IndexAccess の両方で strict mode チェック
- **for-of / for-in の TDZ (Temporal Dead Zone) 対応**
  - `for (let x of [x])` や `for (let x in { x })` で TDZ エラーを投げる
  - iterable/object 式を binding 環境で評価するように修正
- **Passed: 12,240 → 12,300 (+60)**

### 以前の修正 (super対応) - 完了
- クラスのコンストラクタ/メソッド内での super.xxx 参照が動作するよう修正
- extends なしでも super は Object.prototype を参照
- static メソッドでは super は親クラス（または Function.prototype）を参照
- getter/setter 内での super 対応
- オブジェクトリテラルのメソッド内での super（`__home_object` 実装）
- generator メソッド内での super 対応
- クラスフィールドのアロー関数内での super 対応
- `__super_proto` 等の内部プロパティを non-enumerable に設定
- **"super is not defined" エラー: 18 → 0 件に解消**

---

## SKIPの内訳

| 理由 | 件数 | 優先度 |
|------|------|--------|
| async flag (async/await tests) | 4,163 | 低 |
| with statement not supported | 2,448 | 対応しない |
| missing includes: propertyHelper.js | 1,800 | 中 |
| fixture | 252 | - |
| module syntax | 221 | 中 |
| missing includes: asyncHelpers.js | 122 | 低 |
| missing includes: fnGlobalObject.js | 41 | 低 |
| missing includes: tcoHelper.js | 34 | 低 |

---

## ERRORの内訳 (パースエラー)

| エラーパターン | 件数 | 対応方針 |
|----------------|------|----------|
| Unexpected token: Import | 184 | dynamic import構文 |
| Expected RBrace, got Eof | 146 | パーサー修正 |
| Expected 'from' in import/export | 75 | import defer構文 |
| Expected Colon, got Star | 62 | オブジェクトメソッド短縮構文 |
| Expected LBrace, got LParen | 24 | class式パース |
| Unexpected token: Slash | 23 | 正規表現リテラル |
| Expected identifier, got Eof | 20 | 不完全パース |
| Expected base class name, got Class | 11 | class extends |

---

## FAILの内訳

### エラータイプ別

| エラーパターン | 件数 | 優先度 |
|----------------|------|--------|
| Expected an error to be thrown | 663 | 高 |
| Expected SyntaxError but got TypeError | 69 | 中 |
| negative mismatch (parse phase) | 67 | 中 |
| Cannot read properties of null/undefined | 50 | 高 |
| value is not callable | 44 | 高 |
| Expected SyntaxError but got ReferenceError | 44 | 中 |
| Assertion failed | 34 | 中 |
| super is not defined | 0 | 完了 |
| using is not defined | 21 | 低 (ES2024) |
| Spread value is not iterable | 16 | 中 |

### 機能別

| 機能領域 | FAIL数 | 主な問題 |
|---------|--------|----------|
| class | 613 | strict mode, private fields, static |
| compound-assignment | 115 | strict mode エラー処理 |
| for-of | 98 | イテレータ、destructuring |
| super | 49 | super参照解決 |
| object | 44 | メソッド定義、getter/setter |
| assignment | 36 | strict mode |
| generators | 32 | yield式の値 |
| yield | 30 | generator関連 |
| logical-assignment | 30 | ??=, &&=, ||= |
| function | 35 | strict mode |

---

## 優先度順 修正タスク

### P0: 高優先度 (影響範囲大)

1. **[ ] strict mode エラー処理 (~800件)**
   - 未宣言変数へのassignでReferenceErrorを投げる
   - arguments/eval への代入禁止
   - 重複引数名禁止
   - 関連: compound-assignment, assignment, class

2. **[x] superキーワード対応 (完了)**
   - [x] クラスコンストラクタ/メソッド内での super.xxx
   - [x] extends なしでも Object.prototype を参照
   - [x] static メソッド内での super
   - [x] getter/setter 内での super
   - [x] オブジェクトリテラルのメソッド内での super (`__home_object`)
   - [x] generator 内での super
   - [x] クラスフィールドのアロー関数内での super
   - ファイル: `parser_class.mbt`, `interpreter_eval.mbt`, `interpreter_iter_eval.mbt`

3. **[ ] null/undefined のプロパティアクセス (~50件)**
   - 適切なTypeError投げ
   - メッセージ改善

4. **[ ] イテレータプロトコル完全対応 (~100件)**
   - for-of での正しいイテレータ呼び出し
   - Symbol.iterator対応
   - iterator.return() / throw() 呼び出し

### P1: 中優先度

5. **[ ] private fields / methods (~50件)**
   - `#field` 構文のパース
   - WeakMap的アクセス制御

6. **[ ] generator関数の値 (~60件)**
   - yield式の戻り値
   - .next(value) の引数伝播

7. **[ ] オブジェクトリテラル拡張**
   - shorthand method: `{ foo() {} }`
   - computed property names in methods
   - getter/setter with super

8. **[ ] パースエラー修正 (~300件)**
   - dynamic import `import()`
   - 正規表現リテラル `/pattern/flags`
   - オブジェクトメソッド短縮構文

9. **[ ] propertyHelper.js 対応 (~1800件 skip解除)**
   - Object.getOwnPropertyDescriptor
   - Object.defineProperty
   - property descriptor support

### P2: 低優先度

10. **[ ] module構文完全対応 (~220件)**
    - import defer
    - import attributes
    - re-exports

11. **[ ] async/await (~4000件)**
    - Promise対応
    - async function
    - async generator

12. **[ ] using declaration (ES2024, ~50件)**
    - `using` キーワード
    - Symbol.dispose

---

## 対応しない項目

- **with statement** (2,448件): 非推奨、strict modeで禁止
- **tcoHelper.js** (34件): 末尾呼び出し最適化
- **eval strict mode の一部**: 複雑すぎる仕様

---

## 次のアクション

1. strict mode エラー処理の実装
2. superキーワードの参照解決
3. パーサーの正規表現リテラル対応
