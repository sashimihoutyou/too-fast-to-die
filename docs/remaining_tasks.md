# Road to Oasis — 残作業リスト & 作業指示書

> 最終更新: 2026-06-24
> 対象: GDD v2 / 実装仕様書 に対する現行コードベースの差分

---

## 凡例

- **[CRITICAL]** ゲームループ・コアメカニクスに直接影響。未実装だとゲームとして成立しない
- **[HIGH]** ゲーム体験に大きく影響。プレイアブル品質に必須
- **[MEDIUM]** あると体験が向上するが、無くても一応遊べる
- **[LOW]** フレーバー・ポリッシュ。後回し可

---

## Phase 1: コア不具合・データ整合（即時対応）

### 1-1. [CRITICAL] カード強化の効果が未実装

**現状**: `rest_screen.gd:39` で `card.upgraded = true` を設定するのみ。
`CardData.get_effective_damage()` / `get_effective_block()` は `upgraded_damage` / `upgraded_block` を参照するが、
**大半の .tres ファイルで `upgraded_damage` / `upgraded_block` が 0**（＝強化しても数値が変わらない）。

**作業内容**:
1. 全120枚の `.tres` を走査し、`upgraded_damage` / `upgraded_block` が 0 のカードを洗い出す
2. GDD / 実装仕様書の「↑」表記（例: `6 (9↑)`）に基づき、各カードの強化後数値を `.tres` に反映
3. 強化後に `display_name` に「+」を付与する処理を `CardData` または表示側に追加
4. 休息画面で強化済みカードのスキップが正しく動作しているか確認（`rest_screen.gd:29` `if card.upgraded: continue` は実装済み）

**対象ファイル**: `resources/cards/**/*.tres`（120ファイル）、`scripts/data/card_data.gd`、`scenes/rest/rest_screen.gd`

---

### 1-2. [CRITICAL] AP/ターンの統一

**現状**: 3つの文書で値が異なる。
| ソース | AP/ターン |
|--------|----------|
| GDD v2 | 6 |
| 実装仕様書 | 3 |
| コード (`combat_manager.gd:28`) | 5 |

**作業内容**:
1. 正式な AP/ターン値を決定する（推奨: **5** — 現コードの値。6だと手札5枚に対してAPが余りすぎ、3だと高コストカードが使えない）
2. GDD v2 と実装仕様書の該当箇所を更新
3. カードコスト設計が決定値と整合しているか検算（特に3APカード: `m05`=チェーンソー, `d06`=鉄壁, `r06`=スナイパー, `cu09`=永遠のハイウェイ, `er09`=デッドリーシャワー, `co07`=百裂拳）

**対象ファイル**: `autoload/combat_manager.gd`、GDD、実装仕様書

---

### 1-3. [HIGH] GDD と .tres の数値不一致を解消

| 項目 | GDD値 | .tres値 | 正とする値 |
|------|-------|---------|-----------|
| ヴェスパ max_hp | 75 | 70 | 70 |
| ウェズリー deck_limit | 20 | 25 | 25 |
| メタアンロック条件 | GDD記載 | meta_progression.gd | **3件の不一致を照合** |

**作業内容**:
1. 各不一致について正式値を決定
2. GDD / .tres / meta_progression.gd を同時に更新
3. `.tres` の `unlock_condition`（表示用文字列）も一致させる

**対象ファイル**: `resources/characters/*.tres`、`autoload/meta_progression.gd`、GDD

---

### 1-4. [HIGH] ヘドニスト(ホタル) キャラデータの作成

**現状**: GDDに6人目のPCとして記載があるが、`.tres` ファイルが存在しない。

**作業内容**:
1. `resources/characters/hedonist.tres` を作成
2. GDD記載値を反映: id=`hedonist`, display_name=`ホタル`, max_hp=55, unique_system=`euphoria`
3. スターターデッキIDを定義（GDD / 実装仕様書の初期デッキ構成に準拠）
4. ヘドニスト専用カード `.tres` が存在するか確認。無ければ作成（実装仕様書 `eu01`-`eu11`）
5. `meta_progression.gd` にアンロック条件を追加
6. `character_select.gd` でヘドニストが選択可能になることを確認
7. `map_screen.gd` の `_get_character_final_boss()` にヘドニストのボスマッピングを追加

