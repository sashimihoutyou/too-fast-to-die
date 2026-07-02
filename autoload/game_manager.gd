extends Node

signal state_changed(new_state: StringName)
signal run_started(character: CharacterData)
signal run_ended(result: StringName, distance: int)
signal companion_notification_queued(message: String)

enum GameState { TITLE, CHARACTER_SELECT, MAP, COMBAT, EVENT, SHOP, REST, GAME_OVER, RESULT }

const MAX_ACT := 5
const SIDECAR_RELIC_ID := &"sidecar"
const SCENE_PATHS := {
	GameState.TITLE: "res://scenes/main/title_screen.tscn",
	GameState.CHARACTER_SELECT: "res://scenes/main/character_select.tscn",
	GameState.MAP: "res://scenes/map/map_screen.tscn",
	GameState.COMBAT: "res://scenes/combat/combat_screen.tscn",
	GameState.EVENT: "res://scenes/event/event_screen.tscn",
	GameState.SHOP: "res://scenes/shop/shop_screen.tscn",
	GameState.REST: "res://scenes/rest/rest_screen.tscn",
	GameState.GAME_OVER: "res://scenes/main/game_over.tscn",
}

var current_state: GameState = GameState.TITLE
var current_character: CharacterData
var current_act: int = 1
var current_node_index: int = -1
var total_nodes_visited: int = 0
var distance_km: int = 0
var event_flags: Dictionary = {}
var map_nodes: Array[Dictionary] = []
var map_current_row: int = -1
var map_current_node_id: String = ""
var pending_combat_node_type: int = -1
var pending_combat_enemy_ids: Array[StringName] = []
var pending_combat_boss_hp_scale: float = 1.0
var boss_cleared: bool = false
var pending_result: StringName = &"defeat"
var current_companion: CompanionData = null
var companion_nodes_remaining: int = 0
var companion_hp: int = 0
var companion_is_settled: bool = false
var companion_bond: int = 0
var companion_pending_offer: bool = false
var secondary_companion: CompanionData = null
var secondary_companion_nodes_remaining: int = 0
var secondary_companion_hp: int = 0
var secondary_companion_is_settled: bool = false
var secondary_companion_bond: int = 0
var secondary_companion_pending_offer: bool = false
var pending_bond_slot: int = -1
var pursuit_level: int = 0
var pursuit_triggered: bool = false
var oasis_info: Dictionary = {}
var faith: int = 80
var recent_companion_event: StringName = &""
var recent_companion_id: StringName = &""
var recent_companion_type: CompanionData.CompanionType = CompanionData.CompanionType.FIGHTER
var companion_notifications: Array[String] = []

# 絆1につき定着打診確率に加算される%。絆は道中の絆イベントで最大 BOND_MAX まで上がる。
const BOND_SETTLE_BONUS := 15
const BOND_MAX := 3
const BOND_EVENT_CHANCE := 0.25
const BOND_EVENT_FUEL_COST := 1

# 希望提示のタイプ既定台詞。CompanionData.request_line が空の場合に使う。
const REQUEST_LINE_DEFAULTS := {
	CompanionData.CompanionType.FIGHTER: "道中の護衛は請け負う。しばらく東へ走ってくれ",
	CompanionData.CompanionType.TECHNICIAN: "距離を稼ぎたい。追いつかれる前に、できるだけ遠くまで",
	CompanionData.CompanionType.MERCHANT: "市の立つ場所まで乗せてくれ。悪いようにはしない",
	CompanionData.CompanionType.INFORMANT: "届けたいものがある。人の集まる場所まで頼む",
	CompanionData.CompanionType.REFUGEE: "……安全な集落まで、連れて行ってもらえませんか",
	CompanionData.CompanionType.TRAITOR: "なに、少し先まででいい。気のいい旅の連れってやつさ",
	CompanionData.CompanionType.LOVE_SLAVE: "ね、もう少しだけ一緒にいたい",
}

const SETTLE_OFFER_DEFAULT := "よければ、この先も乗せていってくれないか"

# 絆イベントのタイプ別テキスト。%s は display_name。
const BOND_EVENT_TEXTS := {
	CompanionData.CompanionType.FIGHTER: "野営の火の横で、%sが銃の手入れをしながら昔の戦場の話を始めた。",
	CompanionData.CompanionType.TECHNICIAN: "%sがエンジンの異音に気づいた。「見せてみな」と、もう工具を出している。",
	CompanionData.CompanionType.MERCHANT: "%sが戦前のコーヒー豆を取り出した。「特別だぞ」と火にかける気でいる。",
	CompanionData.CompanionType.INFORMANT: "%sが地図の端を指でなぞっている。「ここだけの話、聞くか？」",
	CompanionData.CompanionType.REFUGEE: "子供が%sの膝で眠っている。母親が、礼を言いたそうにこちらを見た。",
	CompanionData.CompanionType.LOVE_SLAVE: "%sが背中に体を預けてきた。風の音に混じって、小さな鼻歌が聞こえる。",
}

