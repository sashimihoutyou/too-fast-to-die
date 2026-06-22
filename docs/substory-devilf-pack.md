# サブストーリー設計：デビルフの群れ ─ 実装テンプレートの叩き台

Act1（荒野／ニューエデン辺境／ボス＝アルファ・デビルフ）に配置するサブストーリーを、
合意した **「名前付きアウトカム＋遅延ペイロード」モデル** で1本だけ完全に書き下ろしたもの。
`.tres` 相当の忠実度で記述し、**そのまま量産テンプレの叩き台**として使えることを狙う。

> **実装状況**: §9 のメカニズム（QuestManager の強制発火・QuestData・ボス修飾チャネル）と本書の `.tres` は
> **実装済み**。実ファイルは `autoload/quest_manager.gd` / `scripts/data/quest_data.gd` /
> `resources/quests/devilf_pack.tres` / `resources/events/settlement/devilf_pack_intro.tres` /
> `resources/events/settlement/devilf_poison_aftermath.tres`。本書の `.tres` ブロックは実ファイルと一致する。

---

## 0. この実例が体現する設計原則（再掲）

- アウトカムは **成功/失敗の二値ではなく名前付き**（`hunt` / `poison` / `ignore` / `lapse`）。「未実施」「失敗」も1つの authored アウトカム。
- 各アウトカム ＝ **(報酬/コストの束) ＋ (アームする遅延イベント 最大1個)**。空アウトカム禁止（CLAUDE.md「no-op禁止」）。
- **道徳コストはテレグラフし、カルマ本体は遅延加算**（選択時にメーターでネタバレしない）。
- 処理後は **本流（ボス戦の修飾）へ再収束**。深い枝（A→A1→A1a）を作らない。
- アウトカムの出現可否・帰結の重さを **PCで出し分け**、キャラ非対称性に変換する。

---

## 1. クエスト定義（QuestData / 提案スキーマ）

| 項目 | 値 |
|---|---|
| id | `&"devilf_pack"` |
| title | デビルフの群れ |
| required_act | 1 |
| node_limit | 5（導入ノードからの猶予。Act1ボス行より手前で決着する想定） |
| intro_event | `&"devilf_pack_intro"` |
| boss_target | `&"alpha_devilf"`（アウトカムに応じてボス生成を修飾） |
| outcomes | `hunt` / `poison` / `ignore` / `lapse` |

```
# 提案スキーマ（QuestData。クラス未実装）
id            = &"devilf_pack"
title         = "デビルフの群れ"
summary       = "群れを率いるアルファに挑む前に、群れをどう処理するか"
required_act  = 1
node_limit    = 5
intro_event   = &"devilf_pack_intro"
boss_target   = &"alpha_devilf"
# objective は hunt ルートのみ追跡（poison/ignore は導入で即決着）
hunt_objective = { type = &"defeat_tag", tag = &"devilf", count = 3 }
```

ポイント: **「追跡されるクエスト」と「アウトカム」は別レイヤ**。`hunt` だけが
（撃破数×ノード期限の）追跡対象で、`poison`/`ignore` は導入イベントで即確定する。
この実例はその違いも兼ねて示している。

---

## 2. 導入イベント（`.tres`：既存EventDataスキーマ ＋ 新規 `starts_quest` / `quest_outcome`）

`body_text` 末尾に **常時テレグラフ**（獣の足跡に混じる小さな裸足の跡）を仕込む。
これが §4 の遅延ペイロードへの伏線になる。

