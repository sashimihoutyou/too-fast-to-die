# Too Fast to Die: Road to Oasis - Image Generation Prompts

`docs/character-visuals.md` の画風を基準に、ゲーム内で必要になる敵・背景・タイトル・ロゴ・UI用素材を生成するためのプロンプト集。

## 共通スタイル

### Positive Base

すべての主要アセットの末尾に追加する共通指定。

```text
semi-realistic thick-paint digital illustration, heavy ink-like linework, dramatic chiaroscuro shadows, gritty post-apocalyptic road movie atmosphere, rusted metal, dust, cracked leather, sun-bleached cloth, nuclear winter afterglow, American Midwest wasteland 32 years after localized nuclear war, desert sand #D4A855, rust orange #C45A2D, scorched black #1A1A1A, iron gray #4A4A4A, high detail, game asset concept art, sharp readable silhouette, no clean fantasy armor, no glossy sci-fi utopia
```

### Negative Base

```text
low quality, blurry, smooth plastic skin, cute mascot style, chibi, anime school uniform, modern clean city, cyberpunk skyscraper city, pristine chrome, generic fantasy, medieval castle, green lush forest, cheerful cartoon, overexposed, washed out, unreadable silhouette, extra limbs, malformed hands, deformed vehicle wheels, random text, watermark, logo artifacts
```

### 敵画像の共通指定

横長バトル画面で読みやすいよう、敵は「全身・少し斜め・背景なし/薄背景」を基本にする。

```text
full body enemy sprite concept, 3/4 view facing left, isolated on transparent or very simple dusty background, strong silhouette readable at small size, combat-ready pose, feet grounded, centered composition, no player character, no UI, no text
```

### 背景画像の共通指定

戦闘UIとカードが乗るため、中央下部は少し情報量を抑える。

```text
wide 16:9 game background, no characters in foreground, clear empty combat floor in lower third, layered parallax-friendly composition, horizon line visible, readable silhouettes, atmospheric dust, cinematic but not too busy, no text, no UI
```

## タイトル・ロゴ

### タイトル画面背景

```text
wide 16:9 title screen background for a post-apocalyptic card battle road roguelite, a lone large motorcycle stopped on a cracked highway in the American Midwest wasteland, empty road leading toward a distant rumor-like oasis hidden beyond heat haze, rusted road signs, abandoned gas station silhouettes, orange dust storm on the horizon, faint cold blue remnants of nuclear winter in the upper sky, foreground asphalt broken by dry weeds, strong negative space in the upper center for game title, melancholic but fast and dangerous mood, semi-realistic thick-paint digital illustration, heavy shadows, rust orange sunset lighting, high detail
```

### メインロゴ

```text
logo design for "Too Fast to Die: Road to Oasis", post-apocalyptic biker road roguelite, bold distressed block letters, speed streaks carved into the letter edges, cracked asphalt texture, rusted metal inlays, subtle V8 engine crown motif hidden in the top silhouette, small desert road line running through the subtitle, color palette scorched black, iron gray, rust orange, desert sand, readable at small size, transparent background, no extra words, no mockup, no background scene
```

### アイコン用シンボル

```text
square game icon symbol, a rusted motorcycle wheel fused with a V8 engine crown and a cracked road arrow pointing forward, post-apocalyptic desert palette, scorched black silhouette with rust orange highlights, thick painterly edges, readable at 64px, no text, transparent background
```

## 背景

### Act 1 荒野 / ニューエデン辺境

```text
wide 16:9 game background, post-apocalyptic American Midwest wasteland at the edge of New Eden territory, cracked two-lane road, dead grass, rusted oil pumps, distant refinery settlement with patched metal walls and thin smoke, scattered fuel drums, faded warning signs, dry yellow sand and rust orange dust, harsh afternoon sun, lower third kept open as combat floor, semi-realistic thick-paint digital illustration, gritty road movie mood
```

### Act 2 廃墟都市 / 中立圏

