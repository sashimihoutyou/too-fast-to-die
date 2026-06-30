class_name AmbientFragment extends RefCounted

const NO_COMPANION_TYPE: int = -1
const LOW_SHOW_CHANCE: float = 0.38
const COMPANION_SHOW_CHANCE: float = 0.68
const TRANSIENT_SHOW_CHANCE: float = 1.0

static func pick(node_type: MapGenerator.NodeType) -> Dictionary:
	var pool: Array[Dictionary] = _get_pool()
	var candidates: Array[Dictionary] = []
	var highest_priority: int = -999

	for fragment: Dictionary in pool:
		if not _matches(fragment, node_type):
			continue
		var priority: int = int(fragment.get("priority", 0))
		if priority > highest_priority:
			highest_priority = priority
			candidates.clear()
		if priority == highest_priority:
			candidates.append(fragment)

	if candidates.is_empty():
		return {}

	var show_chance: float = LOW_SHOW_CHANCE
	if GameManager.recent_companion_event != &"":
		show_chance = TRANSIENT_SHOW_CHANCE
	elif GameManager.has_any_companion():
		show_chance = COMPANION_SHOW_CHANCE
	if randf() > show_chance:
		return {}

	return _weighted_pick(candidates)

static func mark_seen(fragment: Dictionary) -> void:
	var id: StringName = fragment.get("id", &"")
	if id == &"":
		return
	if bool(fragment.get("once_per_run", false)):
		GameManager.event_flags[_seen_flag(id)] = true
	var sets_flag: StringName = fragment.get("sets_flag", &"")
	if sets_flag != &"":
		GameManager.event_flags[sets_flag] = true

static func consume_transient_context() -> void:
	GameManager.clear_recent_companion_event()

static func _matches(fragment: Dictionary, node_type: MapGenerator.NodeType) -> bool:
	if bool(fragment.get("once_per_run", false)):
		var id: StringName = fragment.get("id", &"")
		if id != &"" and bool(GameManager.event_flags.get(_seen_flag(id), false)):
			return false

	var required_flags: Array = fragment.get("required_flags", [])
	for flag in required_flags:
		if not bool(GameManager.event_flags.get(flag, false)):
			return false

	var blocked_flags: Array = fragment.get("blocked_flags", [])
	for flag in blocked_flags:
		if bool(GameManager.event_flags.get(flag, false)):
			return false

	var node_types: Array = fragment.get("node_types", [])
	if not node_types.is_empty() and int(node_type) not in node_types:
		return false

	var min_act: int = int(fragment.get("min_act", 1))
	var max_act: int = int(fragment.get("max_act", GameManager.MAX_ACT))
	if GameManager.current_act < min_act or GameManager.current_act > max_act:
		return false

	var character_id: StringName = fragment.get("character_id", &"")
	var current_character_id: StringName = &""
	if GameManager.current_character != null:
		current_character_id = GameManager.current_character.id
	if character_id != &"" and character_id != current_character_id:
		return false

	if bool(fragment.get("requires_companion", false)) and not GameManager.has_any_companion():
		return false

	var companion_type: int = int(fragment.get("companion_type", NO_COMPANION_TYPE))
	if companion_type != NO_COMPANION_TYPE:
		var current_type: int = NO_COMPANION_TYPE
		for companion: CompanionData in GameManager.get_active_companions():
			if int(companion.companion_type) == companion_type:
				current_type = companion_type
				break
		if current_type == NO_COMPANION_TYPE and GameManager.recent_companion_event != &"":
			current_type = int(GameManager.recent_companion_type)
		if current_type != companion_type:
			return false

	var companion_id: StringName = fragment.get("companion_id", &"")
	if companion_id != &"":
		var current_companion_id: StringName = &""
		if GameManager.is_companion_active(companion_id):
			current_companion_id = companion_id
		elif GameManager.recent_companion_event != &"":
			current_companion_id = GameManager.recent_companion_id
		if current_companion_id != companion_id:
			return false

	var required_event: StringName = fragment.get("recent_companion_event", &"")
	if required_event != &"" and GameManager.recent_companion_event != required_event:
		return false

	var min_euphoria: int = int(fragment.get("min_euphoria", -1))
	if min_euphoria >= 0 and CombatManager.player_euphoria < min_euphoria:
		return false
	var max_euphoria: int = int(fragment.get("max_euphoria", -1))
	if max_euphoria >= 0 and CombatManager.player_euphoria > max_euphoria:
		return false

	var min_heat: int = int(fragment.get("min_heat", -1))
	if min_heat >= 0 and CombatManager.player_heat < min_heat:
		return false
	var max_heat: int = int(fragment.get("max_heat", -1))
	if max_heat >= 0 and CombatManager.player_heat > max_heat:
		return false

	var min_faith: int = int(fragment.get("min_faith", -1))
	if min_faith >= 0 and GameManager.faith < min_faith:
		return false
	var max_faith: int = int(fragment.get("max_faith", -1))
	if max_faith >= 0 and GameManager.faith > max_faith:
		return false

	var min_fuel: int = int(fragment.get("min_fuel", -1))
	if min_fuel >= 0 and ResourceManager.fuel < min_fuel:
		return false
	var max_fuel: int = int(fragment.get("max_fuel", -1))
	if max_fuel >= 0 and ResourceManager.fuel > max_fuel:
		return false

	var min_bike: int = int(fragment.get("min_bike", -1))
	if min_bike >= 0 and ResourceManager.bike_durability < min_bike:
		return false
	var max_bike: int = int(fragment.get("max_bike", -1))
	if max_bike >= 0 and ResourceManager.bike_durability > max_bike:
		return false

	return true

