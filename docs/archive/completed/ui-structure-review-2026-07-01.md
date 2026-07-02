# UI・ゲーム構造レビュー（2026-07-01）

全画面スクリプト（title / character_select / map / combat / event / shop / rest / game_over）、
Autoload 16本、MapGenerator、SaveManager、実装仕様書、`残りタスク.md` を突き合わせたレビュー。
`残りタスク.md` に既出の項目（オーディオ組み込み、カード詳細ポップアップ横展開、インベントリUI等）は重複記載しない。

凡例は `残りタスク.md` に合わせる: **[CRITICAL] / [HIGH] / [MEDIUM] / [LOW]**

---

## A. 「静かに壊れている」系の確認済み不具合

CLAUDE.md の「宣言したデータフィールドは必ず消費側で読む」「効果がコンテキスト上no-opにならないことを確認する」に抵触する現行の実例。

### A-1. [HIGH] 休息回復に同行者ボーナスが乗らない

`GameManager.get_rest_heal_percent()`（`autoload/game_manager.gd:301`）は
`CompanionData.rest_heal_bonus_percent` を合算する設計だが、**呼び出し元がゼロ**。
`rest_screen.gd:16` は `player_max_hp * 50 / 100` を直書きしており、
同行者の休息ボーナスがデータ・説明文ごと死蔵されている。
→ `_on_rest()` と `_update_display()` の両方を `get_rest_heal_percent(50)` 経由に変更する。

### A-2. [HIGH] セーブがマップノードの `faction` / `site` を保存しない

`save_manager.gd:197-211`（`_serialize_map_nodes`）と `save_manager.gd:160-173`（復元側）は
`row/col/type/position/connections/visited/fuel_reward` のみ扱う。
MapGenerator は全ノードに `faction` / `site` を設定する（`map_generator.gd:125-126`）ため、
**コンティニュー後は全ノードが「無勢力/荒野」に落ち**、ボタンの勢力ラベル・枠色・ツールチップが嘘になる。

### A-3. [HIGH] QuestManager の状態がセーブ対象外

`quest_manager.gd` の `_state` / `_armed`（サブストーリー進行・遅延ペイロード・ボス修飾）が
`save_run()` に含まれない。導入イベントでクエストを受けた直後に中断すると、
コンティニュー後は hunt 進捗もボス修飾も消える。`残りタスク.md` §2（クエスト接続）の検証前に塞ぐべき。

### A-4. [HIGH] キャラ固有ゲージのセーブ漏れ（euphoria のみ保存）

`save_run()` は `player_euphoria` だけ保存する（`save_manager.gd:50`）。
`player_heat` はノードをまたいで持ち越す設計（イベント条件 `heat>=` / `heat_max`、追跡ゲージ連動）なのに
保存されず、中断復帰で 0 に戻る。`GameManager.pursuit_level` は保存されるのにその源泉のヒートが消えるため、
元レイダーのラン中断は実質的に状態リセットになる。faith は保存済み、heat だけが漏れている。

### A-5. [MEDIUM] セーブタイミングにより戦闘スキップが可能

`map_screen.gd:219` はノード入場直後（`visited=true` を立てて `advance_node()` した後、
戦闘開始前）に `save_run()` する。戦闘ノードで不利になったらアプリを終了→コンティニューで、
**その戦闘を戦わずにマップへ復帰できる**（ボス戦含む）。
対策例: 戦闘系ノードでは「未消化ノードタイプ」をセーブに含め、ロード時に該当戦闘へ直行させる。

### A-6. [MEDIUM] ショップの品揃えが購入のたびに再抽選される

`shop_screen.gd` は購入ハンドラ全部（`_on_buy` / `_on_buy_card` / `_on_buy_part` / `_on_buy_item`）が
`_build_shop()` を呼び直し、その中で `card_pool.shuffle()` / `all_parts.shuffle()` / `all_items.shuffle()`
が再実行される。**安い物（スクラップ3燃料）を買うたびにカード/パーツ/アイテムの在庫がリロール**され、
実質無限リロールになる。在庫は `_ready()` で一度だけ抽選して配列に保持し、再描画は在庫から行う。

