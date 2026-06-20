# キャラクターデザイン仕様書 — 修正差分

> character_design.md のセクション1（カルティスト）、セクション2（元レイダー）、5キャラ対比表を以下に差し替える。
> セクション3〜5（放浪者・調教師・覇者）は変更なし。

---

## 1. カルティスト — アタルパ (Atarpa)

### ビジュアル仕様

| 項目 | 内容 |
|---|---|
| 体格 | 引き締まった中背。信仰による断食と荒野での生活で余分な脂肪が削がれているが、巡礼の旅に耐えうる実用的な筋肉がついている。腱と骨格のラインが浮き出た、乾いた身体 |
| 顔 | 目に異様な輝きがある（狂信者の目）。頬がこけ気味で精悍。額にエンジンオイルで描いた薄い部族的フェイスペイント（V8カルトの儀式模様）の痕跡。左頬にV8のシンボルを模した焼印（成人の儀） |
| 髪 | 黒い短髪。エンジンオイルを塗り込んで固めており、濡れたような暗い光沢がある。普通の髪型だが質感が異質 |
| 服装上半身 | 袖なしの麻布ポンチョ（粗い織り、砂埃で褪色）。胸元が大きく開いており、鎖骨から肩・上腕にかけてエンジンオイルと赤土で描かれた部族的な渦巻き紋様が見える。ポンチョの下は素肌 |
| 服装下半身 | 使い込まれた黒い革パンツ。片脚にエキゾーストパイプの破片を革紐で巻き付けた脛当て |
| アクセサリ | 首からV8エンジンのミニチュアをペンダントに（革紐）。ベルトにガソリン缶を数本ぶら下げている。腰に小さな動物の骨と機械部品を組み合わせた呪術的なお守り。片腕にスパークプラグやワッシャーを紐で連ねた腕飾り。反対の腕には帯状の革の装飾 |
| ボディペイント | 露出した肩・上腕・胸元にエンジンオイル（黒）と赤土で描かれた渦巻き・円・回路を模した部族紋様。普段は薄く残る程度だが、儀式のたびに描き直す |
| 特徴的な傷 | 右手が焼けただれている（信仰の証）。両腕の内側にも小さな焼灼痕が点々と連なっている（日常的な信仰儀式の痕跡） |
| バイク | 改造チョッパー。排気管がやや多い。ハンドルやサドルバッグに動物の骨や呪術的なお守りが結び付けてある。大型のサドルバッグ（巡礼の荷物） |
| 配色 | 黒 + オレンジ + 赤土 + 骨の白 + オイルの暗い光沢 |
| 印象 | 一見すると荒野を行く普通の青年旅人だが、オイルで固めた髪、焼印、火傷の手、部族紋様といった「普通じゃない」ディテールが違和感を残す。親しみやすさと異質さが同居する、初期キャラクターにふさわしい造形。旅を通じて信仰の深層が開示される構造を前提とした「控えめな異質さ」 |

### デザイン方針メモ

初期プレイアブルキャラクターとして、プレイヤーの第一印象で拒否感を生まないことを優先する。仕様書初版の「剃り上げ頭＋全身ペイント＋ローブ」は信仰度が最大（狂信）時の姿として温存し、立ち絵の基本状態では部族要素を控えめにする。ただし以下の要素は「V8カルト教徒である」ことを視覚的に示す最低限の記号として常に含める:
- V8ペンダント（信仰の象徴）
- 火傷の右手（信仰の証、フルスロットルの代償の伏線）
- ガソリン缶（燃料特化型の視覚記号）
- オイル固めの髪（一般人との質感の差異）
- 肩〜腕の部族紋様（薄くても「何か描いてある」とわかる程度）

### 画像生成プロンプト

#### 全身立ち絵（バイク走行）

```
(Sketch art, line art, drawn), 1male, young man, thin wiry build, gaunt cheeks, solo, looking straight ahead, brown eyes with intense fervor, short black hair slicked back with motor oil giving it a wet dark sheen, light engine oil smudge marks on forehead like faded tribal paint, V8 symbol brand scar on left cheek, burn-scarred right hand with old severe burns, sleeveless rough hemp poncho over bare chest, chest partially visible showing faint oil-drawn ritual marks, tribal spiral and circle patterns in oil and red clay on shoulders and upper arms, V8 engine miniature pendant on leather cord around neck, small gasoline cans hanging from belt, spark plug and washer bangles on one wrist, animal bone charm tied to belt, worn leather pants, exhaust pipe fragment shin guard on one leg, driving motorcycle, black chopper motorcycle with extra exhaust pipes and a few bones and charms tied to handlebars, large saddlebag on back of bike, covered in dust, smudged clothes, post apocalyptic, desert, masterwork, masterpiece, best quality, detailed, depth of field, high detail, very aesthetic, 8k, dynamic pose, dynamic angle, dynamic lighting
```

