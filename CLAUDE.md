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

### 型付き配列への代入

型付き配列プロパティ（`Array[Tag]`, `Array[CharacterRestriction]` 等）に `Dictionary.get()` やリテラル `[]` の戻り値を直接代入するとランタイムエラーになる。`assign()` を使うこと。

```gdscript
# NG: ランタイムエラー (Array を Array[Tag] に代入できない)
card.tags = data.get("tags", [])

# OK: assign() で型付き配列にコピーする
card.tags.assign(data.get("tags", []))
```

### PanelContainer と子ノードの配置

`PanelContainer` は子ノードを自動的に全面に引き伸ばすため、複数の子を手動配置（offset指定）しても全て重なる。手動配置が必要な場合は `Panel` を使い、子ノードの `layout_mode` を `1`（アンカー）にすること。

```
# NG: PanelContainer + layout_mode=2 → offset無視で全子ノードが重なる
[node name="HUD" type="PanelContainer" parent="."]
[node name="Label1" type="Label" parent="HUD"]
layout_mode = 2

# OK: Panel + layout_mode=1 → offsetが正しく適用される
[node name="HUD" type="Panel" parent="."]
[node name="Label1" type="Label" parent="HUD"]
layout_mode = 1
```

### 動的生成ノードへの参照

`get_node()` によるパス解決はノード名の自動リネーム等で失敗しやすい。動的に生成したノードは参照を配列等に直接保持すること。

```gdscript
# NG: パスが一致しない場合にnullエラー
var btn := panel.get_node("VBoxContainer/TargetButton") as Button
btn.visible = false  # null instance エラー

# OK: 生成時に参照を保持
var target_buttons: Array[Button] = []
# 生成時:
target_buttons.append(target_btn)
# 使用時:
target_buttons[i].visible = false
```

### シグナル発火前にステート更新

シグナルハンドラはUI再構築等で現在のステートを参照する。`state` の更新をシグナル発火より後に行うと、ハンドラ内で旧ステートが読まれてUIが不正になる。ステートは必ずシグナル発火前に確定させること。

```gdscript
# NG: シグナルハンドラ内でstate==CHECK_ENDのまま → can_play_card()がfalse
DeckManager.draw_cards()
turn_started.emit(turn_number)
state = CombatState.PLAYER_TURN  # 遅すぎる

# OK: シグナル発火前にステートを確定
state = CombatState.PLAYER_TURN
DeckManager.draw_cards()
turn_started.emit(turn_number)
```

### PRESET_CENTER での動的UI配置

`set_anchors_preset(Control.PRESET_CENTER)` はアンカーを0.5に設定するだけでオフセットは変更しない。`position` を設定するとアンカー位置からの追加オフセットとなり、意図せず右下にずれる。サイズの半分を負のオフセットとして明示的に指定すること。

```gdscript
# NG: positionはアンカー(中央)からのオフセット → 右下にずれる
panel.set_anchors_preset(Control.PRESET_CENTER)
panel.custom_minimum_size = Vector2(700, 400)
panel.position = Vector2(190, 120)

# OK: offsetで中央配置を明示
panel.set_anchors_preset(Control.PRESET_CENTER)
panel.custom_minimum_size = Vector2(700, 400)
panel.offset_left = -350   # -width/2
panel.offset_top = -200    # -height/2
panel.offset_right = 350   # +width/2
panel.offset_bottom = 200  # +height/2
```

### シーン遷移で失われるローカル状態

`change_scene_to_file()` で遷移すると元のシーンのスクリプト変数は全て破棄される。マップ進行状況など遷移後も必要なデータは Autoload（`GameManager` 等）に保持し、`_ready()` で毎回再生成しないこと。

```gdscript
# NG: _ready()で毎回生成 → 戦闘後に戻るとマップがリセットされる
func _ready() -> void:
    map_nodes = MapGenerator.generate_act(act)
    current_row = -1

# OK: Autoloadに保持し、未生成時のみ生成
func _ready() -> void:
    if GameManager.map_nodes.is_empty():
        GameManager.map_nodes = MapGenerator.generate_act(act)
        GameManager.map_current_row = -1
    map_nodes = GameManager.map_nodes
    current_row = GameManager.map_current_row
```

### 基底クラスメソッドのシャドウイング回避

関数パラメータやローカル変数に `show`, `hide`, `print` など基底クラス（`CanvasItem`, `Node` 等）のメソッド名を使うと `SHADOWED_VARIABLE_BASE_CLASS` 警告が出る。意味の明確な別名を使うこと。

```gdscript
# NG: CanvasItem.show() をシャドウイング
func _show_target_buttons(show: bool) -> void:

# OK: 別名を使う
func _show_target_buttons(visible_flag: bool) -> void:
```

### その他の型安全ルール

- 変数宣言には可能な限り型注釈を付ける
- `for` ループの変数にも型を付ける（例: `for card: CardData in hand:`）
- シグナル引数にも型を指定する

## データ設計のベストプラクティス

### データベースAutoloadを単一の参照元にする

`EnemyDatabase` / `EventManager` / `CardDatabase` 等は `.tres` を読み込んで保持する。
画面スクリプト側でコンテンツをハードコードすると、DBに作り込んだ大量の資産（敵・イベント等）が
**読み込まれているのに一度も使われない死蔵コンテンツ**になる。実際に区間進行が「Act1の敵を
ハードコードし続ける」「イベントが固定5種だけ」というバグが発生した。

```gdscript
# NG: 画面スクリプトが内容を直書き → DBのAct2〜5の敵が永遠に使われない
func _get_enemies_for_node(node_type):
    enemies.append(_make_enemy(&"devilwolf", "デビルフ", ..., 28, ...))

# OK: DBを参照元にし、区間(act)等の条件で取得する
func _get_enemies_for_node(node_type):
    var pool := EnemyDatabase.get_enemies_for_act(GameManager.current_act)
```

### ハードコードIDはデータのIDと一致させる

`match data.id:` のようにIDで分岐するロジックと、`.tres` の `id` が食い違うと、
**エラーにならず一般default（例: 一律6ダメージ）に静かに落ちる**ため発覚しにくい。
実例: コード側 `&"devilwolf"` / `&"wild_dog"` に対し `.tres` は `&"deviluf"` / `&"wild_dog_pack"`。

- ID分岐に頼らず、`category` や `act` 等のデータ駆動の属性でスケールさせる設計を優先する。
- どうしてもID分岐が必要なら、default節に落ちたら警告を出す等で不一致を検出可能にする。

### 完結したゲームループを保証する

区間進行・勝利条件・次区間生成のような「ループを閉じる」処理が無いと、ボス撃破後に
行き止まり（クリック可能ノードが無い無限待機）になる。`change_scene_to_file()` で遷移が
分断される本作では、進行状態は Autoload（`GameManager.current_act` 等）に集約し、
ボス撃破→`advance_act()`→マップ再生成→最終区間で結果画面、という遷移を明示的に実装すること。

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