### A-7. [MEDIUM] `_on_heat_changed` に紛れ込んだ共通UI初期化

`combat_screen.gd:552-555` で EndTurnButton 等の `focus_mode = FOCUS_NONE` 設定と
「ターン終了 (Space)」のテキスト/操作ヒント設定が **ヒート変化ハンドラ内**にある。
ヒート持ち（元レイダー）以外のキャラではこのコードが一度も走らず、
キーボードヒントが表示されない・ボタンがフォーカスを持ち Space がボタン誤発火し得る。
`_ready()` へ移動する。

### A-8. [MEDIUM] 燃料切れソフトロック（「エンスト」エンドが存在しない）

移動燃料が足りない場合は通知を出すだけ（`map_screen.gd:201-204`）。
最小移動コストは2以上（距離+1、同行者でさらに+1）で燃料は0まで減るため、
**全ルートが支払えない状態になると無限待機**になる。ゲームオーバー画面のタイトルは
「エンストした」なのに、実際にエンストで終わる経路がコードに無い。
→ 通知後に「移動可能なノードが一つも無い」判定を行い、
`pending_result = &"defeat"` で結果画面へ送る（または救済イベントを挟む）。

### A-9. [LOW] 未使用シグナル・死にコード

- `ResourceManager.fuel_warning`（`resource_manager.gd:7`）: 購読者ゼロ。燃料警告UIが未実装のまま
  シグナルだけ存在する。マップHUDの燃料ラベル色替え等で消費するか、削除する。
- `map_screen.gd:372` `_enter_pursuit_combat()`: 呼び出し元ゼロ。`_start_pursuit_combat()` と重複しており、
  こちらだけ「コカトリスの追手」通知を出す（通知内容の食い違いも含めて統合・削除する）。
- `combat_screen.gd:1294` `_on_card_played()`: 空実装。

---

## B. ゲーム構造（アーキテクチャ）

### B-1. [HIGH] 画面遷移の分散と `GameState` の形骸化

`change_scene_to_file()` の直書きが 8 ファイル・十数箇所に散っており、
`GameManager.GameState` / `change_state()` は `start_run` / `end_run` / `go_to_title` 以外から
ほぼ呼ばれない（COMBAT/SHOP/REST/EVENT への遷移で state は更新されない）。
`state_changed` の購読者も実質いない。

→ `GameManager.goto(GameState.XXX)` に「シーンパス解決 + change_state + 遷移」を一元化する。
効果: シーンパスのタイポ耐性、遷移前後のフック（セーブ・BGM切替・トランジション演出）の置き場が
一箇所になり、A-5（セーブタイミング）や `残りタスク.md` §11（オーディオ組み込み）の実装先にもなる。

### B-2. [HIGH] `combat_manager.gd`（1,929行）のキャラ固有システム分離

6キャラ分の固有システム（gear/heat/investigation/aura/euphoria/partner）の状態変数・定数・
ロジックが全部 CombatManager に同居し、`_apply_card_effects()`（443〜772行）はカードID
（`er01`, `co08`, `wa06`, `eu11`…）の分岐羅列になっている。CLAUDE.md 自身が
「ID分岐に頼らず、データ駆動の属性でスケールさせる設計を優先する」と定めており、
`残りタスク.md` §11 にも「`scripts/systems/` の分離方針を決める」とある。

段階的な提案:
1. まず固有ゲージ（heat/aura/gear/…）を `scripts/systems/unique_system_*.gd`（RefCounted）へ抽出し、
   CombatManager は `unique_system` 名からインスタンスを引くだけにする。
   シグナルは既存のまま CombatManager が中継すれば UI 側は無改修で済む。