static func _weighted_pick(candidates: Array[Dictionary]) -> Dictionary:
	var total_weight: int = 0
	for fragment: Dictionary in candidates:
		total_weight += maxi(1, int(fragment.get("weight", 1)))

	var roll: int = randi_range(1, total_weight)
	var cursor: int = 0
	for fragment: Dictionary in candidates:
		cursor += maxi(1, int(fragment.get("weight", 1)))
		if roll <= cursor:
			return fragment
	return candidates[0]

static func _seen_flag(id: StringName) -> StringName:
	return StringName("ambient_seen_%s" % id)

static func _get_pool() -> Array[Dictionary]:
	return [
		{
			"id": &"love_slave_joined_road",
			"title": "荷台の沈黙",
			"body": "荷台で、誰かが息を整える音だけが続いた。\nホタルは振り返らない。ネオンの残り香と砂埃が、同じ温度で喉に入ってくる。\n次の揺れで、後ろの影が少しだけ近づいた。",
			"character_id": &"hedonist",
			"companion_type": CompanionData.CompanionType.LOVE_SLAVE,
			"recent_companion_event": &"recruited",
			"priority": 100,
			"weight": 1,
			"once_per_run": true,
			"tags": [&"road", &"companion", &"love_slave", &"neon"],
		},
		{
			"id": &"love_slave_departed_road",
			"title": "軽くなった席",
			"body": "荷台の重みがひとつ消えた。\nエンジン音は変わらない。それなのに、ホタルの背中には空席の形だけが残った。\nジュリエットの握りが、いつもより少し冷たい。",
			"character_id": &"hedonist",
			"companion_type": CompanionData.CompanionType.LOVE_SLAVE,
			"recent_companion_event": &"departed",
			"priority": 100,
			"weight": 1,
			"once_per_run": true,
			"tags": [&"road", &"companion", &"withdrawal"],
		},
		{
			"id": &"love_slave_direct_heat",
			"title": "短い停車",
			"body": "古い標識の影で、バイクが一度だけ止まった。\n言葉はほとんどなかった。求める手と、応じる体温と、すぐ先で鳴る追っ手の幻聴。\n走り出す頃、ホタルの目は少しだけ明るくなっていた。",
			"character_id": &"hedonist",
			"companion_type": CompanionData.CompanionType.LOVE_SLAVE,
			"min_euphoria": 60,
			"priority": 60,
			"weight": 2,
			"tags": [&"road", &"companion", &"sex", &"neon"],
		},
		{
			"id": &"love_slave_indirect",
			"title": "後部座席",
			"body": "後ろから服の布ずれが聞こえた。\nホタルはミラーを少しだけ上げる。見えたのは顔ではなく、指先と、言いつけを待つような姿勢だった。\n燃料計の針が跳ねる。体の奥の針も、少し遅れて跳ねた。",
			"character_id": &"hedonist",
			"companion_type": CompanionData.CompanionType.LOVE_SLAVE,
			"priority": 60,
			"weight": 3,
			"tags": [&"road", &"companion", &"sex"],
		},
		{
			"id": &"love_slave_tired",
			"title": "消耗",
			"body": "休ませたほうがいい。そう思う前に、ホタルの指はスロットルを戻していた。\n相手は文句を言わない。ただ息を飲み、また命令を待つ。\nその従順さが、快楽より重く残る夜もある。",
			"character_id": &"hedonist",
			"companion_type": CompanionData.CompanionType.LOVE_SLAVE,
			"max_euphoria": 70,
			"priority": 60,
			"weight": 2,
			"tags": [&"road", &"companion", &"fatigue", &"dependence"],
		},
		{
			"id": &"companion_shared_water",
			"title": "回し飲み",
			"body": "水筒は軽かった。\n先に飲め、と差し出すと、同行者は少し迷ってから口をつけた。返ってきた金属の縁に、砂と体温が残っている。\nそれだけで、道が少しだけ人間のものに戻った。",
			"requires_companion": true,
			"priority": 45,
			"weight": 2,
			"tags": [&"road", &"companion"],
		},
		{
			"id": &"dog_wanderer_clock",
			"title": "止まった時計",
			"body": "犬の耳が風向きに合わせて動く。\nウェズリーは止まった腕時計を見て、また前を向いた。時刻は読めない。けれど犬は、進むべき方角だけは間違えない。\n「行くぞ、パートナー」",
			"character_id": &"wanderer",
			"companion_type": CompanionData.CompanionType.DOG,
			"priority": 55,
			"weight": 2,
			"tags": [&"road", &"companion", &"dog"],
		},
		{
			"id": &"informant_pursuit",
			"title": "無線の針",
			"body": "同行者が古い無線機のつまみを爪で弾いた。\n雑音の奥に、誰かの呼吸が混ざる。追跡網はまだ遠い。だが遠いものほど、まっすぐ近づいてくる。\n速度を落とす理由はなかった。",
			"companion_type": CompanionData.CompanionType.INFORMANT,
			"priority": 50,
			"weight": 2,
			"tags": [&"road", &"companion", &"pursuit"],
		},
		{
			"id": &"ex_raider_heat_road",
			"title": "革ジャンの内側",
			"body": "ホーネットは革ジャンの襟を引き下ろした。\n熱は傷口ではなく、もっと古い場所から上がってくる。コカトリスの街路灯、銃声、笑い声。\n全部まとめて、スロットルで踏み潰した。",
			"character_id": &"ex_raider",
			"min_heat": 45,
			"priority": 35,
			"weight": 2,
			"tags": [&"road", &"heat"],
		},
		{
			"id": &"cultist_faith_low",
			"title": "火のない祈り",
			"body": "アータルはペンダントを握った。\n祈りの言葉は途中で止まる。砂の上に落ちた影は、聖印よりエンジンの形に似ていた。\nそれでも手は、まだ離れない。",
			"character_id": &"cultist",
			"max_faith": 49,
			"priority": 35,
			"weight": 2,
			"tags": [&"road", &"faith"],
		},
		{
			"id": &"fuel_low",
			"title": "軽いタンク",
			"body": "燃料タンクの中で、最後の液体が薄く鳴った。\n音は頼りない。だがゼロではない。\nゼロでないなら、まだ道は命令できる。",
			"max_fuel": 6,
			"priority": 30,
			"weight": 2,
			"tags": [&"road", &"fuel"],
		},
		{
			"id": &"bike_damaged",
			"title": "軋む車体",
			"body": "フレームの奥で、嫌な金属音がした。\nバイクは文句を言わない。壊れる直前まで働き、壊れてから初めて沈黙する。\n手のひらに残る振動だけが、まだ生きていた。",
			"max_bike": 4,
			"priority": 30,
			"weight": 2,
			"tags": [&"road", &"bike"],
		},
		{
			"id": &"combat_smell",
			"title": "血の前触れ",
			"body": "風に鉄の匂いが混じった。\n誰かが先に撃ったのか、誰かが先に倒れたのか。順番はもう関係ない。\n前方の砂が、低く震えている。",
			"node_types": [MapGenerator.NodeType.COMBAT, MapGenerator.NodeType.ELITE, MapGenerator.NodeType.BOSS],
			"priority": 20,
			"weight": 3,
			"tags": [&"road", &"combat"],
		},
		{
			"id": &"shop_lights",
			"title": "値札の灯り",
			"body": "遠くに、店の灯りが見えた。\n安全の色ではない。値段の色だ。助かるものにも、壊れるものにも、同じ数字がぶら下がっている。\n財布より先に、喉が乾いた。",
			"node_types": [MapGenerator.NodeType.SHOP],
			"priority": 20,
			"weight": 3,
			"tags": [&"road", &"shop"],
		},
		{
			"id": &"rest_smoke",
			"title": "休める場所",
			"body": "煙の細い柱が、岩陰から上がっていた。\n罠かもしれない。焚き火かもしれない。どちらにせよ、夜を越すには近づくしかない。\nエンジンを切る前から、耳が静けさを探している。",
			"node_types": [MapGenerator.NodeType.REST],
			"priority": 20,
			"weight": 3,
			"tags": [&"road", &"rest"],
		},
		{
			"id": &"info_antenna",
			"title": "折れたアンテナ",
			"body": "折れた通信塔が、夕日の中で黒く立っていた。\n誰かがここで情報を拾い、誰かがここで嘘を流した。\n真実は錆びない。錆びるのは、真実を運ぶ機械だけだ。",
			"node_types": [MapGenerator.NodeType.INFO],
			"priority": 20,
			"weight": 3,
			"tags": [&"road", &"info"],
		},
		{
			"id": &"act2_salt_flat",
			"title": "白い地面",
			"body": "白く乾いた地面が、月明かりを返していた。\n水の死骸だ、と誰かが言った。タイヤはその上を静かに渡る。\n足跡だけが、まだ生き物のふりをしている。",
			"min_act": 2,
			"priority": 10,
			"weight": 2,
			"tags": [&"road", &"landmark"],
		},
		{
			"id": &"generic_neon_memory",
			"title": "遠いネオン",
			"body": "地平線の向こうで、見えるはずのないネオンが瞬いた気がした。\n幻覚か、記憶か、ただの反射か。\n確かめに行くほど、道は親切ではない。",
			"priority": 5,
			"weight": 4,
			"tags": [&"road", &"neon"],
		},
	]
