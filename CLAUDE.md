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

**Variantは演算をまたいで伝播する。** `and` / `or` / 比較 / 算術の被演算子に素のVariant
（辞書アクセス等）が一つでも混ざると、式全体がVariant扱いになり `:=` で受けるとパースエラーになる。
「結果は明らかに `bool`」と思っても推論は通らない。Variantは**式に入れる前に明示キャスト**で潰すか、
受け側に型注釈を付けること（実例: `enemies[i]["alive"]` を `and` に直接混ぜてパースエラー）。

```gdscript
# NG: enemies[i]["alive"] が Variant → and の結果も Variant → 推論エラー
var show_it := visible_flag and enemies[i]["alive"]

# OK-1: 受け側に型注釈を付ける
var alive: bool = enemies[i]["alive"]
var show_it: bool = visible_flag and alive

# OK-2: 式に入れる前に明示キャストで潰す（本コードベースの標準イディオム）
var dmg := base + int(player_status.get("strength", 0))
var hp_pct := float(enemy["hp"]) / float(enemy["max_hp"])
```

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

### 宣言したデータフィールドは必ず消費側で読む

`CardData.status_effect` / `CharacterData.unique_system` / `can_use_guns` /
`ResourceManager.bike_durability` のように、Resource に `@export` したフィールドが
**消費側ロジックで一度も読まれていない**と、エラーも警告も出ずに静かに無効化される。
カードの説明文（「萎縮2付与」「炎上3」等）だけが残り、実際には何も起きない＝
**説明文が嘘になる**バグが発生した（実例: `_apply_card_effects` が `status_effect` を
`pass` で握りつぶしていた）。

- 新しいフィールドを追加したら、それを読む側のコードを必ず同時に実装する。
- 仮実装（stub）で `pass` する場合は `# TODO` を残し、説明文・データを伴わせない。
- 「データはあるのに動かない」を検出するため、対応する効果が未実装の `status_effect` 等は
  既知値へのマッピングで弾き（`_map_status` が未知を `&""` で返す）、明示的に無視と分かる形にする。
- 対価（燃料消費等）は効果を適用する直前に行う。実例: ショップの「カード削除」が
  `consume_fuel()` 後に `pass` で何もせず、**燃料だけ失う**バグがあった。`match` の分岐や
  選択フローで対価を先払いする場合、その分岐が実際に効果を持つことを必ず確認する。

### 効果がコンテキスト上no-opにならないことを確認する

ロジックが正しく動いていても、実際のデータとの組み合わせで**効果がゼロ**になるケースがある。
コードにバグは無いため静かにスルーされ、カードが「存在するが無意味」になる。

実例（修正済み）: 旧フルスロットルの「APコスト半減（端数切上）」は `(1+1)/2 = 1` となり、
初期デッキの1コストカードに対して**一切コストが下がらない**状態だった。
現在はアルティメット（AP-1固定）に置き換え済み。

- 数値効果を実装したら、**最も一般的な使用状況**（初期デッキ・序盤の敵等）で
  実際に意味のある差が出るかを検算する。
- 端数処理（切上・切捨）や下限（0）が効果を殺さないか確認する。

### 未実装システムの情報をUIに表示しない

`description` に「→ 強化: 9」のようにまだ動作しないシステムの情報を
含めると、プレイヤーに誤解を与える。UIに表示するテキストは
**現時点で機能するもの**だけにする。将来の強化値等は `upgrade_description`
のような非表示フィールドに保持し、システム実装時に初めてUIへ反映する。

### 完結したゲームループを保証する

区間進行・勝利条件・次区間生成のような「ループを閉じる」処理が無いと、ボス撃破後に
行き止まり（クリック可能ノードが無い無限待機）になる。`change_scene_to_file()` で遷移が
分断される本作では、進行状態は Autoload（`GameManager.current_act` 等）に集約し、
ボス撃破→`advance_act()`→マップ再生成→最終区間で結果画面、という遷移を明示的に実装すること。

### 設定・物語の前提（タイムライン/年齢/世代/関係）の整合を検算する

物語上の事実（キャラの年齢・世代・出来事の前後関係・「誰が誰を知っているか」）は、
コードと違い**エラーを出さない**。前提同士が矛盾しても静かにプロットホールになるだけで、
パースにもテストにも引っかからない。`status_effect` が `pass` で握りつぶされるのと同じ
「静かに壊れる」系の不具合であり、見つけるには明示的な検算が要る。

実例（修正済み）: 放浪者ウェズリー（崩壊時15歳・ジョエルの旧友）と、戦後生まれのミーシャ
（ジョエルの娘）について「ミーシャはウェズリーの存在を知らない」という設定が、
**親友の娘なら面識があるはず**というタイムラインと矛盾していた。年齢・世代・崩壊からの
経過年数を数直線で突き合わせ、「ウェズリーは放浪者でジョエルの家庭に住んでいない／家族は
奴隷狩りから隠されていた／攫われた後に合流したため一度も会っていない」という整合解を補って解消した。

- 新しい設定（年齢変更・新キャラ・新エピソード）を足したら、**既存の前提と数直線で突き合わせる**。
  崩壊からの経過年数を一つの基準に固定すると検算しやすい（本作では現在＝崩壊後32年）。
- 「AはBを知らない/知っている」「AはBより年上」等の関係命題は、両者のタイムラインが許すか確認する。
- 矛盾が見つかったら設定を消すのではなく、**世界観で正当化できる整合解**（隠された家族・すれ違い等）を探す。

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
