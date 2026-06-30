# Too Fast to Die: Road to Oasis ― キャラクタービジュアル仕様書

> 元 `character_design.md` から移動（2026-06-26）。
> 
> **関連ドキュメント:**
> - キャラクター設計（ゲームプレイ・物語） → `docs/gdd-characters.md`
> - 現行PC再設計 → `docs/gdd-pc-redesign.md`
> - PC性的態度・身体プロフィール → `docs/pc-profiles.md`

---

## 共通方針

- **アートスタイル**: 厚塗り半リアル。金子一馬（女神転生）の人物造形 + Darkest Dungeon の陰影 + Mad Max の世界観
- **世界観**: 核戦争後32年のアメリカ中西部。砂漠・廃墟・荒野
- **カラーパレット基調**: 砂漠サンド(#D4A855)、錆オレンジ(#C45A2D)、焦げ黒(#1A1A1A)、鉄グレー(#4A4A4A)

---

## 1. カルティスト — アータル (Atarpa)

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
- 火傷の右手（信仰の証、オーバーチャージの代償の伏線）
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

## 2. 元レイダー — ホーネット / キイロ (Vespa / Kilo)

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
| 印象 | 殺し屋としての色気。革バンドゥの硬質さと露出した肌のコントラストが「鎧としての色気」を体現する。金髪はコードネーム「ホーネット（スズメバチ）」と本名「キイロ（黄色）」の二重の意味を視覚化する。ワイルドさと豊満な美しさが同居する危険な魅力 |

### カラーリング方針メモ

元レイダーの金髪＋黄色アクセントは物語的根拠に基づく:
- **ホーネット（Vespa）**: スズメバチ。黒と黄色の配色
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

## 3. 孤独な放浪者 — ウェズリー / ウェス (Wesley / Wes)

### ビジュアル仕様

| 項目 | 内容 |
|---|---|
| 体格 | 中肉でやや引き締まった体型。30代後半〜40代前半。まだ衰えていない体力を感じさせるが、長年の放浪で余分な肉は削がれている |
| 顔 | 年齢以上に疲れた表情だが顔立ち自体はまだ若い。目尻と眉間に刻まれた皺は年齢より経験によるもの。穏やかだが遠くを見る目。薄い無精ひげ（白髪はほぼなし） |
| 髪 | ダークブラウンの中長髪。後ろで適当に束ねているが、前髪と横髪が額や頬に垂れている。わずかに白髪が数本混じる程度 |
| 服装上半身 | ポンチョ（砂埃で色褪せた元は紺色）。下にヘンリーネックシャツ + 実用的なカーゴベスト。ポケットが多く、すべて使い込まれている |
| 服装下半身 | 丈夫なワークパンツ。膝にパッチ当てあり |
| 足元 | 使い込まれたウエスタンブーツ（つま先が尖り、ヒールが高めの実戦仕様。デザートブーツから変更——カウボーイのペルソナを視覚化する最もわかりやすい記号） |
| 帽子 | 日焼けしたフェルトのカウボーイハット。つばが片側だけ反り上がっている。紐で顎に固定可能。バイク走行時は首の後ろに垂らす |
| アクセサリ | 戦前のデジタル腕時計（壊れているが外さない）。ポンチョの下、ベストの内ポケットに古い写真（ジョエルと写っている） |
| 武装 | 腰にリボルバー1丁（使い込まれて銃身が磨り減っている）。腰の後ろにもう1丁予備。西部劇の早撃ちを意識した低めのホルスター位置 |
| 特徴 | カウボーイハットとポンチョの組み合わせが「荒野の用心棒」的なシルエットを作る。表情には疲労と自嘲が同居するが、顔つき自体はまだ鋭さを残している。戦前の映画で見たカウボーイ像を32年かけて内面化した男の姿 |
| バイク | 実用的なツーリングバイク。派手さゼロだが整備が行き届いている。サドルバッグは革製で、西部のカウボーイの鞍袋を思わせる |
| 配色 | 褪せた紺 + サンドベージュ + レザーブラウン + フェルトの灰 |
| 印象 | 西部劇から抜け出してきたような流れ者。カウボーイハット＋ポンチョ＋リボルバーという「演じている」感が、よく見ると痛々しい。すべてを見ている目と、何も見たくない心の乖離。戦前の記憶が作り上げた仮面を32年間被り続けている男 |

### 画像生成プロンプト

#### 全身立ち絵

```
A lean, weathered man in his late 30s to early 40s standing in a vast post-apocalyptic desert, looking like a cowboy who wandered out of an old western film into the apocalypse. Still physically capable — not yet old, but worn down by years of solitary wandering, all excess stripped from his frame. Sun-bleached felt cowboy hat with one side of the brim curled up, a chin strap hanging loose. He wears a faded navy poncho bleached by sun and dust over a henley shirt and a practical cargo vest with many well-used pockets. Sturdy work pants with patched knees. Worn western boots with pointed toes and slightly raised heels. Dark brown medium-length hair tied loosely back, bangs and side strands falling over his forehead and cheeks under the hat brim, only a few stray gray hairs visible. A thin stubble with almost no gray. His face is still relatively young in structure but carries premature lines at the eyes and brow — marks of experience rather than age. Self-mocking but distant eyes that look past the horizon, carrying weariness and quiet self-deception. A broken pre-war digital wristwatch on his left wrist. A well-worn revolver in a low-slung hip holster in western quick-draw position, the barrel visibly smooth from years of use. A second revolver tucked at the small of his back. Behind him, a plain but well-maintained touring motorcycle with western-style leather saddlebags. Color palette: faded navy, sand beige, leather brown, felt gray, muted earth tones. Semi-realistic thick-paint art style, melancholic golden-hour lighting. Full body character design sheet.
```

#### バストアップ（カード用ポートレート）

```
Portrait bust shot of a weathered but still young-looking man in his late 30s to early 40s, one of the last to remember the pre-war world, wearing a sun-bleached felt cowboy hat with one side of the brim curled up. His face has premature lines at the eyes and brow from hardship rather than age, but his bone structure is still youthful and sharp. Self-mocking distant eyes carrying years of self-deception and weariness, thin stubble with barely any gray. Dark brown hair loosely tied back with bangs falling forward under the hat brim, only a few stray white hairs. Faded navy poncho over a henley shirt and cargo vest. A broken digital wristwatch on his wrist. The hat brim casts a shadow over one eye. Warm melancholic golden-hour lighting, vast empty desert in soft focus behind him. Semi-realistic thick-paint art style, quiet sorrow aesthetic, the look of a man playing cowboy in the end of the world.
```

---

## 4. 調教師（ビーストマスター） — ミーシャ (Misha)

### ビジュアル仕様

| 項目 | 内容 |
|---|---|
| 体格 | 小柄で華奢。18歳だが栄養不足で発育が遅く、幼く見える。手足が細く長い。胸はほぼ平坦、腰も子供のように直線的。ただし荒野で生き延びてきた分、身のこなしに野生動物のような俊敏さがある |
| 顔 | 大きな丸みのある目 — 本来は可愛らしい顔立ちだが、生気が薄く警戒に満ちている。虹彩が黄色がかったアンバー（野生動物的）。小さな鼻、薄い唇。頬がこけているが骨格自体は整っており、十分に食べれば可愛い少女だとわかる造形。表情は乏しいが、虎に触れる時だけ微かに和らぐ |
| 髪 | 手入れされていない腰までの黒髪。枝・羽根・小さな骨が絡まっている。前髪が目にかかり顔の半分を隠しがち |
| 服装上半身 | 獣皮を継ぎ接ぎしたビスチェのような短い胴衣。肩が片方ずれ落ちて鎖骨と肩が露出。丈が短く肋骨が浮く薄い腹部が露出している |
| 服装下半身 | 獣皮を裂いて作った極めて短いラップスカート。片側が大きく裂けており太ももの付け根近くまで脚が見える。だが露出する脚は細く筋肉より骨と筋が目立ち、膝が大きく見えるほど華奢 |
| 足元 | 素足。足裏が角質化して硬くなっている。足首は細く、脛の骨のラインがはっきり見える |
| 特徴的な傷 | 首に消えない拘束具の痕（項に金属が擦れた黒ずみ）。手首と上腕に奴隷拘束具の古い擦過痕。背中に鞭打ちの古傷が複数（胴衣の隙間から見える） |
| 武装 | 腰に手製の鞭（獣の腱で編んだ粗雑な作り） |
| パートナー | 常に傍にいる虎。虎の首にも同じ拘束具の痕 — 対の存在。虎は彼女より遥かに健康で堂々としている |
| バイク | サイドカー付き（虎の乗車用）。装飾は骨や爪 |
| 配色 | アーストーン（土色・枯草色・獣皮のなめし革色）。肌色が多いが暖かさではなく脆さの色 |
| 印象 | 人間社会の外で生きてきた野生児。露出が多いのは「まともな服を持っていない」から。脚を晒すのも無頓着の表れ。色気ではなく、細く薄い体と傷跡が語る痛々しさ。しかし顔の造作には元の可愛らしさが残っており、それが余計に痛ましい |

### 画像生成プロンプト

#### 全身立ち絵

```
A small feral girl of 18 standing barefoot beside a large tiger in a post-apocalyptic wasteland. Petite and thin with long slender limbs, flat chest, straight childlike frame, but moving with the coiled alertness of a wild animal. She has a pretty face beneath the grime — large round eyes with yellowish-amber irises like a wild cat, a small nose, delicate features that would be cute if she were healthy. But her cheeks are hollow, her expression is blank and wary, only softening faintly when touching the tiger. Long unkempt black hair reaching her waist, tangled with twigs, small feathers, and tiny animal bones, bangs falling over half her face. She wears a very short animal-hide bustier-like top, roughly stitched from patchwork pelts, one shoulder slipped off exposing a bony collarbone. The top is cropped high, revealing her thin stomach where faint rib outlines show. An extremely short wrap skirt made of torn animal hide, split high on one side nearly to the hip joint — her legs fully exposed from upper thigh down. But the exposed legs are painfully thin, knees appearing large on stick-like limbs, shin bones clearly visible, no muscle definition. Completely barefoot, soles thickened and calloused, slender ankles. Dark abrasion scars around her neck and wrists from slave restraints. Whip scars visible on her back through gaps in the bustier. A crude whip of braided animal sinew at her hip. The tiger beside her has matching restraint scars on its neck — a bonded pair. The tiger is visibly healthier and more imposing than the girl. Color palette: earth tones, dried grass, tanned leather, bare skin conveying fragility not allure. Semi-realistic thick-paint art style, harsh noon light casting stark shadows emphasizing how thin and small she is. Full body character design sheet.
```

#### バストアップ（カード用ポートレート）

```
Portrait bust shot of a feral 18-year-old girl next to a tiger's face. She has a naturally pretty face — large round eyes with yellowish-amber irises, small nose, delicate bone structure that would be cute if well-nourished. But her cheeks are sunken, her expression blank and guarded, and grime covers her skin. Long tangled black hair with twigs, feathers, and tiny bones caught in it, bangs covering half her face. A rough patchwork animal-hide bustier, one shoulder slipped off showing a thin bony collarbone. Dark restraint scars ring her neck. The tiger presses close to her, its own neck bearing matching scars. Her blank expression softens almost imperceptibly near the tiger. Harsh daylight, barren wasteland background. Semi-realistic thick-paint art style, emphasizing the contrast between her underlying cuteness and her damaged, feral state.
```

---

## 5. 世紀末の覇者 — 名無し (Nameless) / NPC素材

> 現行PC再設計では覇者はプレイアブルから外す。このビジュアルは将来のユニーク同行者/NPC化用素材として保持する。

### ビジュアル仕様

| 項目 | 内容 |
|---|---|
| 体格 | 身長190cm超。逆三角形の巨躯。ウエストは絞れ肩幅は異常に広い。全身が隆起した筋肉に覆われている。肉体の全盛期にある |
| 顔 | 眉間から左頬にかけて一本の深い古傷。眉が太く精悍な顔立ち。目は鋭いが瞳の奥に穏やかさがある。短い無精ひげ。若いが、傷と眼差しに年齢以上の凄みがある |
| 髪 | 黒髪のオールバック。肩にかかる程度の長さで風になびく。白髪はない（ケンシロウと差別化しつつ、若い全盛期の戦士である印象） |
| 服装上半身 | 長い褪せたダスターコート（元は暗褐色、砂埃と日焼けでまだら模様に退色）。前は留めずに開けており、中は裸の上半身。全盛期の筋肉と無数の傷跡が露出。片肩にだけ革のショルダーガード（非対称にしてケンシロウと差別化） |
| 服装下半身 | ダメージド・カーゴパンツ。膝から下がちぎれてハーフ丈。太い革ベルトで留めている |
| 足元 | 軍用ブーツ（唯一しっかりした装備。歩き続けるために必要） |
| アクセサリ | 首に旅人のネックレス — シンプルな革紐に小さな金属片（形見。決して外さない。戦闘中も光る） |
| 武装 | 両拳にテーピングと古い包帯 — 唯一の武装。何層にも巻かれている |
| 特徴 | 腕を組むポーズが基本の立ち姿。ダスターコートの裾が風で翻る。コートには切り傷・弾痕・焦げ跡が無数にある（彼の歴戦をコートが物語る） |
| バイク | なし。徒歩。この男にバイクは似合わない |
| 配色 | 褪色ダークブラウン（コート）+ 肌色 + 砂色 + 傷跡の赤白 + ネックレスの金属光 |
| 印象 | 肉体的な全盛期にありながら、目的なく彷徨う矛盾。若く圧倒的に強いのに、その強さを振るう理由を持たない。ダスターコートが砂漠の風に翻る姿は、西部劇の流れ者と北斗の拳の融合 |

### ケンシロウとの差別化ポイント

| 要素 | ケンシロウ | 覇者 |
|---|---|---|
| 傷 | 北斗七星の七つの傷 | 眉間から左頬への一本傷 |
| 髪 | 短髪 | オールバックの長めの黒髪 |
| 上着 | 革ジャン（または裸） | ダスターコート（前開き、中は裸） |
| 肩装甲 | 両肩パッド | 片肩のみの革ショルダーガード |
| 年齢感 | 若い（20代後半） | 同等の若さだが、眼差しだけが老成している |
| 表情 | 正義の怒り・使命感 | 目的なき穏やかさ。怒りではなく静けさ |
| 体格 | 理想的格闘家体型 | 同等だが傷が圧倒的に多い。全身が戦場の地図 |

### 画像生成プロンプト

#### 全身立ち絵

```
A towering muscular man in his late 20s to early 30s, over 190cm tall, standing in a vast post-apocalyptic desert with arms crossed. In the absolute prime of his physical power — massive inverted-triangle build with extremely broad shoulders and a narrow waist, every muscle perfectly defined and at peak condition, yet covered in countless old battle scars like a living map of wars survived. He wears a long weathered duster coat, originally dark brown, now faded and mottled from sun and sandstorms. The coat is worn open in front, revealing his bare scarred torso in its full muscular glory. The duster's hem catches the wind dramatically, billowing behind him. The coat itself bears slash marks, bullet holes, and scorch marks — a chronicle of battles. A single leather shoulder guard on one shoulder only, creating asymmetry. Damaged cargo pants torn to half-length below the knees, secured with a thick leather belt. Military boots, well-worn but sturdy. Black hair swept back reaching his shoulders, blowing in the wind — no gray, pure black, youthful. A single deep old scar running from between his eyebrows down to his left cheek. Thick eyebrows, a young handsome face that is fierce yet paradoxically gentle in the eyes. Short stubble. Both fists wrapped in layers of old tape and bandages — his only weapons. A simple leather cord necklace with a small metal piece at his throat, catching the light. He has no motorcycle, no vehicle — he walks alone. Color palette: faded dark brown duster, warm skin, sand, scar red-white, metallic glint of the necklace. Semi-realistic thick-paint art style, epic wide-angle composition, wind-swept post-apocalyptic wasteland. Full body character design sheet.
```

#### バストアップ（カード用ポートレート）

```
Portrait bust shot of a towering muscular warrior in his late 20s to early 30s in a post-apocalyptic wasteland. In the prime of his life — a body built for destruction, yet eyes that hold no malice. A long faded duster coat worn open, revealing a massively scarred bare chest of peak musculature. A single leather shoulder guard on one shoulder. Pure black hair swept back to shoulder length, blowing in desert wind — no gray, young and vital. A single deep scar from between his eyebrows to his left cheek. Thick brows, fierce handsome young face that paradoxically holds quiet kindness in the eyes. Short stubble, no signs of aging. Both fists wrapped in layered tape and bandages, arms crossed. A simple metal-piece necklace on a leather cord at his throat glinting in the light. He evokes a legendary martial artist archetype — young, impossibly strong, yet purposeless and gentle. Dramatic wind-swept lighting, endless desert behind him. Semi-realistic thick-paint art style, Fist of the North Star meets spaghetti western aesthetic.
```

---

## 6. 享楽者 — ホタル (Hotaru)

### ビジュアル仕様

| 項目 | 内容 |
|---|---|
| 体格 | 155cm / 44kg。細い四肢と薄い胴体に、変異による巨大なバストが乗った不均衡な体型。肋骨が浮くほど痩せているのに胸だけが異常に重く、前傾姿勢が癖になっている。Nカップ相当（B100/W53/H83）。ホーネットの豊満さが「鍛えた身体の上の均整」であるのに対し、ホタルの巨乳は「壊れた身体の上の奇形」。色気ではなく異様さが先に立つ |
| 顔 | 実年齢25歳、外見15-16歳。丸みのある幼い顔立ちに、瞳孔が常にわずかに散大した目。虹彩の色が光の加減で琥珀→蛍光緑→灰紫に変わる（ネオン代謝物の蓄積）。口角が自然に上がっており、無表情でも笑っているように見える。頬はネオンの食欲抑制でこけ気味だが、骨格自体は整っていて、清潔にすれば年相応の美人だとわかる造形。ただし瞳の色が変わる目を長く見つめると、その「年相応」がどの年齢を指すのかわからなくなる |
| 髪 | 地毛は黒のセミロング（肩甲骨あたり）。そこに蛍光ピンクと蛍光イエローのエクステが大量に編み込まれ、三色が入り混じった派手な見た目。手入れは歓楽街仕込みで意外と丁寧——櫛を通す習慣だけが「元の生活」の残滓。ただし旅が長くなると根元の黒が伸びてエクステとの境界がはっきりし、「染め直せない放浪者」の現実が滲む |
| 服装上半身 | 世紀末改造バニースーツ。元は黒い合皮のレオタードだったものを防刃繊維のパッチワークで補修・補強してある。胸元は破れと補修を繰り返した痕跡で継ぎ接ぎだらけ。ネオンピンクの糸で縫った補修跡がアクセントになっている。巨大なバストがレオタードの布地を限界まで押し広げており、谷間というより布が負けている形状。ウサギ耳のカチューシャはボロボロの合皮で片耳が折れかけている。首元に小さなネオンバイアル（蛍光液体入りのガラス管）をペンダントにしている |
| 服装下半身 | レオタードの下に黒い網タイツ。片脚だけ膝上から大きく破れたまま放置されている（直す気がない）。破れた側の太ももが露出するが、その脚は細く、膝の骨が目立つほど華奢。ウェストにユーティリティベルトを巻き、ネオンバイアルのホルダーが4本分並ぶ（中身が入っているのは0〜2本。残りは空） |
| 足元 | 厚底のショートブーツ（歓楽街のクラブ仕様、ヒール8cm）。荒野には完全に不向きだが、これ以外の靴を持っていない。ヒールの底が磨り減って斜めになっている |
| アクセサリ | 首のネオンバイアル・ペンダント（常に身につけている。最後の一本を首にかけておく習慣）。両手首に蛍光色のミサンガ（歓楽街の同僚から貰った。名前は覚えていない）。左耳に小さなスタッドピアス（安物。光の角度でネオングリーンに見える素材） |
| 特徴的な傷 | 左の二の腕の内側に注射痕の集中（ネオンの静脈投与の痕。普段はレオタードで隠れるが、ズレると見える）。背中の右肩甲骨の下に小さな火傷痕（歓楽街での「事故」。詳細は語らない） |
| 肌の特異性 | 暗所でごく微かに発光する（ネオン代謝物が皮下に蓄積。星明かり程度で肌が淡く蛍光緑に光る）。体温が常人より0.5-1度高い（ネオン代謝亢進）。汗にかすかにネオンの化学的な甘い匂いが混じる |
| 武装 | ベルトの裏に小型拳銃1丁（護身用。歓楽街では必需品だった）。戦闘での主力はカード（ネオン系・魅了系）であり、銃は最終手段 |
| バイク | 死んだ情報屋から持ち出したストリートレーサー。元は派手なネオンアンダーグロウ（車体下の発光装置）が付いていたが、壊れて消灯したまま。タンクにニューエデンのクラブのステッカーが褪色して残る。サドルバッグにネオンの保管ケースと化粧ポーチ。整備状態は悪い——ホタルにバイク修理の知識がないため、走るたびにどこかがガタつく |
| 配色 | 黒（レオタード基調）+ 蛍光ピンク（髪・補修糸・ネオン液）+ 蛍光イエロー（髪・ベルトのアクセント）+ 素肌。暗所では肌の微発光と、ネオンバイアルの蛍光が加わり、文字通り「蛍」になる |
| 印象 | 歓楽街から逃げ出してきた壊れたおもちゃ。バニースーツは戦場に持ち込まれた場違いの衣装だが、ホタルにとってはこれが「普通の服」。巨大なバストと棒のような脚の対比、破れた網タイツ、折れかけのウサギ耳、色の変わる目——すべてが「普通じゃない」方向に揃っている。明るく笑う顔がいちばん不気味 |

### カラーリング方針メモ

蛍光ピンク＋蛍光イエローは物語的根拠に基づく:
- **ホタル（蛍）**: 暗闘で光る。蛍光色は彼女のネオン汚染を視覚化したもの
- ニューエデン歓楽街のネオンサインの色（青白＋ピンク＋黄）が身体に染みついている
- 蛍光色を「髪とアクセント」に限定し、ベースは黒で統一。ホーネットの黒+金が「スズメバチの警告色」ならば、ホタルの黒+蛍光は「毒物の警告色」
- 暗所での皮膚の微発光が「蛍」のモチーフを完成させる。これは演出ではなくネオン汚染の症状

### ホーネットとの視覚的差別化

| 要素 | ホーネット | ホタル |
|---|---|---|
| 体格 | 167cm。均整の取れたグラマラス | 155cm。上半身だけ異常に重い不均衡 |
| 胸 | Lカップ。革バンドゥで「鎧」として機能 | Nカップ。パッチワークのレオタードが「負けている」 |
| 露出の意味 | 意図的な威嚇と誘惑。見せることで主導権を握る | 無頓着。これが普通の服。見せている自覚がない |
| 配色 | 黒+金。高級感のある危険 | 黒+蛍光。安っぽい毒々しさ |
| 傷跡 | 戦闘の勲章。強さの証明 | 注射痕。依存の証明 |
| 印象 | 殺し屋としての色気 | 壊れた玩具としての異様さ |

### 服装レイヤー設計メモ

バニースーツの上に羽織物を設けることで、演出バリエーションを確保:
- **移動時（ポンチョ着用）**: 荒野の砂避けに情報屋のポンチョを羽織る。ウサギ耳だけ突き出て異様だが、体型は隠れる。「何か変な旅人」程度の印象
- **戦闘時（ポンチョ脱ぎ）**: バニースーツ全開。蛍光色の髪、巨大なバスト、網タイツの破れ、ベルトのネオンバイアル——「異様」の全要素が出揃う
- **休息/イベント時**: レオタードのジッパーを下ろした半脱ぎ、または下着状態。変異による胸の不自然な形状と、肋骨の浮く胴体の対比が最も露わになる
- いずれの状態でも首のネオンバイアル・ペンダントは外さない

### 画像生成プロンプト

#### 全身立ち絵（バイク座り）

```
(Sketch art, line art, drawn), 1girl, solo, looking at viewer with unnervingly bright smile, huge breasts on a very thin small frame creating extreme top-heavy disproportion, sitting on motorcycle with legs crossed, short 155cm petite build but with disproportionately massive chest straining against outfit, neon pink and neon yellow hair extensions woven into natural black semi-long hair creating a chaotic tri-color mix, slightly dilated pupils with color-shifting irises that appear amber-green-purple, round youthful face that looks 15-16 but with something off in the eyes, sunken cheeks from malnutrition despite cute bone structure, modified black bunny girl leotard with patchwork ballistic fiber patches sewn with neon pink thread, one broken rabbit ear headband in worn synthetic leather, black fishnet stockings with one leg torn from mid-thigh showing thin bony leg, thick-soled club boots with worn-down heels, utility belt with neon vial holders at waist with some empty some glowing with fluorescent liquid, small neon vial pendant on neck as necklace containing faintly glowing green liquid, fluorescent colored friendship bracelets on both wrists, small pistol tucked in belt, visible ribs and thin waist contrasting with enormous chest, sitting on a flashy street racer motorcycle with broken underglow tubes still attached and faded club stickers on tank, needle track marks barely visible on inner left arm, post apocalyptic desert, covered in dust, the overall impression is bizarre not sexy, masterwork, masterpiece, best quality, detailed, depth of field, high detail, very aesthetic, 8k, dynamic pose, dynamic angle, dynamic lighting
```

#### バストアップ（カード用ポートレート）

```
(Sketch art, line art, drawn), portrait bust shot of a bizarre-looking girl who appears 15-16 but is clearly not a normal teenager, huge breasts straining against a patchwork black bunny girl leotard with neon pink stitch repairs, round youthful face with sunken cheeks and an unsettlingly bright natural smile, slightly dilated pupils with color-shifting irises appearing amber to fluorescent green, neon pink and neon yellow hair extensions tangled into black hair framing her face, one drooping rabbit ear headband in worn synthetic leather, small glowing neon vial pendant at her neck containing fluorescent liquid, faintly luminescent skin with a subtle greenish glow at the edges, needle marks barely visible on inner arm, the contrast between her cute face and the wrongness of everything else creates deep uncanny valley, warm neon-tinted side lighting against dark post-apocalyptic background, masterwork, best quality, detailed, very aesthetic, 8k
```

---

## 5PC + NPC素材の視覚的対比

| | カルティスト | ホーネット | ウェス | ミーシャ | 覇者NPC素材 | ホタル |
|---|---|---|---|---|---|---|
| **年齢感** | 若い（20前後） | 若い（22歳） | やや若い（30後半〜40前半） | 幼い（18歳、見た目14-15） | 若い（20後半〜30前半） | 不詳（25歳、見た目15-16） |
| **シルエット** | 引き締まった縦長（ポンチョ+サドルバッグ） | 曲線的なS字（豊満+革ジャン） | ポンチョの台形 | 小さく不定形（+虎） | 巨大な逆三角+コート裾 | 上半身だけ膨らんだ不均衡（バニースーツ+細い脚） |
| **肌の露出** | 中程度（ポンチョの隙間から紋様） | 多い（意図的、胸と脚を強調） | 少ない（すべて覆う） | 多い（服がない。脚の露出が顕著） | 多い（コートの隙間から筋肉） | 多い（無頓着。網タイツの破れ、レオタードの隙間） |
| **露出が語るもの** | 控えめな部族的信仰の痕跡 | 色気・威嚇・豊満な自信 | 何も見せない寡黙さ | 貧困・野生・華奢な脆さ | 全盛期の肉体・歴戦の傷 | 無頓着・変異・壊れた日常の延長 |
| **主な配色** | 黒+オレンジ+赤土+オイルの光沢 | 黒（革）+金（髪）+黄アクセント+銀+肌色 | 紺+砂色 | 土色+枯草+肌色 | 褪色茶（コート）+肌色+砂 | 黒+蛍光ピンク+蛍光イエロー+肌の微発光 |
| **見る者の印象** | 一見普通だが何か違う青年旅人 | 危険で豊満な金髪の元殺し屋 | 若いのに疲弊した旅人 | 可愛い顔の壊れた野生児 | 最強なのに目的がない青年 | 歓楽街から逃げてきた壊れた玩具 |
| **立ち姿** | バイクに跨り前を見据える（巡礼） | 片腰に手、胸を張る/銃を構える | 遠くを見る、手はポケット | 身を縮める+虎が寄り添う | 腕組み、コートが翻る | 前傾気味に笑う。胸の重さで姿勢が崩れている |