```gdscript
[gd_resource type="Resource" script_class="EventData" load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/data/event_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data/event_choice_data.gd" id="2"]

[sub_resource type="Resource" id="choice_hunt"]
script = ExtResource("2")
label = "自力でデビルフを狩る"
requirement = ""
result_text = "群れを間引くと決めた。アルファに挑むまでに、できるだけ数を削る。"
karma_change = 1
starts_quest = &"devilf_pack"   # 新規フィールド（§9）
quest_outcome = &"hunt"          # 新規フィールド（§9）

[sub_resource type="Resource" id="choice_poison"]
script = ExtResource("2")
label = "毒餌を仕掛けて一網打尽にする"
requirement = "scrap>=4"
result_text = "拾い集めた薬品で粗末な毒を煮出し、家畜の死骸に仕込む。夜明けには群れは静かになっていた。"
karma_change = -2                # 即時は“軽い忌避”のみ。本体は遅延（§6）
scrap_change = -4
starts_quest = &"devilf_pack"
quest_outcome = &"poison"

[sub_resource type="Resource" id="choice_ignore"]
script = ExtResource("2")
label = "関わらない"
requirement = ""
result_text = "おれの問題じゃない。群れは荒野をうろついたままだ。"
starts_quest = &"devilf_pack"
quest_outcome = &"ignore"

[resource]
script = ExtResource("1")
id = &"devilf_pack_intro"
title = "デビルフの群れ"
body_text = "デビルフの群れが活性化し、旅人や家畜が襲われる被害が相次いでいるらしい。「今年はどこでも奴らを見る…きっと、とんでもない数の狼がいるんだろう」村人は口を揃えて言う。襲われた家畜の死骸を検めると、骨に残った歯型は十を超えていた。相当な大群だ。──だが、よく見ると刃物でこそげ取ったような跡も混じっている。村では誰も、こんな死肉に手は出さないはずだが。"
required_act = 1
choices = [SubResource("choice_hunt"), SubResource("choice_poison"), SubResource("choice_ignore")]
```

> `scrap>=4` ゲートは二役。①毒餌に**実弾の資源コスト**を持たせ「常に毒が最適」を防ぐ。
> ②スクラップ不足時は灰色 `(条件不足)` 表示になり、**「次の周回で毒餌ルートを試せる」とプレイヤーに告知**する（リプレイ誘発）。

---

## 3. アウトカム別の効果束

| アウトカム | 即時効果 | ボス修飾（アルファ・デビルフ） | 遅延ペイロード | カルマ(即/遅延) |
|---|---|---|---|---|
| **hunt（完遂）** | デビルフ×3を戦闘で撃破 | 取り巻きなし・HP-25% | なし | +1 ／ 完遂+5 |
| **hunt（lapse）** | 期限内に未達 | 取り巻き1減のみ | なし | +1 ／ — |
| **poison** | scrap-4 | 取り巻きなし・**HP-40%**（群れ全滅で最も弱体） | `devilf_poison_aftermath` を装填 | -2 ／ -12〜-18 |
| **ignore** | なし | 取り巻き2・全力 | なし | 0 ／ — |

設計意図（**ここが分岐の肝**）:

- 毒餌は**機械的に最良**（ボス最弱体・戦闘ゼロ）。コストは**資源(scrap)＋遅延する道徳的代償**に寄せる。
  「効率と良心のトレードオフ」を成立させ、悪ルート側の代償が no-op にならないようにする。
- 自力狩りは**手間とHPリスク**が代償だが、調教師には獣カード入手の好機（下記PC差）。
- 無視は**ボス戦が最も重く**なる軽い帰結（authored、空ではない）。

### PC差（アウトカムの出し分け）

| PC | 差分 |
|---|---|
| 調教師ミーシャ | `hunt` 中、屈服の鞭で獣にとどめ→**デビルフ獣カード確定入手**。`poison` は思想的に最悪手で、遅延カルマに**追加-6**（後述「知り得た」と重複し得る）。将来拡張で **`tame`（アルファを手懐ける）** 専用アウトカムを足す余地 |
| カルティスト アタルパ | `poison` の遅延先で、死んだ孤児が**V8カルトが保護するような捨て子**だったと判明→**信仰動揺イベント**へ接続 |
| 放浪者 ウェズリー | 遅延先の反応が固有に重い（**幼少期に家族が核の冬の飢餓で一人ずつ死ぬのを見た**世代）。獣読み能力で「知り得た」フラグが立ちやすい |
| 覇者 | 知性/読み選択肢が乏しく**毒の帰結に踏み込みやすい**。デフォルト「弱きを助ける」ゆえ `hunt` が自然な第一選択 |
| 元レイダー ヴェスパ | `poison`→`見なかったことにする` が血の怒り表現に合う。だが**失った弟マイロ**ゆえ、孤児の死は彼女にこそ刺さる |

---

## 4. 遅延ペイロード（`.tres`：`devilf_poison_aftermath`）

**`poison` ルートのみが装填**。`poison` 選択の **1ノード以上後・Act1内** の最初のEVENTノードで
**強制発火**（§9-3）。常時テレグラフ（刃物でこそげ取った跡）を回収する。

選択肢は**浅く再収束**（新たな分岐を切らない）。反応＋カルマ本体の加算のみ。