```text
wide 16:9 game background, ruined midwestern city after 32 years of collapse, broken highway overpass, collapsed parking structures, abandoned cars half-buried in dust, dead traffic lights, scavenger camp traces but no people in foreground, cold gray concrete mixed with rust orange sunlight, patches of radioactive warning paint, lower third open for combat, heavy shadow, semi-realistic thick-paint digital illustration
```

### Act 3 砂漠 / サンドバイパーズ圏

```text
wide 16:9 game background, vast desert territory controlled by the Sand Vipers, wind-carved dunes over cracked asphalt, improvised toll gate made from scrap metal and tank traps in the distance, snake-like banners torn by sandstorm, burned-out convoy wrecks, sun glaring through tan dust, lower third flat and open as combat arena, rusted weapon silhouettes at the edges, semi-realistic thick-paint digital illustration
```

### Act 4 山岳部 / ラケダイモーン圏

```text
wide 16:9 game background, harsh mountain pass under Lacedaemon control, fortified checkpoint built from concrete, scrap iron, and old military medical facility parts, black iron shields and spear-like radio masts, slave-worked terraced fields far below, torchlight mixed with cold mountain dusk, disciplined oppressive order, lower third clear rocky combat ground, semi-realistic thick-paint digital illustration
```

### Act 5 沿岸部 / ノウアスフィア隠し圏

```text
wide 16:9 game background, foggy poisoned coastline near hidden Noosphere facilities, cracked coastal highway, dead reeds, brackish water reflecting pale green light, half-buried automated defense towers, sealed bunker door in the cliff face, distant ocean under nuclear winter haze, quiet technological menace, lower third open wet concrete combat floor, semi-realistic thick-paint digital illustration
```

### オアシス到達画面

```text
wide 16:9 ending background, the rumored Oasis revealed beyond the wasteland, a massive sealed self-sustaining nuclear shelter partially embedded under desert rock, clean water glinting inside a protected basin, old solar mirrors, defensive doors scarred by time, the scene must feel real and ambiguous rather than heavenly, hope mixed with unease, motorcycle tracks stopping in the foreground, semi-realistic thick-paint digital illustration, golden light breaking through gray sky
```

## 敵

### Act 1

#### 荒野の盗賊

```text
full body enemy sprite concept, 3/4 view facing left, wasteland bandit in patched leather and scavenged sports pads, rusty pistol in one hand, chipped machete at belt, wrapped face against dust, lean hungry body, stolen fuel cans tied to backpack, mismatched boots, nervous aggressive stance, human enemy, post-apocalyptic Midwest, semi-realistic thick-paint digital illustration, strong readable silhouette
```

#### デビルフ

```text
full body enemy sprite concept, 3/4 view facing left, mutant American red wolf called Deviwolf, lean powerful canine body, split oversized jaw, jagged teeth, red-brown mangy fur, exposed scar tissue, yellow predatory eyes, long legs built for chasing motorcycles, dust clinging to ribs, stable believable mutation not fantasy demon, low stalking pose, semi-realistic thick-paint digital illustration
```

#### 野犬の群れ

```text
enemy group sprite concept, 3/4 view facing left, pack of feral wasteland dogs, three to five thin aggressive dogs with torn ears and scars, different sizes but one shared silhouette mass, dust and drool, cracked collars from dead owners, surrounding formation, readable as a group at small size, semi-realistic thick-paint digital illustration
```

#### ならず者ライダー

```text
full body elite enemy sprite concept, rogue biker dismounted beside a battered motorcycle, 3/4 view facing left, sawed-off shotgun, spiked tire armor on jacket, fuel hose wrapped around shoulder, helmet visor cracked, aggressive forward lean, motorcycle partly visible as silhouette support, dust cloud behind, semi-realistic thick-paint digital illustration
```

#### デビルフの群れリーダー

```text
full body elite enemy sprite concept, larger Deviwolf pack leader, 3/4 view facing left, scarred red-brown mutant wolf, split jaw wider than normal Deviwolf, broken rebar collar tangled in fur, old bullet scars, commanding posture with smaller wolf shadows behind it, yellow eyes, dust storm backlight, semi-realistic thick-paint digital illustration
```

#### アルファ・デビルフ