**対象ファイル**: `resources/characters/hedonist.tres`（新規）、`resources/cards/hedonist/*.tres`（新規）、`autoload/meta_progression.gd`、`scenes/map/map_screen.gd`

---

## Phase 2: キャラ固有システム実装

### 2-1. [HIGH] ワンダラー — ローンウルフ・パッシブ

**GDD仕様**:
- 同行者がいない場合にパッシブ強化（詳細はGDD 7-3章）
- デッキ枚数が少ないほど強化されるカード（`wa04` Bullet Time: デッキ≤15で追加ドロー）

**作業内容**:
1. `combat_manager.gd` に `_is_wanderer()` ヘルパーを追加
2. ローンウルフ判定関数を実装（同行者データが未実装のため、当面は常時trueまたはフラグ制御）
3. ワンダラー専用カードのうち「ローンウルフ条件」を参照するカードの効果を `_apply_card_effects()` に追加:
   - `wa02`: 同行者なしでドロー+1
   - `wa04`: デッキ≤15でドロー+1
   - `wa09`: 同行者なしで全攻撃+4
4. `st_we02` サバイバルナイフ: デッキ≤15で+2ダメージの条件分岐を追加

**対象ファイル**: `autoload/combat_manager.gd`

---

### 2-2. [HIGH] コンカラー — オーラ(闘気)システム

**GDD仕様**: オーラ 0-100%。近接攻撃で蓄積、一定閾値で攻防にバフ。

**作業内容**:
1. `combat_manager.gd` に `player_aura: int`、`AURA_MAX := 100` を追加
2. シグナル `aura_changed(value: int, max_value: int)` を追加
3. コンカラー専用カードのオーラ増減処理を `_apply_card_effects()` に追加:
   - `co01`: +10オーラ, `co03`: +15, `co04`: +10, `co05`: +20, `co06`: +25, `co09`: +10, `co10`: +15
   - `co07` 百裂拳: オーラを0にリセット
   - `co08` オーラリリース: ダメージ=オーラ÷2、オーラ0にリセット
   - `co10` 一撃必殺: オーラ80%以上で3倍ダメージ
4. 戦闘画面にオーラゲージUIを追加（ヒートメーターと同様の実装パターン）
5. `start_combat()` でオーラを0にリセット

**対象ファイル**: `autoload/combat_manager.gd`、`scenes/combat/combat_screen.gd`

---

### 2-3. [MEDIUM] ビーストマスター — 獣召喚システム

**GDD仕様**: 獣カードで獣を召喚（最大5体）。獣は独立してHPを持ち、ターン毎に自動攻撃。

**作業内容**:
1. `combat_manager.gd` に獣スロット管理を追加:
   - `player_beasts: Array[Dictionary]`（name, hp, max_hp, attack, alive）
   - 獣の自動攻撃をプレイヤーターン開始時に実行
   - 獣へのダメージ処理（敵のAOE等で獣もダメージを受ける）
2. ビーストマスター専用カードの効果実装:
   - `bm02`: 全獣即時攻撃
   - `bm03`: 獣1体をHP5回復
   - `bm04`: 全獣+3攻撃(ターン中)
   - `bm06`: 全獣が2回攻撃
   - `bm07`: 獣がいれば+5ダメージ
   - `bm08`: 自分+獣1体にブロック
   - `bm09`: ランダム獣を0APで召喚
3. 戦闘画面に獣スロットUIを追加（敵スロットの手前に表示）
4. `_get_enemies_for_node()` で獣がいる場合の敵AIへの影響（獣へのターゲティング）

**対象ファイル**: `autoload/combat_manager.gd`、`scenes/combat/combat_screen.gd`