2. カード特殊効果は「ID → Callable」の登録テーブル化から始める（match の羅列を辞書に置換するだけでも
   追加時の見通しが違う）。将来的には `CardData` に効果タイプ+パラメータを持たせてデータ駆動へ。

### B-3. [MEDIUM] `combat_screen.gd`（1,734行）のコンポーネント分割

1ファイルに同居しているもの: ツールチップシステム、ポートレートHUD、固有ゲージ表示×5、
敵パネル生成、カードボタン生成、報酬画面、ステータス/バフ名カタログ、画面演出。
少なくとも以下は `.tscn` + スクリプトのコンポーネントに切り出す価値がある:

- **EnemyPanel**（`_build_enemy_display` の中身。8本の並行配列 `hp_labels`/`hp_bars`/… を
  1パネル1スクリプトに畳める）
- **CardButton**（戦闘手札・報酬・後述のデッキ閲覧で共用。`残りタスク.md` §7/§8 の
  「カード詳細ポップアップ/比較表示の横展開」の受け皿になる）
- **RewardPanel**（`_show_reward_screen` 以下 約170行）
- ステータス/バフの表示名・説明カタログ（`_status_display_name` 等）は UI ヘルパーか
  データ側へ移し、他画面からも参照可能にする

### B-4. [MEDIUM] Theme 不在によるスタイル定義の重複

ほぼ全てのUIが `Button.new()` + `StyleBoxFlat` のコード直書きで、プロジェクト Theme が無い。
「角丸8px・ボーダー2px」のスタイル構築コードが combat/map/shop 等に十数回コピーされている。
全体 Theme リソース（フォントサイズ、Button/Panel の既定 StyleBox）を1つ作り、
色分けが必要な箇所（レアリティ・勢力色）だけ `theme_type_variation` かコードで上書きする。
フォントサイズの散在（12〜32を個別指定）も Theme に寄せると画面全体の調整が一括でできる。

### B-5. [MEDIUM] 通知ダイアログ／デッキ一覧の画面別再実装

- 通知: `map_screen.gd:449`（`_show_notification_then`）はモーダルオーバーレイ無しで
  **背後のマップノードがクリック可能**（`_awaiting_fragment` ガードはフラグメント経路のみ）。
  一方 `_show_ambient_fragment` や combat の詳細ポップアップはオーバーレイ付き。挙動が不統一。
- デッキ一覧: map の `_show_deck_popup`、shop の削除リスト、rest の強化リストがそれぞれ別実装。

→ `scenes/ui/` に共通 `NotificationDialog`（オーバーレイ+チェーン再生対応）と
`DeckListPopup`（表示のみ/選択モード）を作り、4画面から差し替える。
通知チェーン中の多重入力事故（A-8 とは別の入力系バグの温床）がこれで塞がる。

### B-6. [LOW] `event_flags` の名前空間混在

`GameManager.event_flags` にイベントid・`sets_flag` の任意フラグ・`unique_%s_joined`・
`companion_%s_sleep_counter`（カウンタ=非bool値）が同居している。
イベントidと `sets_flag` の値が偶然衝突すると「未遭遇イベントが遭遇済み扱い」になる。
プレフィックス規約（`ev_` / `flag_` / `sys_`）を決めるか、用途別に辞書を分ける。

### B-7. [LOW] 最終ボス対応表のハードコード

`map_screen.gd:328-335` の `boss_by_character` 辞書はキャラid→ボスidの直書き。
`CharacterData` に `@export var final_boss_id: StringName` を持たせてデータ駆動にすれば、
GDDとの同期監査（`残りタスク.md` §5）の対象に自然に入る。
同種の直書きとして、医薬品回復量15（`map_screen.gd:685`）と休息50%（`rest_screen.gd`）も
定数または `.tres` へ寄せる。

---

## C. UI/UX 改善

### C-1. [HIGH] ゲームオーバー画面に再挑戦導線が無い