# 定着同行者エンディング余韻のタイプ既定文。CompanionData.ending_fragment が空の場合に使う。
const ENDING_FRAGMENT_DEFAULTS := {
	CompanionData.CompanionType.FIGHTER: "「次はどこへ行く」と%sが聞く。護衛代の話は、もうしなくなった。",
	CompanionData.CompanionType.TECHNICIAN: "エンジンはもう妙な音を立てない。%sが毎晩どこかを締め直しているからだ。",
	CompanionData.CompanionType.MERCHANT: "%sはオアシスの水に早くも値段をつけている。それでも降ろす気は起きない。",
	CompanionData.CompanionType.INFORMANT: "%sが新しい噂を仕入れてくる。行き先のない旅の、次の行き先を。",
	CompanionData.CompanionType.REFUGEE: "子供が砂の上に絵を描いている。バイクと、寄り添う人影を。",
	CompanionData.CompanionType.DOG: "%sが水面に向かって吠えている。尻尾は正直だ。",
	CompanionData.CompanionType.LOVE_SLAVE: "%sは今朝も隣で眠っている。約束の期限は、とうに数えなくなった。",
}

const OASIS_CATEGORIES := [&"location", &"danger", &"resource", &"truth"]
const OASIS_INFO_TEXTS := {
	&"location": [
		"「東の果てに水の湧く地がある」",
		"「岩山の向こう、枯れ川の先だ」",
		"「最後の丘を越えれば見える」",
	],
	&"danger": [
		"「オアシスには番人がいる」",
		"「武装した集団が周囲を巡回している」",
		"「油断した者は二度と戻れない」",
	],
	&"resource": [
		"「水だけでなく、旧世界の技術が眠るらしい」",
		"「燃料精製施設があると聞いた」",
		"「医薬品の原料も豊富だそうだ」",
	],
	&"truth": [
		"「本当にオアシスは楽園なのか？」",
		"「オアシスを支配する者がいるらしい」",
		"「辿り着いた者は、そこを離れられなくなるという」",
	],
}

func start_run(character: CharacterData) -> void:
	current_character = character
	current_act = 1
	current_node_index = -1
	total_nodes_visited = 0
	distance_km = 0
	event_flags.clear()
	QuestManager.reset()
	map_nodes.clear()
	map_current_row = -1
	map_current_node_id = ""
	clear_pending_combat()
	boss_cleared = false
	pending_result = &"defeat"
	current_companion = null
	companion_nodes_remaining = 0
	companion_hp = 0
	companion_is_settled = false
	companion_bond = 0
	companion_pending_offer = false
	secondary_companion = null
	secondary_companion_nodes_remaining = 0
	secondary_companion_hp = 0
	secondary_companion_is_settled = false
	secondary_companion_bond = 0
	secondary_companion_pending_offer = false
	pending_bond_slot = -1
	pursuit_level = 0
	pursuit_triggered = false
	oasis_info.clear()
	faith = 80
	companion_notifications.clear()
	clear_recent_companion_event()
	ResourceManager.reset()
	ItemDatabase.reset()
	DeckManager.build_starter_deck(character)
	KarmaManager.reset()
	CombatManager.reset_player_for_new_run()
	run_started.emit(character)
	change_state(GameState.MAP)

func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(GameState.keys()[new_state])

func set_pending_combat(node_type: int, enemy_list: Array[EnemyData], boss_hp_scale: float = 1.0) -> void:
	pending_combat_node_type = node_type
	pending_combat_enemy_ids.clear()
	for enemy: EnemyData in enemy_list:
		if enemy != null:
			pending_combat_enemy_ids.append(enemy.id)
	pending_combat_boss_hp_scale = boss_hp_scale

func clear_pending_combat() -> void:
	pending_combat_node_type = -1
	pending_combat_enemy_ids.clear()
	pending_combat_boss_hp_scale = 1.0

func go_to_state(new_state: GameState) -> void:
	var scene_path: String = String(SCENE_PATHS.get(new_state, ""))
	if scene_path.is_empty():
		change_state(new_state)
		return
	get_tree().change_scene_to_file(scene_path)
	change_state(new_state)

func get_travel_resource_name() -> String:
	if current_character != null and current_character.id == &"conqueror":
		return "水"
	return "燃料"

func get_travel_resource_icon() -> String:
	if current_character != null and current_character.id == &"conqueror":
		return "💧"
	return "⛽"