---

### 2-4. [MEDIUM] ヘドニスト — サイケデリック・エクスタシー(陶酔)システム

**GDD仕様**: ユーフォリア 0-100。快楽系カードで蓄積、高ユーフォリアでカード強化・自傷リスク。

**作業内容**:
1. ヘドニスト固有ゲージを `combat_manager.gd` に追加
2. ユーフォリア連動カード効果の実装（`eu01`-`eu11`）
3. 戦闘画面にユーフォリアゲージUIを追加
4. **前提**: Phase 1-4（ヘドニスト .tres 作成）が完了していること

**対象ファイル**: `autoload/combat_manager.gd`、`scenes/combat/combat_screen.gd`

---

## Phase 3: ゲームシステム拡張

### 3-1. [HIGH] バイクパーツの効果適用

**現状**: `bike_parts_database.gd` が47パーツの `.tres` を読み込み済み。しかし装着UI・効果適用ロジックがない。

**作業内容**:
1. `ResourceManager` に装備中パーツのスロットを追加:
   ```
   var equipped_parts: Dictionary = {}  # {Slot: BikePartData}
   ```
2. パーツの `stats` を読み取り、以下に反映:
   - `tank_capacity`: タンクパーツの容量ボーナス
   - `bike_max_durability`: フレームパーツの耐久ボーナス
   - バイクカードのダメージボーナス: エンジンパーツの `bike_attack_bonus`
   - 逃走成功率: タイヤ/エンジンの `escape_bonus`
3. ショップまたは休息画面にパーツ装着UIを追加（新規シーン `scenes/bike/bike_customize.tscn`）
4. パーツ入手経路の実装（戦闘報酬・ショップ・イベント）

**対象ファイル**: `autoload/resource_manager.gd`、`autoload/combat_manager.gd`、新規シーン

---

### 3-2. [HIGH] コンパニオン(同行者)システム

**現状**: `companion_data.gd` にデータクラスが定義済み。7体の同行者データが `.tres` に存在。ゲームロジックでの参照なし。

**作業内容**:
1. `GameManager` に同行者スロットを追加:
   ```
   var current_companion: CompanionData = null
   var companion_nodes_remaining: int = 0
   ```
2. ノード進行時にカウントダウン、期限到達で離脱＋報酬付与
3. 同行者のパッシブ効果を各システムに接続:
   - fighter: 全敵-1ダメージ/ターン → `_execute_enemy_turns()`
   - technician: 戦闘中バイク耐久ダメージ無効
   - merchant: ショップ10%割引 → `shop_screen.gd`
   - traitor: 毎ターン+1ドロー → `begin_turn()`、3ノード目で離脱＋燃料窃取
4. イベント選択肢での同行者加入処理を `event_screen.gd` に追加
5. マップHUDに同行者表示を追加

**対象ファイル**: `autoload/game_manager.gd`、`autoload/combat_manager.gd`、`scenes/event/event_screen.gd`、`scenes/map/map_screen.gd`、`scenes/shop/shop_screen.gd`

---

### 3-3. [MEDIUM] ヒート連動イベント選択肢ロック

**GDD仕様**: エクスレイダーのヒートが50%以上で友好的選択肢がグレーアウト。90%以上で完全消失。

**作業内容**:
1. `EventChoiceData` に `heat_max: int = -1` フィールドを追加（-1=制限なし）
2. `event_screen.gd:_check_requirement()` にヒート条件を追加
3. 該当イベントの `.tres` に `heat_max` を設定
4. マイロ同行中のロック解除条件（将来の同行者システム実装後）

**対象ファイル**: `scripts/data/event_choice_data.gd`、`scenes/event/event_screen.gd`、`resources/events/**/*.tres`

---

### 3-4. [MEDIUM] 汚染カードシステムの完全実装

**現状**: `con01`-`con04` の `.tres` は存在。`is_unplayable = true` は設定済み。ドロー時の AP-1 / 自傷 / デバフ効果が未実装。