```gdscript
[gd_resource type="Resource" script_class="EventData" load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/data/event_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data/event_choice_data.gd" id="2"]

[sub_resource type="Resource" id="choice_bury"]
script = ExtResource("2")
label = "亡骸を葬る"
requirement = ""
result_text = "毒は獲物を選ばなかった。骨まで肉を削いで生き延びていた子供らが、冷たくなって倒れている。土を掘り、埋める。噂は荒野を伝っていく。"
karma_change = -12               # 基本値。「知り得た」PCは実装側で-6追加（§6）
fuel_change = -2
sets_flag = &"devilf_orphans_dead"   # 新規フィールド（§9）。後続集落の評判に波及

[sub_resource type="Resource" id="choice_lookaway"]
script = ExtResource("2")
label = "見なかったことにして走り去る"
requirement = ""
result_text = "アクセルを捻る。ミラーの中の小さな影は、見ないことにした。"
karma_change = -15
sets_flag = &"devilf_orphans_dead"

[resource]
script = ExtResource("1")
id = &"devilf_poison_aftermath"
title = "毒の行方"
body_text = "群れを仕留めた死骸の野に戻ると、狼以外のものまで倒れていた。隠れて生きていた戦災孤児の一団が、毒の回った肉を口にしたのだ。骨を刃物でこそげていたのは──こいつらだった。"
required_act = 1
choices = [SubResource("choice_bury"), SubResource("choice_lookaway")]
```

### 遅延イベントのPC別フレーバー（本文末尾に1行差し込む想定）

| PC | 差し込む反応 |
|---|---|
| 調教師 | 獣にも子供にも──ミーシャの数少ない味方だった両方に、毒は等しく回った。彼女は何も言わない。 |
| カルティスト | この子らは、共同体が拾い、火の傍で育てたはずの子だ。スピード・デーモンは、これも「加速」と呼ぶのか。 |
| 放浪者 | 飢えで子供が死ぬのを、ウェズリーは昔も見た。順番に、一人ずつ。三十年経っても、匂いは同じだ。 |
| 元レイダー | こんな歳の子を、おれは知っている。砂嵐の向こうに置いてきた。 |
| 覇者 | 強きをくじき、弱きを助ける──その手が、今度は何をした。 |

> `devilf_orphans_dead` フラグは、後の集落ノードで**評判低下（売値悪化・善人系イベント不可）**に波及させる
> フックとして残す（本書では深掘りせず、再収束を優先）。

---

## 5. テレグラフ設計（後出しジャンケン感の回避）

公平性は**2層**で担保する。

1. **常時（全PC）**: 導入 `body_text` の「刃物でこそげ取った跡」＋「村では誰も手を出さない」。
   *大群* の誤誘導で注意を狼の頭数へ逸らしつつ、死肉を漁る人間の存在だけを伏せる。
   答え（子供）は名指ししない。遅延先で刃物の跡として明示的に回収され、見落とした人も遡って腑に落ちる。
2. **能力依存（PC/同行者）**: 調教師の獣読み・放浪者・犬／密告者同伴は、検分時に
   「これは狼じゃない。誰かがここで死肉を漁って生きている」まで言語化し「**知り得た**」フラグを立てる。
   一般PCは曖昧な刃物の跡止まり（＝既定 -12）、人間と見抜いたPCのみ加重（-18）。
   → クリック追加なしで、テレグラフ公平性を**キャラ非対称性に変換**する。
3. **存在の告知（リプレイ誘発）**: 毒餌の `scrap>=4` 灰色表示で「別ルートがある」と知らせる。
4. **覇者の例外**: 知性/読み手段に乏しく、毒の帰結に踏み込みやすい＝キャラ設計どおりの弱点表現。

---

## 6. カルマ加算のタイミング（地味だが効く規則）

| タイミング | poison ルートのカルマ |
|---|---|
| 選択時（導入） | **-2 のみ**（軽い忌避。メーターでネタバレしない） |
| 遅延発火時 | **-12**（知らず）／ **-18**（「知り得た」フラグあり） |

理由: 罪の自覚を**後から**来させる演出。選択時に本体(-12〜-18)を即時適用すると、
**カルマメーターが結末を先にネタバレ**してしまう。`hunt` 完遂の +5 も完遂時に後置する。

---

## 7. 本流への再収束