func advance_node(travel_cost: int = 2) -> void:
	current_node_index += 1
	total_nodes_visited += 1
	distance_km += randi_range(3, 6) + travel_cost
	if current_character != null and current_character.id != &"conqueror":
		var tech_immune: bool = has_companion_type(CompanionData.CompanionType.TECHNICIAN)
		if not tech_immune:
			ResourceManager.damage_bike(1)
			if ResourceManager.bike_durability <= 0:
				ResourceManager.consume_fuel(2)
	_apply_companion_node_effects()
	_check_escort_arrivals()
	_tick_companion()
	_maybe_trigger_bond_event()
	_tick_pursuit()
	QuestManager.on_node_advanced()

func recruit_companion(companion: CompanionData) -> bool:
	var block_reason: String = get_companion_recruit_block_reason(companion)
	if not block_reason.is_empty():
		_queue_companion_notification("%sは同行を拒んだ。\n%s" % [companion.display_name, block_reason])
		return false
	var slot: int = _first_available_companion_slot()
	if slot == -1:
		slot = 0
		dismiss_companion_slot(0)
	elif slot == 1:
		_queue_companion_notification("%sがサイドカーに乗った。" % companion.display_name)
	else:
		_queue_companion_notification("%sが同行者になった。" % companion.display_name)
	_assign_companion_to_slot(slot, companion)
	_add_companion_cards(companion)
	_queue_request_notification(slot)
	_set_recent_companion_event(&"recruited", companion)
	_mark_unique_companion_joined(companion)
	return true

