# 機能優先度分類

## 分類基準

| 分類 | 説明 |
|------|------|
| **P0: 必須** | 一般的なJSコードで頻繁に使用、実装コスト中〜高だが必要 |
| **P1: 重要** | 使用頻度は中程度、ベストプラクティスや特定ユースケースで必要 |
| **P2: 低優先** | 使用頻度低、または実装コストに見合わない |
| **P3: 対応しない** | 非推奨、セキュリティ上の問題、または複雑すぎる |

---

## P0: 必須（一般的なJSコードの実行に必要）

### 1. テンプレートリテラル (6,002テスト)
- **影響**: 非常に大きい。モダンJSでは文字列操作の標準
- **実装難易度**: 中
- **必要な機能**:
  - バッククォート文字列 `` `hello ${name}` ``
  - タグ付きテンプレート `` tag`template` ``
  - 複数行文字列
  - エスケープシーケンス (`\n`, `\t`, `\u{...}`)
- **現状**: パーサーでバッククォートを検出するとスキップ

### 2. イテレータプロトコル修正 (1,626テスト失敗)
- **影響**: for-of、スプレッド、分割代入すべてに影響
- **実装難易度**: 中
- **問題**: `Symbol.iterator` が正しく呼び出されない
- **失敗パターン**:
  - "value is not callable" (1,626件)
  - "Iterator result is not an object" (66件)
  - "Iterator next is not callable" (6件)
- **必要な修正**:
  - `Symbol.iterator` のルックアップ修正
  - イテレータオブジェクトの `next()` 呼び出し修正
  - `{value, done}` 結果オブジェクトの検証

### 3. Strict Mode エラー処理 (~300テスト失敗)
- **影響**: ES5以降のすべてのモジュールコード
- **実装難易度**: 低〜中
- **必要な修正**:
  - arguments/eval への代入禁止
  - 重複引数名の検出
  - 予約語の厳密なチェック
  - 8進数リテラルの禁止

### 4. エラー型の正確性 (~110テスト失敗)
- **影響**: エラーハンドリングの信頼性
- **実装難易度**: 低
- **失敗パターン**:
  - "Expected SyntaxError but got TypeError" (69件)
  - "Expected SyntaxError but got ReferenceError" (41件)
- **必要な修正**:
  - パース時のエラー検出強化
  - 適切なエラー型の選択

---

## P1: 重要（ベストプラクティス・特定ユースケース）

### 5. 正規表現リテラル (574テスト)
- **影響**: 文字列処理で頻繁に使用
- **実装難易度**: 高
- **現状**: パーサーが `/pattern/flags` を正しく解析できない
- **必要な機能**:
  - リテラル構文のパース
  - フラグ (g, i, m, s, u, y)
  - RegExp オブジェクトとの連携
- **備考**: moonbitlang/regexp クレートが利用可能

### 6. TypedArray (1,123テスト)
- **影響**: バイナリデータ処理、WebGL、Wasm連携
- **実装難易度**: 中
- **必要な型**:
  - Int8Array, Uint8Array, Uint8ClampedArray
  - Int16Array, Uint16Array
  - Int32Array, Uint32Array
  - Float32Array, Float64Array
  - BigInt64Array, BigUint64Array
- **依存**: ArrayBuffer 実装

### 7. private フィールドの name プロパティ (14テスト失敗)
- **影響**: デバッグ、リフレクション
- **実装難易度**: 低
- **問題**: `#method.name` が `__private_brand__0__#method` を返す
- **修正**: マングリング前の名前を保持

### 8. Symbol の文字列変換 (22テスト失敗)
- **影響**: デバッグ出力、エラーメッセージ
- **実装難易度**: 低
- **問題**: `Cannot convert Symbol to string`
- **修正**: 暗黙的変換を禁止、`Symbol.prototype.toString()` を許可

### 9. Generator の yield* 改善 (38テスト失敗)
- **影響**: Generator の委譲パターン
- **実装難易度**: 中
- **問題**: 委譲先のイテレータ処理が不完全

