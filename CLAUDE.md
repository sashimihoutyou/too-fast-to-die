# CLAUDE.md

## プロジェクト概要

Godot 4.7 / GDScript製のSlay the Spire風カードバトルローグライト「Too Fast to Die: Road to Oasis」。

## ロア作成ルール

- 敵・集落・NPC・勢力拠点・イベント背景・アイテム由来などのロアを作成/改修する際は、必ず `docs/lore-rules.md` を先に参照する。
- ロアは「一目でイカれた世界だとわかる」が、世界内では水・燃料・人口・情報をめぐる生存戦略として機能していること。
- ロアを追加したら、必要に応じてGDD、イベント、`.tres` データ、マップノードの勢力/施設種別との整合を確認する。

## ビルド・実行

- エンジン: Godot 4.7 (Mobile renderer)
- メインシーン: `res://scenes/main/title_screen.tscn`
- Autoloadの登録順序は `project.godot` の `[autoload]` セクションで管理
- PowerShell で日本語ファイルを読む場合、既定の `$OutputEncoding` が US-ASCII だとツール出力だけ文字化けする。ファイル自体の破損と誤認しないこと。`Get-Content -Encoding UTF8`、または `[System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($path))` で確認する。
- Godot のプロジェクトロード/検証は `.godot` と Scoop の `editor_data` に cache/temp/settings を書き込む。サンドボックス内で実行するとポップアップや偽の書き込みエラー、クラッシュに見える失敗が出るため、`godot --headless --editor --quit --path .` や実行確認は権限昇格で行う。
- `godot --headless --check-only --script some_file.gd` は `class_name` と Autoload のプロジェクトスキャンを行わないため、通常プロジェクトで解決される `GameManager` 等が未定義になる。単体スクリプト検証結果をプロジェクト全体のパースエラーと混同しないこと。

## GDScriptコーディング規約

### Variant推論の禁止

Godot 4.7はデフォルトで「Variantからの型推論」を警告→エラーとして扱う。
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

### コンテナの mouse_filter とボタンの重なり

`VBoxContainer` / `HBoxContainer` 等のコンテナは、デフォルトの `mouse_filter` が `MOUSE_FILTER_STOP` であり、**子ノードが空でも自身の rect 内のマウスイベントを奪う**。同じ親の下でコンテナがボタンより後（子インデックスが大きい＝Z-orderが上）に配置されていると、コンテナの rect がボタンを覆い隠し、**ボタンが一切クリックできなくなる**。

実例（修正済み）: 休息画面の `CardContainer`（VBoxContainer, 子index=6）が `RestButton`（index=4）/ `UpgradeButton`（index=5）と同じ Y 座標に配置されていた。CardContainer は空だが rect は offset で確保されており、MOUSE_FILTER_STOP のままだったため全ボタンが操作不能になった。

- 動的にボタンを追加するコンテナは `mouse_filter = Control.MOUSE_FILTER_IGNORE`（tscn: `mouse_filter = 2`）を設定する。コンテナ自身はイベントを通過させ、子ボタンは独自の mouse_filter で正常に受け取る。
- tscn を編集したら、同じ親の下でコンテナと固定ボタンの **rect が重なっていないか** を Z-order（子の並び順）を含めて確認する。

```
# NG: 空のVBoxContainerがボタンを覆い、クリック不能
[node name="RestButton" type="Button" parent="."]
offset_top = 240.0
[node name="CardContainer" type="VBoxContainer" parent="."]
offset_top = 240.0  # ← RestButtonと同じ領域を覆う (indexがButtonより後)

# OK: mouse_filter = 2 (IGNORE) でコンテナ自身はイベントを通過させる
[node name="CardContainer" type="VBoxContainer" parent="."]
mouse_filter = 2
offset_top = 240.0
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

### コールバックチェーンでの中間結果チェック

確認ダイアログの「保存してから続行」のように、コールバック内で副作用（保存・削除等）を実行してから次のアクション（画面遷移・エディター閉じ等）を呼ぶ場合、副作用の成否を確認せずに後続を実行すると、失敗時にも処理が進んでしまう。副作用が失敗しうるなら、成否を返すメソッドに分離して結果をチェックすること。

```gdscript
# NG: 保存失敗でもon_proceedが呼ばれる
dialog.confirmed.connect(func() -> void:
    _do_save(resource, path)
    on_proceed.call()
)

# OK: 保存結果を確認してから続行
dialog.confirmed.connect(func() -> void:
    var err: Error = _do_save_and_return(resource, path)
    if err != OK:
        return
    on_proceed.call()
)
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

### `--script` モードでの `class_name` 未解決

`godot --headless --script` でスタンドアロン実行する場合、Godotはプロジェクト全体の `class_name` スキャンを行わない。別ファイルで `class_name Foo` と宣言しても、`--script` のエントリポイントからは `Foo` が見えず `Could not find type "Foo"` パースエラーになる。`preload()` で明示的にスクリプトを読み込むこと。

```gdscript
# NG: --script モードでは class_name が解決されない
var audit := DataAudit.new()

# OK: preload で明示的に読み込む
const DataAuditScript := preload("res://tools/sim/data_audit.gd")
var audit: RefCounted = DataAuditScript.new()
```