```text
full body boss enemy concept, alpha Deviwolf, enormous mutant American red wolf standing on cracked highway, 3/4 view facing left, massive split jaw, long exposed fangs, scarred muzzle, powerful shoulders, red-brown fur darkened by oil and blood, one torn ear, pack silhouettes behind, boss-level presence, low camera angle, dust and rust orange sunset backlight, semi-realistic thick-paint digital illustration, clear silhouette
```

### Act 2

#### スカベンジャー

```text
full body enemy sprite concept, wasteland scavenger in layered rags and old respirator, 3/4 view facing left, carrying a crowbar and a sack of scrap electronics, patched backpack, flashlight taped to shoulder, cautious greedy posture, city ruin dust, human enemy, semi-realistic thick-paint digital illustration
```

#### 汚染ラット群

```text
enemy group sprite concept, swarm of contaminated mutant rats, 3/4 view facing left, many oversized rats with patchy fur, pale sores, faint green radioactive grime, glowing eyes in sewer darkness, crawling over broken concrete and rusted cans, one large rat leading the mass, readable swarm silhouette, semi-realistic thick-paint digital illustration
```

#### 殺人ロボット

```text
full body machine enemy sprite concept, old pre-war security robot repurposed as killer machine, 3/4 view facing left, rusted bipedal chassis, cracked police-white armor panels, exposed cables, one red optical sensor, hydraulic arms with built-in shock baton and nailgun, uneven walking stance, heavy iron gray and rust orange palette, semi-realistic thick-paint digital illustration
```

#### ガーディアンドローン

```text
full body elite machine enemy concept, hovering guardian drone from an abandoned facility, 3/4 view facing left, compact armored body, four damaged rotors, stabilized gun pod, cold red sensor eye, scratched serial markings, dust blown downward by rotors, old world technology decayed but still lethal, semi-realistic thick-paint digital illustration
```

#### レイダーバイカーデュオ

```text
elite enemy duo concept, two raider bikers fighting as a pair, 3/4 view facing left, one with chain weapon and spiked helmet, one with pistol and road shield made from a car door, two battered motorcycles behind them, coordinated ambush stance, black leather, yellow hazard paint, dust and exhaust smoke, semi-realistic thick-paint digital illustration, readable pair silhouette
```

#### 暴走キラーロボット

```text
full body boss machine concept, runaway killer robot from ruined city, tall heavy pre-war combat robot, 3/4 view facing left, damaged armored torso, exposed glowing reactor core, mismatched replacement limbs, rotary cannon arm, hydraulic claw arm, broken warning lights, old civic service markings scratched away, sparks and smoke, boss presence, semi-realistic thick-paint digital illustration
```

### Act 3

#### サンドバイパー歩兵

```text
full body enemy sprite concept, Sand Viper infantry raider, 3/4 view facing left, desert toll-gang soldier with snake-pattern scarf, patched tactical vest, curved knife, old assault rifle, tan dust goggles, scrap metal shin guards, confident checkpoint enforcer posture, sand yellow and rust palette, semi-realistic thick-paint digital illustration
```

#### 砂漠キャラバン護衛

```text
full body enemy sprite concept, desert caravan guard, 3/4 view facing left, practical independent mercenary with sun cloak, reinforced leather vest, long rifle, water canteen and fuel tokens at belt, face shaded by wide brim hat, not evil but ready to kill, protective stance, semi-realistic thick-paint digital illustration
```

#### サソリ変異体

```text
full body beast enemy sprite concept, mutant desert scorpion, 3/4 view facing left, dog-sized to human-sized arachnid, cracked chitin like dry earth, enlarged venom tail, mismatched pincers, pale radiation scars, crawling over sand-buried asphalt, threatening low silhouette, semi-realistic thick-paint digital illustration
```

#### 砂漠の主（巨大サソリ）

```text
full body elite beast concept, giant mutant scorpion called Desert Lord, 3/4 view facing left, car-sized body, cracked black-brown chitin, massive crushing claws, towering venom tail casting shadow, sand streaming from shell, old license plates and bones stuck between plates, elite presence, semi-realistic thick-paint digital illustration
```

#### サンドバイパー軽戦車