全アウトカムは **Act1ボス＝アルファ・デビルフ戦の修飾**に収束し、戦闘後は通常進行へ戻る。
遅延イベントは1本だけで、そこから新しいクエストを生やさない（評判フラグの波及に留める）。

```
[devilf_pack_intro]
   ├ hunt   ─→（道中でデビルフ×3撃破 / 期限）─→ [ボス: 弱体 or lapse] ─┐
   ├ poison ─→（1ノード後）[devilf_poison_aftermath]──────→ [ボス: 最弱体] ─┼→ 通常進行
   └ ignore ───────────────────────────────────────────→ [ボス: 全力] ─┘
```

---

## 8. 抽出テンプレート（量産用スケルトン）

この1本から抜いた、埋めるだけの骨子。

```
QUEST
  id / required_act / node_limit / intro_event / boss_target(任意)
  outcomes: [ ふつう3〜4個。ignore と lapse を含める ]

各 OUTCOME
  key（StringName）
  即時効果束（fuel/scrap/medicine/hp/karma_small + card/companion）
  boss修飾（任意。リプレイ性の核）
  遅延ペイロード（最大1。装填するEventDataのid、または無し）
  遅延カルマ（本体。「知り得た」で加重）
  PCゲート/差分（出現可否・帰結の重さ）

遅延ペイロード EVENT
  強制発火（ランダム抽選に紛れさせない）
  選択肢は浅く再収束（反応＋カルマ本体のみ。新分岐を切らない）
  能力依存のカルマ加重
  PC別フレーバー1行

5つの鉄則
  ① 即時カルマは小さく、本体は遅延で
  ② 各アウトカムに非空の帰結（no-op禁止）
  ③ テレグラフ2層（常時＋能力依存）
  ④ 灰色ゲートで「別ルートの存在」を告知
  ⑤ 深掘り禁止・本流へ再収束
```

---

## 9. 実装（このサブストーリーを動かす機構）

前ターンで「オプションB」とした機構。**実装済み**（このブランチ）。対応箇所は以下。

1. ✅ `GameManager.total_nodes_visited: int`（`advance_node()` で単調増加、`advance_act()` でもリセットしない）。期限基準。
2. ✅ `scripts/data/quest_data.gd`（`QuestData`）＋ `autoload/quest_manager.gd`（`QuestManager`、autoloadは GameManager の直後に登録）。
   アクティブクエスト保持・`deadline = total_nodes_visited + node_limit`・hunt の撃破数追跡（`CombatManager.on_enemy_defeated` フック）・アウトカム確定・遅延ペイロード装填・期限切れ→lapse。
3. ✅ **EVENTノードの強制発火フック**: `event_screen.gd::_pick_event()` の前段で `QuestManager.get_pending_payload()` を最優先で返す。
   無ければ従来のランダム抽選にフォールバック。ペイロードイベントは `EventData.payload_only=true` でランダムプールから除外。
4. ✅ `EventChoiceData` への新規フィールド: `starts_quest` / `quest_outcome` / `sets_flag`。
   消費側は `event_screen._apply_choice`（フラグ・クエスト記録）と `_on_choice`（`notify_event_resolved`）で同時実装済み。
5. ✅ **ボス修飾チャネル**: `CombatManager.start_combat(enemy_list, boss_hp_scale)` でボスHPを倍率調整。取り巻きは
   `map_screen._get_enemies_for_node` で `QuestManager.get_boss_modifier()` を参照して追加。修飾値は `QuestData.boss_mods` 駆動。
6. ⬜ （任意・未実装）明示テレグラフを「情報画面→選択画面」の2段で見せる小拡張。現状はテレグラフ＝本文＋能力依存の「知り得た」加重で代替。

### 「知り得た」テレグラフ加重の実装

`QuestManager._pc_can_read()` が調教師・放浪者で true を返し、poison 装填時に `knew` として記録。
ペイロード解決時に `QuestData.payload_knew_extra_karma`（-6）を加算（一般PC -12／看破PC -18）。
犬/密告者の同行による看破は同行者システム未実装のため TODO。

### 型安全メモ（CLAUDE.md準拠）

- `Dictionary.get()` の戻りは `:=` で受けず型注釈。`Array[QuestData]` への代入は `assign()`。
- マップ画面のクエストHUDは `PanelContainer` ではなく `Panel`＋`layout_mode=1` で配置。
- 報酬カード/同行者は ID駆動で `CardDatabase` / `companions` を参照（ハードコードしない）。