---

## P1.5: 改善中（部分的に動作）

### 10. async/await (1,210テスト追加可能)
- **現状**: 基本的なasync/awaitは動作中
- **テスト結果**:
  - async-function statements: 71/74 passed (95.9%)
  - async-function expressions: 88/93 passed (94.6%)
  - async-generator: 80/301 passed (26.6%) - 改善が必要
- **残課題**:
  - async generator の yield* 処理
  - for-await-of の完全対応
  - Promise rejection の伝播

---

## P2: 低優先（使用頻度低・コスト高）

### 11. BigInt TypedArray (692テスト)
- **影響**: 64bit整数のバイナリ処理
- **実装難易度**: 中
- **依存**: BigInt, TypedArray 両方の実装
- **理由**: 使用頻度が低い

### 12. Intl (国際化) (175テスト)
- **影響**: 多言語対応アプリ
- **実装難易度**: 非常に高
- **必要な機能**:
  - Intl.DateTimeFormat
  - Intl.NumberFormat
  - Intl.Collator
  - ロケールデータ
- **理由**: 実装コストが非常に高い

### 13. Realm / 複数コンテキスト (8テスト)
- **影響**: iframe、Worker間の通信
- **実装難易度**: 高
- **理由**: 単一コンテキストで十分なケースが多い

### 14. Atomics / SharedArrayBuffer (77テスト)
- **影響**: マルチスレッドJS
- **実装難易度**: 高
- **理由**: Wasm連携の特殊ケース

---

## P3: 対応しない

### 15. eval / Function コンストラクタ (1,254テスト)
- **理由**:
  - セキュリティリスク
  - 実行時コード生成は設計思想に反する
  - 代替手段が存在 (事前コンパイル)
- **テスト数**: eval (976) + Function (278)

### 16. with 文 (428テスト)
- **理由**:
  - ES5 strict mode で禁止
  - パフォーマンス問題
  - 可読性低下
  - 非推奨機能

### 17. Temporal API (2,690テスト)
- **理由**:
  - ES2024の新機能
  - まだ安定していない
  - 外部ライブラリで代替可能

### 18. using 宣言 (26テスト)
- **理由**:
  - ES2024の新機能
  - try-finally で代替可能

### 19. import defer (76テスト)
- **理由**:
  - ES2024の新機能
  - 通常の import で代替可能

### 20. Tail Call Optimization (34テスト)
- **理由**:
  - 実装が複雑
  - Safari以外は未実装
  - 再帰の深さ制限で代替

### 21. Resizable ArrayBuffer (188テスト)
- **理由**:
  - ES2024の新機能
  - 通常の ArrayBuffer で代替可能

---

## 実装ロードマップ

### Phase 1: 基盤強化 (P0)
1. テンプレートリテラル (6,002テスト)
2. イテレータプロトコル修正 (1,626テスト失敗の根本原因)
3. strict mode エラー処理
4. エラー型の正確性

### Phase 1.5: 継続改善 (実装中)
- async/await 改善（基本動作は完了、async generator要改善）

### Phase 2: 機能拡充 (P1)
5. 正規表現リテラル
6. TypedArray
7. private フィールド name 修正
8. Symbol 文字列変換
9. Generator yield* 改善

### Phase 3: オプショナル (P2)
- 必要に応じて対応

---

## テスト影響の推定

| 分類 | 関連テスト数 | 期待改善 |
|------|-------------|----------|
| P0 | ~8,000 | +3,000〜4,000 passed |
| P1 | ~2,500 | +1,000〜1,500 passed |
| P1.5 (async) | ~1,200 | 実装中 (+150 passed 追加見込み) |
| P2 | ~1,100 | +500〜800 passed |
| P3 | ~4,700 | (対応しない) |

**許可リスト**: 28,527件 (async/await解禁後)
**現状**: passed ~12,000 (statements + expressions + module-code)
**目標**: passed 16,000〜18,000 (P0+P1完了時)
