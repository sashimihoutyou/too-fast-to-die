# CLAUDE.md

## プロジェクト概要

Godot 4.6 / GDScript製のSlay the Spire風カードバトルローグライト「Road to Oasis」。

## ビルド・実行

- エンジン: Godot 4.6 (Mobile renderer)
- メインシーン: `res://scenes/main/title_screen.tscn`
- Autoloadの登録順序は `project.godot` の `[autoload]` セクションで管理

## GDScriptコーディング規約

### Variant推論の禁止

Godot 4.6はデフォルトで「Variantからの型推論」を警告→エラーとして扱う。
`Array.pop_back()`、`Array.pop_front()`、`Dictionary.get()` など Variant を返すメソッドの戻り値を `:=` で受けてはならない。

```gdscript
# NG: Variant推論エラーになる
var card := draw_pile.pop_back()
var value := some_dict.get("key")

# OK: 明示的に型を指定する
var card: CardData = draw_pile.pop_back()
var value: int = some_dict.get("key", 0)
```

対象となる主なメソッド:
- `Array.pop_back()`, `Array.pop_front()`, `Array.back()`, `Array.front()`
- `Dictionary.get()`, `Dictionary.values()` の要素アクセス
- 型付き配列でない `Array` の `[]` アクセス

### その他の型安全ルール

- 変数宣言には可能な限り型注釈を付ける
- `for` ループの変数にも型を付ける（例: `for card: CardData in hand:`）
- シグナル引数にも型を指定する

## ディレクトリ構成

```
autoload/          Autoloadシングルトン
scripts/data/      カスタムResourceクラス (CardData, EnemyData等)
scripts/combat/    戦闘関連ロジック
scripts/map/       マップ生成
scripts/systems/   キャラ固有システム
scenes/            各画面の .tscn + .gd
resources/         .tres データファイル
```