```text
full body elite machine vehicle concept, Sand Viper light tank assembled from old military chassis and raider scrap, 3/4 view facing left, low fast profile, snake-mouth paint on front armor, patched treads, jury-rigged cannon, fuel drums strapped outside, sand flags, dust plume, readable vehicle silhouette, semi-realistic thick-paint digital illustration
```

#### サンドバイパーズ首領

```text
full body boss human concept, leader of the Sand Vipers, 3/4 view facing left, charismatic desert raider warlord at a toll gate, snake-scale patterned coat made from patched leather, polished old revolver, curved saber, dust goggles pushed up, necklace of fuel caps, calm predatory expression, banners and tank traps behind, boss-level silhouette, semi-realistic thick-paint digital illustration
```

### Act 4

#### ラケダイモーン歩兵

```text
full body enemy sprite concept, Lacedaemon infantry soldier, 3/4 view facing left, post-apocalyptic Spartan-Roman inspired armor made from blackened scrap iron, old riot shield reshaped like a hoplon, short spear, disciplined stance, red-brown cloth strips, military medical facility tags, oppressive order, semi-realistic thick-paint digital illustration
```

#### ラケダイモーン奴隷兵

```text
full body enemy sprite concept, Lacedaemon slave soldier, 3/4 view facing left, underfed conscript with simple iron collar, worn padded armor, short spear and cracked shield, fear and exhaustion in posture, numbered cloth tag, forced discipline rather than pride, mountain dust, semi-realistic thick-paint digital illustration
```

#### 山岳変異グリズリー

```text
full body beast enemy sprite concept, mutant mountain grizzly, 3/4 view facing left, huge bear with patchy dark fur, bony growths along shoulders, old trap scars, one cloudy eye, powerful forelimbs, breath steaming in cold mountain air, believable radiation mutation, semi-realistic thick-paint digital illustration
```

#### ラケダイモーン百人隊長

```text
full body elite human concept, Lacedaemon centurion, 3/4 view facing left, imposing commander in black scrap-metal cuirass, crested helmet made from red cable bundles, heavy rectangular shield, shock spear, medals made from dog tags, cold disciplined expression, mountain fortress lighting, semi-realistic thick-paint digital illustration
```

#### 奴隷商キャラバン

```text
elite enemy group concept, slave trader caravan, 3/4 view facing left, armored truck silhouette with cage trailer, two armed guards in patched coats, chain hooks, fuel lanterns, cruel commerce rather than chaos, dusty mountain road, readable group silhouette, semi-realistic thick-paint digital illustration
```

#### ラケダイモーン前哨部隊長

```text
full body boss human concept, Lacedaemon outpost commander, 3/4 view facing left, tall officer in brutal post-apocalyptic hoplite armor, black iron breastplate, red cloth mantle faded by dust, helmet under one arm, shock spear planted in ground, old military medical insignia on armor, cold strategic gaze, fortified mountain checkpoint behind, boss presence, semi-realistic thick-paint digital illustration
```

### Act 5

#### ノウアスフィアエージェント

```text
full body human enemy sprite concept, Noosphere agent, 3/4 view facing left, secretive field operative in dust-gray sealed coat, compact respirator, old-world tablet strapped to forearm, suppressed pistol, sensor lenses, cleanest silhouette in the wasteland but still worn and practical, pale green tech accents, semi-realistic thick-paint digital illustration
```

#### ノウアスフィア重装エージェント

```text
full body elite human enemy concept, Noosphere heavy agent, 3/4 view facing left, armored sealed suit made from pre-war composite plates, heavy magnetic rifle, respirator mask with multiple lenses, pale green diagnostic lights, tactical but secretive, no shiny utopia, scratched and field-repaired, semi-realistic thick-paint digital illustration
```

#### 沿岸変異体

```text
full body beast enemy sprite concept, coastal mutant humanoid, 3/4 view facing left, gaunt amphibious radiation mutant from poisoned shoreline, wet gray skin, salt-cracked sores, webbed hands, fishbone jewelry, hunched posture, brackish water dripping, tragic but dangerous, semi-realistic thick-paint digital illustration
```

#### 自動防衛タレット