#### バストアップ（カード用ポートレート）

```
(Sketch art, line art, drawn), portrait bust shot of a young man with gaunt face, brown eyes burning with quiet fanatical devotion, short black hair slicked with motor oil giving it a wet dark sheen, faint tribal paint marks on forehead in engine oil, V8 brand scar on left cheek, sleeveless rough hemp poncho over bare chest, tribal spiral patterns in oil and red clay visible on shoulders, V8 engine miniature pendant on leather cord at neck, burn-scarred right hand raised near chest, spark plug bangle on wrist, dramatic orange side lighting, dark post-apocalyptic desert background, masterwork, best quality, detailed, very aesthetic, 8k
```

---

## 2. 元レイダー — ヴェスパ / キイロ (Vespa / Kilo)

### ビジュアル仕様

| 項目 | 内容 |
|---|---|
| 体格 | 均整の取れたグラマラスな体型。戦闘で鍛えられつつも女性的な曲線を強調。胸が大きく、服装がそれを隠さない |
| 顔 | 左目の下に裂傷の跡。切れ長の目に青い瞳。濃いアイライン（戦化粧の名残）。厚めの唇。挑発的だが疲れを含んだ表情 |
| 髪 | 顎下〜鎖骨あたりの金髪ショートヘア。前髪が片目にかかり気味。手入れは最低限だが自然な艶がある。風で散った毛束が顔周りを縁取る |
| 服装上半身 | 黒い革のバンドゥトップ（レースアップのディテール付き）。革の質感が硬質で、胸の形を強調しつつ戦闘的な印象を与える。その上に元コカトリスの黒い革ジャン（ショート丈）を羽織る。革ジャンは脱いだ状態・片袖だけ通した状態・完全着用の三段階で描き分け可能。背中のコカトリス紋章はナイフで削り取った跡がある。革ジャンを脱いでも革バンドゥが残るため、引き締まった腹筋と腰のラインが露出する |
| 服装下半身 | ローライズのデニムホットパンツ（ダメージ加工、裾がほつれている）。腰骨が見える位置で履いている。弾帯をベルト代わりに巻く |
| 足元 | 編み上げブーツ（ヒールが少しある実戦型） |
| アクセサリ | 胸元にドッグタグがぶら下がり谷間に落ちている。片腕はむき出しで腕輪を数本。反対の腕にレザーアームガード（コカトリスの焼印を隠している）とフィンガーレスグローブ |
| 武装 | 拳銃（メイン武器）。腰に二丁拳銃のホルスター（太ももに沿うタイプ、脚線を強調）。ナイフも携行 |
| 特徴的な傷 | 片腕のアームガードの下にコカトリスの焼印。左目の下の裂傷跡。体の各所に古い傷跡（腹部・脚など、革バンドゥ＋ホットパンツの露出部分から見える） |
| バイク | スポーツタイプの改造車。速度重視。弾痕あり。跨る姿勢が映えるローポジション。タンクにコカトリスの目のエンブレム（消し切れていない） |
| 配色 | 黒（革ジャン・バンドゥ・ブーツ）+ 金（髪）+ デニム青 + 銃金属のシルバー + 素肌のコントラスト。黄色はアクセント（バンドゥのステッチ、ドッグタグの紐、バイク塗装のワンポイント等）としてスズメバチの印象を差す |
| 印象 | 殺し屋としての色気。革バンドゥの硬質さと露出した肌のコントラストが「鎧としての色気」を体現する。金髪はコードネーム「ヴェスパ（スズメバチ）」と本名「キイロ（黄色）」の二重の意味を視覚化する。ワイルドさと豊満な美しさが同居する危険な魅力 |

### カラーリング方針メモ

元レイダーの金髪＋黄色アクセントは物語的根拠に基づく:
- **ヴェスパ（Vespa）**: スズメバチ。黒と黄色の配色
- **キイロ（Kilo）**: 日本語で「黄色（Yellow）」にも聞こえる二重意味の名前
- 黒い革装備が「スズメバチの黒」、金髪と黄色の差し色が「スズメバチの黄色」を構成
- 黄色を全面に出すとカジュアルになるため、差し色に留め、主軸は黒で「危険な美女」の印象を維持