# 加入直後に同行者の「希望」を通知する。希望なし（犬・専用PCのユニーク等）は何も出さない。
func _queue_request_notification(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	if _effective_request_type(companion) == CompanionData.RequestType.NONE:
		return
	var line: String = companion.request_line
	if line.is_empty():
		line = String(REQUEST_LINE_DEFAULTS.get(companion.companion_type, "しばらく乗せてくれ"))
	_queue_companion_notification("%s「%s」\n（希望: %s）" % [
		companion.display_name, line, get_companion_request_display(slot)])

func can_recruit_companion(companion: CompanionData) -> bool:
	return get_companion_recruit_block_reason(companion).is_empty()

func get_companion_recruit_block_reason(companion: CompanionData) -> String:
	if companion == null:
		return "同行者データが見つからない。"
	if is_companion_active(companion.id):
		return "すでに同行している。"
	if not companion.allowed_character_ids.is_empty():
		var current_id: StringName = current_character.id if current_character != null else &""
		if current_id not in companion.allowed_character_ids:
			return "このキャラクターでは同行できない。"
	if KarmaManager.karma < companion.required_karma_min:
		return "カルマが低すぎる。"
	if KarmaManager.karma > companion.required_karma_max:
		return "カルマが高すぎる。"
	return ""

func dismiss_companion() -> void:
	dismiss_companion_slot(0)
	dismiss_companion_slot(1)

# 同行者を任意に下ろす。希望を果たしていない相手を降ろすと「見捨てた」扱いで
# 失敗ペナルティが発生する。定着済み・希望なしの相手はいつでも円満に降ろせる。
func dismiss_companion_slot(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	if _has_active_request(slot):
		_on_request_failed(slot, true)
		return
	_set_recent_companion_event(&"dismissed", companion)
	_queue_companion_notification("%sと別れた。" % companion.display_name)
	_remove_companion_cards(companion)
	_clear_companion_slot(slot)

func has_active_request(slot: int) -> bool:
	return _has_active_request(slot)

# 希望が進行中（未達成・未定着・打診待ちでない）かどうか。
func _has_active_request(slot: int) -> bool:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return false
	if _is_companion_settled(slot) or _is_companion_pending_offer(slot):
		return false
	return _effective_request_type(companion) != CompanionData.RequestType.NONE

# 専用PCと同行中のユニーク同行者は希望を出さず無期限に同行する（物語同行者）。
func _effective_request_type(companion: CompanionData) -> CompanionData.RequestType:
	if companion.is_unique and companion.dedicated_character_id != &"":
		var current_id: StringName = current_character.id if current_character != null else &""
		if companion.dedicated_character_id == current_id:
			return CompanionData.RequestType.NONE
	return companion.request_type

func _tick_companion() -> void:
	_tick_companion_slot(0)
	_tick_companion_slot(1)

func _tick_companion_slot(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	if not _has_active_request(slot):
		return
	var remaining: int = get_companion_nodes_remaining(slot) - 1
	_set_companion_nodes_remaining(slot, remaining)
	if remaining > 0:
		return
	if _effective_request_type(companion) == CompanionData.RequestType.TRAVEL:
		_on_request_fulfilled(slot)
	else:
		_on_request_failed(slot, false)

# ESCORT希望の到着判定。現在ノードの施設種別が目的地に含まれていれば達成。
func _check_escort_arrivals() -> void:
	var site: int = _get_current_node_site()
	if site < 0:
		return
	for slot: int in range(2):
		var companion: CompanionData = get_companion_in_slot(slot)
		if companion == null or not _has_active_request(slot):
			continue
		if _effective_request_type(companion) != CompanionData.RequestType.ESCORT:
			continue
		if site in companion.request_site_types:
			_on_request_fulfilled(slot)

func _get_current_node_site() -> int:
	if map_current_node_id.is_empty():
		return -1
	for node: Dictionary in map_nodes:
		var nid: String = "%d_%d" % [int(node["row"]), int(node["col"])]
		if nid == map_current_node_id:
			return int(node.get("site", -1))
	return -1

func _apply_companion_node_effects() -> void:
	if current_character == null:
		return
	if current_character.unique_system != &"euphoria":
		return
	var euphoria_gain: int = 0
	for companion: CompanionData in get_active_companions():
		euphoria_gain += companion.euphoria_per_node
	if euphoria_gain == 0:
		return
	CombatManager.player_euphoria = clampi(
		CombatManager.player_euphoria + euphoria_gain,
		0,
		CombatManager.EUPHORIA_MAX
	)
	CombatManager.euphoria_changed.emit(CombatManager.player_euphoria, CombatManager.EUPHORIA_MAX)

# 希望達成。報酬を渡し、条件が揃えば永続同行の打診を保留状態にする。
# 打診が発生しない場合は礼を言って去る。
func _on_request_fulfilled(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	var reward_text: String = _grant_request_reward(companion)
	if companion.companion_type == CompanionData.CompanionType.TRAITOR:
		# 裏切り者の「希望達成」は窃盗と逃亡。打診は発生しない。
		_depart_after_request(slot, reward_text)
		return
	if reward_text.is_empty():
		_queue_companion_notification("%sの頼みを果たした。" % companion.display_name)
	else:
		_queue_companion_notification("%sの頼みを果たした。\n%s" % [companion.display_name, reward_text])
	var chance: int = companion.settle_chance_percent + get_companion_bond(slot) * BOND_SETTLE_BONUS
	if not has_settled_companion() and chance > 0 and randi_range(1, 100) <= chance:
		_set_companion_pending_offer(slot, true)
		_set_companion_nodes_remaining(slot, 0)
		return
	_depart_after_request(slot, "")

func _depart_after_request(slot: int, extra_text: String) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	_remove_companion_cards(companion)
	_clear_companion_slot(slot)
	_set_recent_companion_event(&"departed", companion)
	if extra_text.is_empty():
		_queue_companion_notification("%sは礼を言って去った。" % companion.display_name)
	else:
		_queue_companion_notification("%sが去っていった。\n%s" % [companion.display_name, extra_text])

# 希望の失敗。期限切れ（abandoned=false）または途中で降ろした（abandoned=true）。
# カルマ・燃料・追跡のペナルティはデータ駆動（CompanionData.fail_*_penalty）。
func _on_request_failed(slot: int, abandoned: bool) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	var penalty_parts: Array[String] = []
	if companion.fail_karma_penalty != 0:
		KarmaManager.add_karma(companion.fail_karma_penalty)
		penalty_parts.append("カルマ %d" % companion.fail_karma_penalty)
	if companion.fail_fuel_penalty > 0:
		var lost: int = mini(companion.fail_fuel_penalty, ResourceManager.fuel)
		if lost > 0:
			ResourceManager.consume_fuel(lost)
			penalty_parts.append("%s -%d" % [get_travel_resource_name(), lost])
	if companion.fail_pursuit_penalty > 0:
		pursuit_level = clampi(pursuit_level + companion.fail_pursuit_penalty, 0, 100)
		penalty_parts.append("追跡 +%d%%" % companion.fail_pursuit_penalty)
	_remove_companion_cards(companion)
	_clear_companion_slot(slot)
	_set_recent_companion_event(&"departed", companion)
	var head: String = ""
	if abandoned:
		head = "%sを頼みも果たさず降ろした。" % companion.display_name
	else:
		head = "%sは待ちきれずに降りていった。" % companion.display_name
	if penalty_parts.is_empty():
		_queue_companion_notification(head)
	else:
		_queue_companion_notification("%s\n%s" % [head, "、".join(penalty_parts)])

# 希望達成報酬。タイプ別（裏切り者は窃盗）。
func _grant_request_reward(companion: CompanionData) -> String:
	match companion.companion_type:
		CompanionData.CompanionType.TRAITOR:
			var stolen_fuel: int = mini(5, ResourceManager.fuel)
			var stolen_scrap: int = mini(3, ResourceManager.scrap)
			ResourceManager.consume_fuel(stolen_fuel)
			ResourceManager.consume_scrap(stolen_scrap)
			return "燃料%d、スクラップ%dを持ち去られた。" % [stolen_fuel, stolen_scrap]
		CompanionData.CompanionType.MERCHANT:
			ResourceManager.add_fuel(8)
			return "%s +8" % get_travel_resource_name()
		CompanionData.CompanionType.FIGHTER:
			var card: CardData = _add_departure_card(CardData.Rarity.UNCOMMON)
			if card != null:
				return "カード「%s」を受け取った。" % card.get_display_name()
		CompanionData.CompanionType.REFUGEE:
			KarmaManager.add_karma(15)
			return "カルマ +15"
		CompanionData.CompanionType.TECHNICIAN:
			var part: BikePartData = _equip_departure_part(BikePartData.PartRarity.UPPER)
			if part != null:
				return "バイクパーツ「%s」を装着した。" % part.display_name
		CompanionData.CompanionType.INFORMANT:
			return advance_oasis_info()
		CompanionData.CompanionType.DOG:
			KarmaManager.add_karma(3)
			return "カルマ +3"
	return ""

# --- 永続同行（定着）打診 ---

func get_pending_offer_slot() -> int:
	for slot: int in range(2):
		if get_companion_in_slot(slot) != null and _is_companion_pending_offer(slot):
			return slot
	return -1

func get_settle_offer_text(slot: int) -> String:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return ""
	var line: String = companion.settle_offer_line
	if line.is_empty():
		line = SETTLE_OFFER_DEFAULT
	return "%s「%s」" % [companion.display_name, line]

func accept_settle_offer(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	_set_companion_pending_offer(slot, false)
	_set_companion_settled(slot, true)
	_set_companion_nodes_remaining(slot, -1)
	_set_recent_companion_event(&"settled", companion)
	_queue_companion_notification("%sは永続同行者になった。\nいつでも降ろすことができる。" % companion.display_name)
	# 永続同行者は1人まで。もう片方の打診待ちは同時に解消する。
	var other: int = 1 - slot
	if get_companion_in_slot(other) != null and _is_companion_pending_offer(other):
		decline_settle_offer(other)

func decline_settle_offer(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	_set_companion_pending_offer(slot, false)
	_remove_companion_cards(companion)
	_clear_companion_slot(slot)
	_set_recent_companion_event(&"departed", companion)
	_queue_companion_notification("%sはうなずき、荷物をまとめて去った。" % companion.display_name)

func has_settled_companion() -> bool:
	for slot: int in range(2):
		if get_companion_in_slot(slot) != null and _is_companion_settled(slot):
			return true
	return false

# --- 絆イベント ---

# 希望進行中の同行者と過ごす小さな場面を確率で発生させる。
# 肯定的な選択で絆+1（定着打診確率+15%）。マップ画面が pending_bond_slot を消費して表示する。
func _maybe_trigger_bond_event() -> void:
	if pending_bond_slot != -1:
		return
	var eligible: Array[int] = []
	for slot: int in range(2):
		var companion: CompanionData = get_companion_in_slot(slot)
		if companion == null or not _has_active_request(slot):
			continue
		if companion.settle_chance_percent <= 0:
			continue
		if get_companion_bond(slot) >= BOND_MAX:
			continue
		if get_companion_nodes_remaining(slot) <= 1:
			continue
		eligible.append(slot)
	if eligible.is_empty():
		return
	if randf() >= BOND_EVENT_CHANCE:
		return
	pending_bond_slot = eligible[randi() % eligible.size()]

func get_bond_event_text(slot: int) -> String:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return ""
	var template: String = String(BOND_EVENT_TEXTS.get(
		companion.companion_type, "%sが焚火の向こうからこちらを見ている。"))
	return template % companion.display_name

# 絆イベントの解決。positive なら燃料を消費して絆+1。
func resolve_bond_event(slot: int, positive: bool) -> void:
	pending_bond_slot = -1
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null or not positive:
		return
	if not ResourceManager.consume_fuel(BOND_EVENT_FUEL_COST):
		return
	_set_companion_bond(slot, mini(get_companion_bond(slot) + 1, BOND_MAX))
	_queue_companion_notification("%sとの距離が少し縮まった。" % companion.display_name)

func damage_current_companion(amount: int) -> void:
	for slot: int in range(2):
		var companion: CompanionData = get_companion_in_slot(slot)
		if companion != null and companion.max_hp > 0:
			_damage_companion_slot(slot, amount)
			return

func _damage_companion_slot(slot: int, amount: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	if companion.max_hp <= 0:
		return
	var hp: int = maxi(0, get_companion_hp(slot) - amount)
	_set_companion_hp(slot, hp)
	if hp <= 0:
		_on_companion_death(slot)

func _on_companion_death(slot: int = 0) -> void:
	var dead_companion: CompanionData = get_companion_in_slot(slot)
	if dead_companion == null:
		return
	_remove_companion_cards(dead_companion)
	_clear_companion_slot(slot)
	_set_recent_companion_event(&"dead", dead_companion)
	if dead_companion.death_karma_penalty != 0:
		KarmaManager.add_karma(dead_companion.death_karma_penalty)
	_queue_companion_notification("%sを守れなかった。\nカルマ %d" % [dead_companion.display_name, dead_companion.death_karma_penalty])

func get_companion_extra_travel_cost() -> int:
	var total: int = 0
	for companion: CompanionData in get_active_companions():
		total += maxi(0, companion.extra_travel_cost)
	if has_second_companion():
		total += 1
	return total

func get_info_node_bonus_count() -> int:
	var total: int = 0
	for companion: CompanionData in get_active_companions():
		total += maxi(0, companion.info_node_bonus)
	return total

func get_rest_heal_percent(base_percent: int) -> int:
	var total: int = base_percent
	for companion: CompanionData in get_active_companions():
		if companion.rest_heal_bonus_percent > 0:
			total += int(float(base_percent) * float(companion.rest_heal_bonus_percent) / 100.0)
	return total

func consume_companion_sleep_turn_for_combat() -> bool:
	var sleep_triggered: bool = false
	for companion: CompanionData in get_active_companions():
		if companion.sleep_interval_combats <= 0:
			continue
		var flag_key: StringName = _companion_sleep_counter_flag(companion.id)
		var count: int = int(event_flags.get(flag_key, 0)) + 1
		if count >= companion.sleep_interval_combats:
			event_flags[flag_key] = 0
			sleep_triggered = true
		else:
			event_flags[flag_key] = count
	return sleep_triggered

func get_companion_remaining_display(slot: int = 0) -> String:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return ""
	if _is_companion_settled(slot):
		return "永続"
	if _is_companion_pending_offer(slot):
		return "返事待ち"
	match _effective_request_type(companion):
		CompanionData.RequestType.NONE:
			return "無期限"
		CompanionData.RequestType.TRAVEL:
			return "同行あと%d" % get_companion_nodes_remaining(slot)
		CompanionData.RequestType.ESCORT:
			return "%sへ 期限%d" % [_request_site_names(companion), get_companion_nodes_remaining(slot)]
	return ""

# 希望の内容説明（加入通知・ツールチップ用）。
func get_companion_request_display(slot: int) -> String:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return ""
	match _effective_request_type(companion):
		CompanionData.RequestType.TRAVEL:
			return "あと%dノード同行する" % get_companion_nodes_remaining(slot)
		CompanionData.RequestType.ESCORT:
			return "%sまで送り届ける（期限%dノード）" % [
				_request_site_names(companion), get_companion_nodes_remaining(slot)]
	return "なし"

func _request_site_names(companion: CompanionData) -> String:
	var names: Array[String] = []
	for site: int in companion.request_site_types:
		names.append(MapGenerator.get_site_name(site))
	if names.is_empty():
		return "目的地"
	return "/".join(names)

func get_max_companions() -> int:
	if ItemDatabase.has_relic(SIDECAR_RELIC_ID):
		return 2
	return 1

func has_any_companion() -> bool:
	return current_companion != null or secondary_companion != null

func has_second_companion() -> bool:
	return current_companion != null and secondary_companion != null

func has_human_companion() -> bool:
	for companion: CompanionData in get_active_companions():
		if companion.companion_type != CompanionData.CompanionType.DOG:
			return true
	return false

func has_companion_type(companion_type: CompanionData.CompanionType) -> bool:
	for companion: CompanionData in get_active_companions():
		if companion.companion_type == companion_type:
			return true
	return false

func is_companion_active(companion_id: StringName) -> bool:
	for companion: CompanionData in get_active_companions():
		if companion.id == companion_id:
			return true
	return false

func get_active_companions() -> Array[CompanionData]:
	var companions: Array[CompanionData] = []
	if current_companion != null:
		companions.append(current_companion)
	if secondary_companion != null:
		companions.append(secondary_companion)
	return companions

func get_companion_in_slot(slot: int) -> CompanionData:
	if slot == 1:
		return secondary_companion
	return current_companion

func get_companion_nodes_remaining(slot: int) -> int:
	if slot == 1:
		return secondary_companion_nodes_remaining
	return companion_nodes_remaining

func get_companion_hp(slot: int) -> int:
	if slot == 1:
		return secondary_companion_hp
	return companion_hp

func _first_available_companion_slot() -> int:
	if current_companion == null:
		return 0
	if get_max_companions() >= 2 and secondary_companion == null:
		return 1
	return -1

func _assign_companion_to_slot(slot: int, companion: CompanionData) -> void:
	if slot == 1:
		secondary_companion = companion
		secondary_companion_is_settled = false
		secondary_companion_pending_offer = false
		secondary_companion_bond = 0
		secondary_companion_hp = companion.max_hp
		secondary_companion_nodes_remaining = _roll_request_nodes(companion)
	else:
		current_companion = companion
		companion_is_settled = false
		companion_pending_offer = false
		companion_bond = 0
		companion_hp = companion.max_hp
		companion_nodes_remaining = _roll_request_nodes(companion)

# 希望のノード数（TRAVEL=同行数 / ESCORT=期限）をロールする。希望なしは-1（無期限）。
func _roll_request_nodes(companion: CompanionData) -> int:
	if _effective_request_type(companion) == CompanionData.RequestType.NONE:
		return -1
	var lo: int = maxi(1, companion.request_nodes_min)
	var hi: int = maxi(lo, companion.request_nodes_max)
	return randi_range(lo, hi)

func _clear_companion_slot(slot: int) -> void:
	if slot == 1:
		secondary_companion = null
		secondary_companion_nodes_remaining = 0
		secondary_companion_hp = 0
		secondary_companion_is_settled = false
		secondary_companion_bond = 0
		secondary_companion_pending_offer = false
	else:
		current_companion = null
		companion_nodes_remaining = 0
		companion_hp = 0
		companion_is_settled = false
		companion_bond = 0
		companion_pending_offer = false
	if pending_bond_slot == slot:
		pending_bond_slot = -1

func _set_companion_nodes_remaining(slot: int, value: int) -> void:
	if slot == 1:
		secondary_companion_nodes_remaining = value
	else:
		companion_nodes_remaining = value

func _set_companion_hp(slot: int, value: int) -> void:
	if slot == 1:
		secondary_companion_hp = value
	else:
		companion_hp = value

func _is_companion_settled(slot: int) -> bool:
	if slot == 1:
		return secondary_companion_is_settled
	return companion_is_settled

func _set_companion_settled(slot: int, value: bool) -> void:
	if slot == 1:
		secondary_companion_is_settled = value
	else:
		companion_is_settled = value

func _is_companion_pending_offer(slot: int) -> bool:
	if slot == 1:
		return secondary_companion_pending_offer
	return companion_pending_offer

func _set_companion_pending_offer(slot: int, value: bool) -> void:
	if slot == 1:
		secondary_companion_pending_offer = value
	else:
		companion_pending_offer = value

func get_companion_bond(slot: int) -> int:
	if slot == 1:
		return secondary_companion_bond
	return companion_bond

func _set_companion_bond(slot: int, value: int) -> void:
	if slot == 1:
		secondary_companion_bond = value
	else:
		companion_bond = value

# エンディング（勝利）の余韻に差し込む同行者テキスト。
# 定着・無期限同行者は「まだ乗っている」定型＋個別断片（ending_fragment、
# 空ならタイプ既定文）。希望進行中のまま到達した相手は別れの定型のみ。
# 汎用定型＋断片差し替えでテキスト量の爆発を防ぐ（→ gdd-narrative §6）。
func get_companion_ending_epilogues() -> Array[String]:
	var epilogues: Array[String] = []
	for slot: int in range(2):
		var companion: CompanionData = get_companion_in_slot(slot)
		if companion == null:
			continue
		var stays: bool = _is_companion_settled(slot) \
			or _effective_request_type(companion) == CompanionData.RequestType.NONE
		if not stays:
			epilogues.append("%sとはオアシスの入口で別れた。荷台の重さが、少しだけ懐かしい。" % companion.display_name)
			continue
		var fragment: String = companion.ending_fragment
		if fragment.is_empty():
			var template: String = String(ENDING_FRAGMENT_DEFAULTS.get(companion.companion_type, ""))
			if template.contains("%s"):
				fragment = template % companion.display_name
			else:
				fragment = template
		var line: String = "%sはまだサイドカーに乗っている。" % companion.display_name
		if not fragment.is_empty():
			line += "\n" + fragment
		epilogues.append(line)
	return epilogues

func _set_recent_companion_event(event_id: StringName, companion: CompanionData) -> void:
	recent_companion_event = event_id
	recent_companion_id = companion.id
	recent_companion_type = companion.companion_type

func _mark_unique_companion_joined(companion: CompanionData) -> void:
	if not companion.is_unique:
		return
	event_flags[StringName("unique_%s_joined" % companion.id)] = true
	var current_id: StringName = current_character.id if current_character != null else &""
	if companion.dedicated_character_id != &"" and companion.dedicated_character_id == current_id:
		event_flags[StringName("unique_%s_dedicated_joined" % companion.id)] = true

func _companion_sleep_counter_flag(companion_id: StringName) -> StringName:
	return StringName("companion_%s_sleep_counter" % companion_id)

func clear_recent_companion_event() -> void:
	recent_companion_event = &""
	recent_companion_id = &""
	recent_companion_type = CompanionData.CompanionType.FIGHTER

func consume_companion_notifications() -> Array[String]:
	var messages: Array[String] = companion_notifications.duplicate()
	companion_notifications.clear()
	return messages

func _queue_companion_notification(message: String) -> void:
	if message.is_empty():
		return
	companion_notifications.append(message)
	companion_notification_queued.emit(message)

func _add_companion_cards(companion: CompanionData) -> void:
	for card_id: StringName in companion.deck_card_ids:
		var _added: bool = DeckManager.add_card_id_to_deck(card_id)

func _remove_companion_cards(companion: CompanionData) -> void:
	DeckManager.remove_cards_by_ids(companion.deck_card_ids)

func _add_departure_card(rarity: CardData.Rarity) -> CardData:
	var pool: Array[CardData] = CardDatabase.get_reward_pool(current_act, current_character.id)
	var candidates: Array[CardData] = []
	for card: CardData in pool:
		if card.rarity == rarity:
			candidates.append(card)
	if candidates.is_empty():
		candidates = pool
	if candidates.is_empty():
		return null
	candidates.shuffle()
	DeckManager.add_card_to_deck(candidates[0])
	return candidates[0]

func _equip_departure_part(rarity: BikePartData.PartRarity) -> BikePartData:
	var candidates: Array[BikePartData] = BikePartsDatabase.get_parts_by_rarity(rarity)
	if candidates.is_empty():
		candidates = BikePartsDatabase.get_parts_by_rarity(BikePartData.PartRarity.NORMAL)
	if candidates.is_empty():
		return null
	candidates.shuffle()
	var _old_part: BikePartData = ResourceManager.equip_part(candidates[0])
	return candidates[0]

func add_faith(amount: int) -> void:
	faith = clampi(faith + amount, 0, 100)

func get_faith_band() -> StringName:
	if faith >= 80:
		return &"zealot"
	elif faith >= 50:
		return &"devout"
	elif faith >= 20:
		return &"doubting"
	else:
		return &"apostate"

func get_faith_display() -> String:
	match get_faith_band():
		&"zealot": return "狂信(%d)" % faith
		&"devout": return "敬虔(%d)" % faith
		&"doubting": return "懐疑(%d)" % faith
		&"apostate": return "背教(%d)" % faith
	return "%d" % faith

func is_cultist() -> bool:
	if current_character == null:
		return false
	return current_character.unique_system == &"gear"

func advance_oasis_info() -> String:
	var available: Array[StringName] = []
	for cat: StringName in OASIS_CATEGORIES:
		var stage: int = int(oasis_info.get(cat, 0))
		var texts: Array = OASIS_INFO_TEXTS.get(cat, [])
		if stage < texts.size():
			available.append(cat)
	if available.is_empty():
		return "これ以上の情報は得られなかった。"
	var chosen: StringName = available[randi() % available.size()]
	var stage: int = int(oasis_info.get(chosen, 0))
	var texts: Array = OASIS_INFO_TEXTS.get(chosen, [])
	var text: String = texts[stage]
	oasis_info[chosen] = stage + 1
	return text

func get_oasis_info_count() -> int:
	var total: int = 0
	for cat: StringName in OASIS_CATEGORIES:
		total += int(oasis_info.get(cat, 0))
	return total

func _tick_pursuit() -> void:
	var gain: int = 0
	if current_character != null and current_character.unique_system == &"heat":
		gain = randi_range(5, 10)
		if has_companion_type(CompanionData.CompanionType.INFORMANT):
			gain = maxi(1, gain - 3)
	for companion: CompanionData in get_active_companions():
		gain += companion.pursuit_gain_per_node
	if gain == 0:
		return
	pursuit_level = clampi(pursuit_level + gain, 0, 100)
	if gain > 0 and pursuit_level >= 100:
		pursuit_triggered = true
		pursuit_level = clampi(pursuit_level - 40, 0, 100)

func advance_act() -> void:
	if current_act < MAX_ACT:
		CombatManager.player_hp = CombatManager.player_max_hp
		CombatManager.player_hp_changed.emit(CombatManager.player_hp, CombatManager.player_max_hp)
		_upgrade_random_card_after_boss()
	current_act += 1
	current_node_index = -1
	map_nodes.clear()
	map_current_row = -1
	map_current_node_id = ""
	clear_pending_combat()

func _upgrade_random_card_after_boss() -> void:
	var upgradeable: Array[CardData] = []
	for card: CardData in DeckManager.master_deck:
		if not card.upgraded:
			upgradeable.append(card)
	if upgradeable.is_empty():
		return
	var card: CardData = upgradeable[randi() % upgradeable.size()]
	card.upgraded = true

func end_run(result: StringName) -> void:
	MetaProgression.add_distance(distance_km)
	if result == &"victory":
		MetaProgression.mark_cleared(current_character.id)
	SaveManager.delete_save()
	run_ended.emit(result, distance_km)
	change_state(GameState.RESULT)

func go_to_title() -> void:
	go_to_state(GameState.TITLE)