```text
full body machine enemy sprite concept, automated defense turret, 3/4 view facing left, bunker-mounted machine turret torn from old Noosphere perimeter system, cracked concrete base, rotating twin barrels, red targeting lens, exposed wires, warning stripes faded, coastal fog, readable mechanical silhouette, semi-realistic thick-paint digital illustration
```

#### プロトタイプ警備ロボ

```text
full body elite machine concept, prototype guard robot, 3/4 view facing left, advanced but decayed pre-war security android, white ceramic armor cracked and stained by rust, exposed black underframe, one arm shield generator, one arm stun lance, pale green optical sensors, elegant old-world design made frightening by damage, semi-realistic thick-paint digital illustration
```

#### 門番

```text
full body boss machine concept, the Gatekeeper, massive autonomous bunker guardian blocking the road to Oasis, 3/4 view facing left, towering old-world defense robot integrated with a sealed gate mechanism, concrete and steel armor, multiple sensor eyes, heavy shield plates like a fortress door, missile pods sealed under rusted covers, pale green lights, coastal fog and bunker door behind, boss presence, semi-realistic thick-paint digital illustration
```

#### V8カルト大司祭

```text
full body boss human concept, V8 cult high priest, 3/4 view facing left, gaunt charismatic cult leader wearing ritual engine-part crown, black oil-slick hair, face and bare arms covered in engine oil and red clay circuit-like tribal markings, burned hands raised in sermon, sleeveless patched robe made from tires and sun-bleached cloth, V8 engine altar behind, gasoline firelight, fanatical eyes, boss presence, semi-realistic thick-paint digital illustration
```

#### コカトリス首領

```text
full body boss human concept, Cockatrice raider boss, 3/4 view facing left, veteran raider leader with bird-of-prey and venom motifs, black leather coat with scratched cockatrice emblem, hooked blade, heavy pistol, feather-like metal shoulder plates, cruel calculating eyes, slave chains and motorcycle silhouettes behind, yellow hazard accents, boss presence, semi-realistic thick-paint digital illustration
```

#### チェインリンク情報屋

```text
full body boss human concept, Chainlink informant, 3/4 view facing left, thin nervous slave-network broker in layered expensive rags, many chain-link necklaces, ledger book and radio handset, hidden pistol, oily smile, eyes always measuring escape routes, coastal bunker market shadows behind, human enemy, semi-realistic thick-paint digital illustration
```

#### チェインリンク幹部

```text
full body boss human concept, Chainlink executive, 3/4 view facing left, wealthy post-apocalyptic slave trade executive, armored long coat over clean shirt, gold fuel-token rings, chain-link cane, bodyguard shadows and cage-truck silhouette behind, calm predatory businesslike expression, not a wild raider but organized cruelty, boss presence, semi-realistic thick-paint digital illustration
```

## UI・カード用素材

### カード裏面

```text
vertical card back design for a post-apocalyptic road roguelite, centered cracked highway line forming an arrow, rusted motorcycle chain border, small V8 engine crown hidden at top, scorched black background with desert sand scratches and rust orange highlights, thick ink-like painted texture, readable at small size, no text, no characters
```

### カードフレーム

```text
vertical transparent card frame, post-apocalyptic metal and cracked asphalt design, rusted bolts, worn leather corner straps, subtle fuel gauge motif at the cost area, scorched black and iron gray with rust orange highlights, clean interior space for artwork and text, no words, game UI asset, transparent background
```

### 戦闘アイコンセット

```text
small game UI icon set, post-apocalyptic card battle, attack sword icon, shield block icon, fire status icon, bleeding drop icon, contamination radiation icon, fuel can icon, scrap metal icon, medicine vial icon, all in same style, thick readable silhouettes, scorched black shapes with rust orange and pale green accents, transparent background, no text
```

### マップノードアイコン

```text
small map node icon set for post-apocalyptic road roguelite, combat crossed blades, event exclamation sign on rusted road plate, shop fuel-token dollar mark, rest campfire, information radio question mark, elite skull, boss cracked crown, all icons made from rusted metal and asphalt texture, readable at 32px, transparent background, no extra text
```