### 服装レイヤー設計メモ

革ジャンの下にバンドゥトップを設けることで、以下の演出バリエーションが可能:
- **革ジャン着用**: 通常のマップ画面・会話シーン。胸元は見えるがバンドゥで収まっている
- **片袖通し/肩掛け**: 戦闘中・暑い区間。片方の肩が露出し、アームガードと腕輪の非対称が映える
- **革ジャン脱ぎ**: 休息シーン・特定イベント。バンドゥ＋ホットパンツの状態で、傷跡と鍛えられた体が全面に出る
- いずれの状態でもトップレスにならないため、演出の幅が広がる

### 画像生成プロンプト

#### 全身立ち絵（バイク座り・革ジャン片袖）

```
(Sketch art, line art, drawn), 1girl, covered in dust, solo, breasts, looking at viewer, blue eyes, huge breasts, blonde short hair just past chin with stray locks framing face, scar under left eye, holding handgun with smoke from barrel, navel, dog tags hanging into cleavage, sitting on motorcycle, sweat, spread legs, black leather bandeau top with lace-up detail and yellow accent stitching, black cropped leather jacket worn with one sleeve on and one off shoulder, denim hot pants low-rise frayed edges, ammunition bandolier as belt, leather arm guard on one forearm, fingerless glove, bangles on other bare arm, dual pistol holsters strapped to outer thighs, lace-up combat boots with slight heels, old battle scars on abdomen and thighs, knife tucked in belt, smudged clothes, post apocalyptic, desert, bullet-scarred low-position sport motorcycle with eye emblem on tank, masterwork, masterpiece, best quality, detailed, depth of field, high detail, very aesthetic, 8k, dynamic pose, dynamic angle, dynamic lighting
```

#### バストアップ（カード用ポートレート）

```
(Sketch art, line art, drawn), portrait bust shot of a stunning 22-year-old female ex-raider with voluptuous figure and very large breasts, blonde short hair just past chin with stray locks framing face, blue eyes with heavy dark eyeliner, scar under left eye, full provocative lips, battle-worn but seductive expression, black leather bandeau top with lace-up detail, black cropped leather jacket draped over one shoulder, dog tags resting in cleavage, leather arm guard on one forearm with fingerless glove, bangles on other bare arm, warm dramatic lighting emphasizing contrast of soft skin against hard leather, dusty post-apocalyptic desert background, masterwork, best quality, detailed, very aesthetic, 8k
```

---

## 5キャラの視覚的対比（修正版）

| | カルティスト | ヴェスパ | ウェス | ミーシャ | 覇者 |
|---|---|---|---|---|---|
| **年齢感** | 若い（20前後） | 若い（22歳） | やや若い（30後半〜40前半） | 幼い（16歳、見た目12-13） | 若い（20後半〜30前半） |
| **シルエット** | 引き締まった縦長（ポンチョ+サドルバッグ） | 曲線的なS字（豊満+革ジャン） | ポンチョの台形 | 小さく不定形（+虎） | 巨大な逆三角+コート裾 |
| **肌の露出** | 中程度（ポンチョの隙間から紋様） | 多い（意図的、胸と脚を強調） | 少ない（すべて覆う） | 多い（服がない。脚の露出が顕著） | 多い（コートの隙間から筋肉） |
| **露出が語るもの** | 控えめな部族的信仰の痕跡 | 色気・威嚇・豊満な自信 | 何も見せない寡黙さ | 貧困・野生・華奢な脆さ | 全盛期の肉体・歴戦の傷 |
| **主な配色** | 黒+オレンジ+赤土+オイルの光沢 | 黒（革）+金（髪）+黄アクセント+銀+肌色 | 紺+砂色 | 土色+枯草+肌色 | 褪色茶（コート）+肌色+砂 |
| **見る者の印象** | 一見普通だが何か違う青年旅人 | 危険で豊満な金髪の元殺し屋 | 若いのに疲弊した旅人 | 可愛い顔の壊れた野生児 | 最強なのに目的がない青年 |
| **立ち姿** | バイクに跨り前を見据える（巡礼） | 片腰に手、胸を張る/銃を構える | 遠くを見る、手はポケット | 身を縮める+虎が寄り添う | 腕組み、コートが翻る |
