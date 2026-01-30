# test262 進捗

## 現状 (2026-01-30)

| カテゴリ | Passed | Total | 達成率 |
|---------|--------|-------|--------|
| language/statements | 6,527 | 9,337 | 70% |
| language/expressions | 6,145 | 11,093 | 55% |
| language/module-code | 387 | 737 | 52% |
| **language 合計** | **13,059** | **21,167** | **62%** |

### 機能別

| 機能 | Passed | Total | 達成率 |
|------|--------|-------|--------|
| async-generator | 638 | 924 | 69% |
| template-literal | 43 | 57 | 75% |
| for-of | 589 | 751 | 78% |

---

## 次にやるべきこと

### 高優先度

1. **strict mode エラー処理**
   - arguments/eval への代入禁止
   - 重複引数名禁止
   - 影響: ~800件

2. **async generator の yield* 対応**
   - 現在 125件失敗中
   - yield* の thenable 処理

3. **iterator.return() / throw()**
   - ループ中断時のクリーンアップ
   - for-of の early termination

### 中優先度

4. **正規表現リテラル パーサー**
   - `/pattern/flags` 構文
   - 影響: ~23件のパースエラー

5. **Symbol 完全対応**
   - Symbol.iterator → @@iterator (現在の代替)
   - Well-known symbols

### 低優先度 (ES2024+)

- `using` declaration
- import defer
- import attributes

---

## 対応しない項目

- with statement (非推奨)
- eval の一部高度な機能
- 末尾呼び出し最適化 (TCO)

---

## スキップ理由の内訳 (18,698件)

| 理由 | 件数 |
|------|------|
| negative (エラーを期待するテスト) | 4,669 |
| temporalHelpers.js (Temporal API) | 2,690 |
| eval 関連 | 1,418 |
| TypedArray 関連 | 1,815 |
| with statement | 497 |
| Function constructor | 322 |
| Intl (国際化) | 175 |