`game_over.gd` は「タイトルへ」のみ。ローグライトの再走導線として
「同じキャラでもう一度」ボタン（`GameManager.start_run(current_character)` →マップ遷移）を追加する。
現状はタイトル→ニューゲーム→キャラ選択→開始の4操作が毎ラン必要。
なお `end_run()` を結果表示画面の `_ready()` 内で呼ぶ構造（表示とステート更新の同居）も、
このボタンを足すなら「遷移前に end_run を済ませる」形に直しておくと安全。

### C-2. [HIGH] キャラ選択画面の情報量

表示は「名前・HP・固有システム名・デッキ上限」のみ（`character_select.gd:49-52`）。
選択の判断材料として最低限、固有システムの1行説明・初期デッキ概要・ポートレート
（`assets/characters/portraits/` に資産あり）を出す。ロック中キャラの `unlock_condition`
表示は良い実装なので、同じ粒度を選択可能キャラにも。

### C-3. [MEDIUM] 手動offset配置とレイアウト耐性

`combat_screen.tscn` の PlayerHUD 内ラベル群や、コードで生成する固有ゲージラベル
（`offset_left = 235.0` 等の絶対座標が combat_screen.gd に5箇所コピー）は、
1920x1080 前提の絶対配置。`canvas_items` ストレッチで破綻はしないが、
ラベル追加のたびに座標手計算が必要で、実際に5つの固有ゲージが全て同座標に生成される
（同時に出ないので衝突しないが、構造としては脆い）。
PlayerHUD 内を VBoxContainer 化し、固有ゲージは1つの `GaugeLabel` を使い回す。

### C-4. [MEDIUM] マップの現在地スクロール

マップは横スクロール（MapScroll）だが、`_draw_map()` 後に現在ノードへ
`scroll_horizontal` を合わせる処理が無い。後半区間や横長マップで毎回手スクロールになる。
`_ready` / ノード移動後に現在ノードが画面内に来るようスクロール位置を設定する。

### C-5. [MEDIUM] キーボード操作の適用範囲

戦闘は数字キー/Space/Esc 対応済み（`combat_screen.gd:1131`）だが、
報酬選択・イベント選択肢・マップには無い。少なくとも報酬画面とイベント選択肢は
数字キー選択に対応させると、戦闘→報酬の操作感が途切れない。
（A-7 の修正で全キャラに操作ヒントが出るようになるのが前提）

### C-6. [LOW] ツールチップ表現の不統一

combat は自前ツールチップ（遅延表示・枠色付き）、map は Godot 標準 `tooltip_text`。
見た目と挙動が違う。B-3 でツールチップシステムを切り出すなら、map のノード詳細・
同行者詳細も同システムに乗せる。

### C-7. [LOW] 燃料警告の可視化

A-9 の `fuel_warning` を接続し、マップHUDの燃料ラベルを `warning/danger` で色替え、
`danger` 以下でノード選択時に「この移動で燃料が尽きる」確認を出す。
A-8（ソフトロック対策）とセットで実装すると自然。

---

## D. 推奨着手順

| 順 | 項目 | 理由 |
|---|---|---|
| 1 | A-1, A-2, A-3, A-4（セーブ/消費漏れ） | 修正が小さく、コンティニューとクエスト検証（残りタスク§1-2）の前提になる |
| 2 | A-6（ショップ再抽選）, A-8（燃料ソフトロック） | ゲームループの穴。プレイテスト（残りタスク§10）の数値を汚す |
| 3 | A-7, C-1, C-4（操作導線の小修正） | 各1時間未満でプレイ体験が確実に改善する |
| 4 | B-1（遷移一元化） | 以降のセーブ/オーディオ/演出フックの土台 |
| 5 | B-4 + B-5（Theme・共通UI部品） | 残りタスク§7-8（ポップアップ/比較表示の横展開）の前にやると横展開コストが下がる |
| 6 | B-2, B-3（大型ファイル分割） | 機能追加が続く限り効くが、単独では挙動が変わらないため上記の後 |