**作業内容**:
1. `DeckManager.draw_cards()` にドロー時効果のフックを追加
2. 汚染カードをドローした時に `CombatManager` 経由で効果を適用:
   - `con01`: AP-1
   - `con02`: AP-1, 自傷2
   - `con03`: AP-1, ランダムデバフ
   - `con04`: AP-1, 全敵+2ブロック
3. 汚染カードがデッキに混入する経路の実装（イベント・特定敵の攻撃）

**対象ファイル**: `autoload/deck_manager.gd`、`autoload/combat_manager.gd`

---

### 3-5. [MEDIUM] 追跡システム（元レイダー専用）

**GDD仕様**: コカトリスの追手が常時追跡。追跡度が一定以上で強制戦闘イベント。

**作業内容**:
1. `GameManager` または新規Autoloadに `pursuit_level: int` を追加
2. ノード進行時に追跡度が上昇
3. 閾値超過でランダムに追手との強制戦闘を発生
4. 特定行動（隠密移動・マイロ同行）で追跡度の上昇を緩和
5. マップHUDに追跡ゲージを表示

**対象ファイル**: 新規 `autoload/pursuit_system.gd` または `autoload/game_manager.gd`

---

## Phase 4: UI・演出・品質向上

### 4-1. [MEDIUM] 情報ノード（オアシス情報システム）

**現状**: マップの INFO ノードは固定テキスト表示のみ（`map_screen.gd:261`）。

**作業内容**:
1. `GameManager` にオアシス情報ステージを追加: `oasis_info: Dictionary = {}`（カテゴリ→段階）
2. 4カテゴリ × 3段階の情報テキストを定義
3. INFO ノード選択時に情報を1段階進める処理を実装
4. 情報が一定量溜まるとマップにヒントが表示される仕組み

**対象ファイル**: `autoload/game_manager.gd`、`scenes/map/map_screen.gd`

---

### 4-2. [MEDIUM] ショップの拡充

**現状**: 固定3アイテム + ランダム4カード。GDDではバイクパーツ・アイテム・医薬品の種類も想定。

**作業内容**:
1. バイクパーツの販売枠を追加（Phase 3-1 完了後）
2. 区間に応じた品揃え変化
3. 商人同行者のディスカウント適用（Phase 3-2 完了後）
4. スクラップでの購入オプション

**対象ファイル**: `scenes/shop/shop_screen.gd`

---

### 4-3. [MEDIUM] 戦闘演出の強化

**作業内容**:
1. ダメージ数字のポップアップ表示（`scenes/ui/damage_number.tscn` は仕様書に記載あり）
2. カード使用時のアニメーション（手札→場）
3. 敵撃破時のエフェクト
4. ステータス効果のアイコン表示（テキストラベルからアイコンへ）
5. ターン開始/終了のトランジション

**対象ファイル**: `scenes/combat/combat_screen.gd`、新規UIコンポーネント

---

### 4-4. [LOW] オーディオシステム

**現状**: 完全未実装。仕様書に `AudioManager` の記載あり。

**作業内容**:
1. `autoload/audio_manager.gd` を作成（BGM/SEの再生・フェード管理）
2. 各シーンにBGM再生を追加（タイトル、マップ、戦闘、ショップ、イベント、ボス）
3. 戦闘SEの追加（カード使用、ダメージ、ブロック、勝利、敗北）
4. 音源ファイルの準備

**対象ファイル**: 新規 `autoload/audio_manager.gd`、各シーン `.gd`

---

### 4-5. [LOW] セーブ/ロードシステム

**現状**: `meta_progression.gd` のメタデータ保存のみ。ラン中のセーブ/ロードなし。

**作業内容**:
1. `SaveManager` Autoloadを作成
2. マップ画面でオートセーブ（ノード選択後）
3. タイトル画面に「続きから」ボタンを追加
4. 保存対象: GameManager状態、ResourceManager状態、DeckManager.master_deck、マップ進行、クエスト状態

