extends Node

signal state_changed(new_state: StringName)
signal run_started(character: CharacterData)
signal run_ended(result: StringName, distance: int)
signal companion_notification_queued(message: String)

enum GameState { TITLE, CHARACTER_SELECT, MAP, COMBAT, EVENT, SHOP, REST, GAME_OVER, RESULT }

const MAX_ACT := 5
const SIDECAR_RELIC_ID := &"sidecar"

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
var boss_cleared: bool = false
var pending_result: StringName = &"defeat"
var current_companion: CompanionData = null
var companion_nodes_remaining: int = 0
var companion_hp: int = 0
var companion_is_settled: bool = false
var secondary_companion: CompanionData = null
var secondary_companion_nodes_remaining: int = 0
var secondary_companion_hp: int = 0
var secondary_companion_is_settled: bool = false
var pursuit_level: int = 0
var pursuit_triggered: bool = false
var oasis_info: Dictionary = {}
var faith: int = 80
var recent_companion_event: StringName = &""
var recent_companion_id: StringName = &""
var recent_companion_type: CompanionData.CompanionType = CompanionData.CompanionType.FIGHTER
var companion_notifications: Array[String] = []

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
	boss_cleared = false
	pending_result = &"defeat"
	current_companion = null
	companion_nodes_remaining = 0
	companion_hp = 0
	companion_is_settled = false
	secondary_companion = null
	secondary_companion_nodes_remaining = 0
	secondary_companion_hp = 0
	secondary_companion_is_settled = false
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
	_tick_companion()
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
		_queue_companion_notification("%sと別れ、%sを同行者にした。" % [current_companion.display_name, companion.display_name])
		_remove_companion_cards(current_companion)
		_clear_companion_slot(0)
	elif slot == 1:
		_queue_companion_notification("%sがサイドカーに乗った。" % companion.display_name)
	else:
		_queue_companion_notification("%sが同行者になった。" % companion.display_name)
	_assign_companion_to_slot(slot, companion)
	_add_companion_cards(companion)
	_set_recent_companion_event(&"recruited", companion)
	_mark_unique_companion_joined(companion)
	return true

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
	if current_companion != null:
		_set_recent_companion_event(&"dismissed", current_companion)
		_queue_companion_notification("%sと別れた。" % current_companion.display_name)
		_remove_companion_cards(current_companion)
	if secondary_companion != null:
		_set_recent_companion_event(&"dismissed", secondary_companion)
		_queue_companion_notification("%sと別れた。" % secondary_companion.display_name)
		_remove_companion_cards(secondary_companion)
	_clear_companion_slot(0)
	_clear_companion_slot(1)

func _tick_companion() -> void:
	_tick_companion_slot(0)
	_tick_companion_slot(1)

func _tick_companion_slot(slot: int) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	if _is_companion_settled(slot) or companion.duration_nodes < 0:
		return
	var remaining: int = get_companion_nodes_remaining(slot) - 1
	_set_companion_nodes_remaining(slot, remaining)
	if remaining <= 0:
		_on_companion_depart(slot)

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

func _on_companion_depart(slot: int = 0) -> void:
	var companion: CompanionData = get_companion_in_slot(slot)
	if companion == null:
		return
	if companion.settle_chance_percent > 0 and randi_range(1, 100) <= companion.settle_chance_percent:
		_set_companion_settled(slot, true)
		_set_companion_nodes_remaining(slot, -1)
		_queue_companion_notification("%sは逃げなかった。\nこのランの間、同行を続ける。" % companion.display_name)
		return
	var departing_companion: CompanionData = companion
	var reward_text: String = ""
	match companion.companion_type:
		CompanionData.CompanionType.TRAITOR:
			var stolen_fuel: int = mini(5, ResourceManager.fuel)
			var stolen_scrap: int = mini(3, ResourceManager.scrap)
			ResourceManager.consume_fuel(stolen_fuel)
			ResourceManager.consume_scrap(stolen_scrap)
			reward_text = "燃料%d、スクラップ%dを持ち去られた。" % [stolen_fuel, stolen_scrap]
		CompanionData.CompanionType.MERCHANT:
			ResourceManager.add_fuel(8)
			reward_text = "%s +8" % get_travel_resource_name()
		CompanionData.CompanionType.FIGHTER:
			var card: CardData = _add_departure_card(CardData.Rarity.UNCOMMON)
			if card != null:
				reward_text = "カード「%s」を受け取った。" % card.get_display_name()
		CompanionData.CompanionType.REFUGEE:
			KarmaManager.add_karma(15)
			reward_text = "カルマ +15"
		CompanionData.CompanionType.TECHNICIAN:
			var part: BikePartData = _equip_departure_part(BikePartData.PartRarity.UPPER)
			if part != null:
				reward_text = "バイクパーツ「%s」を装着した。" % part.display_name
		CompanionData.CompanionType.INFORMANT:
			reward_text = advance_oasis_info()
		CompanionData.CompanionType.DOG:
			KarmaManager.add_karma(3)
			reward_text = "カルマ +3"
	_remove_companion_cards(companion)
	_clear_companion_slot(slot)
	_set_recent_companion_event(&"departed", departing_companion)
	if reward_text.is_empty():
		_queue_companion_notification("%sが去っていった。" % departing_companion.display_name)
	else:
		_queue_companion_notification("%sが去っていった。\n%s" % [departing_companion.display_name, reward_text])

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
		return "定着"
	if companion.duration_nodes < 0:
		return "無期限"
	return "%dノード" % get_companion_nodes_remaining(slot)

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
		secondary_companion_hp = companion.max_hp
		secondary_companion_nodes_remaining = _initial_companion_nodes(companion)
	else:
		current_companion = companion
		companion_is_settled = false
		companion_hp = companion.max_hp
		companion_nodes_remaining = _initial_companion_nodes(companion)

func _initial_companion_nodes(companion: CompanionData) -> int:
	if companion.companion_type == CompanionData.CompanionType.LOVE_SLAVE:
		return randi_range(3, 7)
	if companion.is_unique and companion.non_dedicated_duration_nodes != -999:
		var current_id: StringName = current_character.id if current_character != null else &""
		if companion.dedicated_character_id != &"" and companion.dedicated_character_id != current_id:
			return companion.non_dedicated_duration_nodes
	return companion.duration_nodes

func _clear_companion_slot(slot: int) -> void:
	if slot == 1:
		secondary_companion = null
		secondary_companion_nodes_remaining = 0
		secondary_companion_hp = 0
		secondary_companion_is_settled = false
	else:
		current_companion = null
		companion_nodes_remaining = 0
		companion_hp = 0
		companion_is_settled = false

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
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
	change_state(GameState.TITLE)