`preload` 経由の `.new()` は戻り値が Variant になるため、`:=` ではなく明示的な型注釈を付けること（Variant推論の禁止ルールと同根）。

### `--script` モードでの Autoload グローバル未解決

`--script` モードでは `GameManager` / `CombatManager` 等のAutoloadシングルトンもコンパイル時に識別子として解決されない（`Identifier not found` エラー）。`class_name` は `preload` で解決できるが、Autoloadは実行時にSceneTreeに追加されるため別の対処が必要。

**エントリポイント（`extends SceneTree`）**: 同名のインスタンス変数を定義し、`_process()` 内で `root.get_node()` により解決する。既存コードの `GameManager.xxx` 呼び出しはインスタンス変数を参照するためそのまま動く。

```gdscript
# OK: 同名インスタンス変数でAutoloadグローバルをシャドウする
var GameManager
var CombatManager

func _process(_delta: float) -> bool:
    GameManager = root.get_node("GameManager")
    CombatManager = root.get_node("CombatManager")
    _run()
    quit()
    return true
```

**ヘルパースクリプト（`extends RefCounted`）**: `root` にアクセスできないため、コンストラクタ引数で参照を受け取る。

```gdscript
var CombatManager
var DeckManager

func _init(combat_mgr, deck_mgr) -> void:
    CombatManager = combat_mgr
    DeckManager = deck_mgr
```

**Variant伝播に注意**: シャドウ変数は型注釈なし（Variant）なので、そのメソッド呼び出しやプロパティアクセスの戻り値も全てVariantになる。`:=` で受けると「Variant推論の禁止」ルールに抵触する。Autoloadシャドウ変数経由の値は必ず明示的型注釈で受けること。

```gdscript
# NG: EnemyDatabase がVariant → get_enemies_for_act() の戻り値もVariant → 推論エラー
var pool := EnemyDatabase.get_enemies_for_act(act)

# OK: 明示的型注釈
var pool: Array[EnemyData] = EnemyDatabase.get_enemies_for_act(act)

# OK: float() 等の組み込みキャストで包めばキャスト先の型に確定するため := でも可
var hp_pct := float(CombatManager.player_hp) / float(CombatManager.player_max_hp)
```

**`static` 関数からのAutoload参照**: `--script` モードでは依存先ファイル（`class_name` で参照されるスクリプト等）も再コンパイルされる。`static` 関数内でAutoloadグローバルを直接参照していると `Identifier not found` になる。`Engine.get_main_loop()` 経由で実行時に解決すること。

```gdscript
# NG: static関数内で ItemDatabase を直接参照 → --script モードでコンパイルエラー
static func calculate_cost() -> int:
    if ItemDatabase.has_relic(&"old_compass"):
        return 0

# OK: Engine.get_main_loop() 経由で実行時に解決
static func calculate_cost() -> int:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if tree and tree.root.has_node("ItemDatabase"):
        var item_db = tree.root.get_node("ItemDatabase")
        if item_db.has_relic(&"old_compass"):
            return 0
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

### GDDと.tresの数値を同期する

GDD（設計文書）と `.tres`（実データ）の両方に `max_hp`・`unlock_condition`・`deck_limit` 等の数値が存在する。片方だけ更新すると食い違いが静かに蓄積し、どちらが正しいか判断できなくなる。実例: ヴェスパHP（GDD 75 / .tres 70）、ウェズリーdeck_limit（GDD 20 / .tres 25）、アンロック条件3件が全て不一致だった。

- 数値を変更するときは**GDDと.tresを同時に更新する**。
- `.tres` の `unlock_condition` は表示用文字列であり、実際のロジックは `meta_progression.gd` にある。3箇所の整合を確認すること。

### GDDへの追記は「末尾に足す」のではなく挿入位置を決めてから採番する

`docs/gdd-*.md` の番号付きサブセクション（`27-1`, `27-5b` 等）に同一セッション内で複数回追記した結果、末尾へ足し続けたことでキャラクター単位の記述がファイル内で分断された（例: 元レイダーの内容が `27-1` / `27-10` / `27-15` の3箇所に分裂）。追記のたびに動作は正しくても、**採番と挿入位置の一貫性はエラーにならず静かに崩れる**——`status_effect` の `pass` 握りつぶしと同じ「レビューしないと気づけない」種類の劣化。

- 既存の番号付きセクションに新項目を足すときは、**関連する既存項目のグループ内に挿入**し、そのグループ内の連番（`27-5b` のような枝番）を使う。ファイル末尾への追記は最終手段。
- 同一トピックへの追記が3回目以降に及ぶ、あるいは既存の番号体系（キャラ単位・章単位等）を横断して末尾に積み増している場合は、その時点で一度立ち止まって並び順を整理する。
- セクション番号を採番し直した場合、**同一ファイル内の相互参照だけでなく他ファイルからの `§27-x` 形式の参照も必ず`grep`で洗い出して追従させる**。片方だけ直すと参照切れが残る。

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