**対象ファイル**: 新規 `autoload/save_manager.gd`、`scenes/main/title_screen.gd`

---

## Phase 5: コンテンツ拡充

### 5-1. [MEDIUM] イベントの追加

**現状**: 15イベント。GDDの世界観の深さに対して明らかに不足。

**作業内容**:
1. 各区間に最低5イベントを目標に追加（現状は区間によって偏りあり）
2. キャラ固有イベントの充実（特にコンカラー、ヘドニスト）
3. 移動イベント（travel）カテゴリの追加（現状0件）
4. カルマ連動イベントの追加（善/悪の各バンドで異なるイベント）

---

### 5-2. [MEDIUM] クエストの追加

**現状**: クエストシステムは複雑だがコンテンツは `devilf_pack` の1件のみ。

**作業内容**:
1. 各区間に最低1つのサブクエストを追加
2. キャラ固有クエスト（特にヴェスパのマイロ関連、ウェズリーのミーシャ探索）
3. ファクション関連クエスト

---

### 5-3. [LOW] 信仰システム（カルティスト専用）

**GDD仕様**: 信仰度 0-100。教義行動で上昇、世俗行動で下降。4段階で口調・選択肢が変化。

**作業内容**:
1. `GameManager` または新規システムに `faith: int = 80` を追加
2. イベント選択時の信仰度増減
3. 信仰度帯による口調変化（テキスト差し替え）
4. 信仰度帯によるカルティスト専用選択肢の出現/消失

---

### 5-4. [LOW] ネオンドラッグシステム

**GDD仕様**: 一時的な強化アイテム。副作用あり。

**作業内容**:
1. アイテムデータクラスの活用（`item_data.gd` は存在済み）
2. 戦闘中の使用UIを追加
3. 効果と副作用の実装

---

## 実装優先順位マトリクス

```
         影響大                     影響小
      ┌─────────────────────┬─────────────────────┐
 工数 │ Phase 1 (1-1,1-2)   │ Phase 1 (1-3)       │
 小   │ → 最優先            │ → 即時対応          │
      ├─────────────────────┼─────────────────────┤
 工数 │ Phase 2 (2-1,2-2)   │ Phase 3 (3-3,3-4)   │
 中   │ Phase 3 (3-1,3-2)   │ Phase 4 (4-1,4-2)   │
      │ → 次フェーズ        │ → 余裕があれば      │
      ├─────────────────────┼─────────────────────┤
 工数 │ Phase 2 (2-3,2-4)   │ Phase 4 (4-4,4-5)   │
 大   │ Phase 1 (1-4)       │ Phase 5 (全体)       │
      │ → 計画的に着手      │ → 長期目標          │
      └─────────────────────┴─────────────────────┘
```

## 推奨実装順序

1. **1-1** カード強化効果 → **1-2** AP統一 → **1-3** 数値同期
2. **2-1** ワンダラー → **2-2** コンカラー（比較的シンプル）
3. **3-2** コンパニオン → **3-1** バイクパーツ
4. **1-4** ヘドニスト .tres → **2-4** ユーフォリア
5. **2-3** ビーストマスター（最も複雑）
6. **Phase 4-5** 随時

---

## 技術的注意事項（CLAUDE.md準拠）

すべての実装において以下のルールを遵守すること:

1. **Variant推論禁止**: `:=` で Variant を受けない。`Dictionary.get()` / `Array.pop_back()` 等は明示型注釈
2. **型付き配列の代入**: `.assign()` を使用
3. **シグナル発火前にステート更新**: `state` を先に確定してからシグナルを emit
4. **動的ノードの参照保持**: `get_node()` パス解決ではなく配列で直接保持
5. **データ駆動設計**: ハードコードIDに頼らず、`.tres` の属性でスケールさせる
6. **GDDと.tresの同時更新**: 数値を変更したら両方を更新
7. **宣言フィールドの消費確認**: `@export` したフィールドは必ず読む側のコードを実装
