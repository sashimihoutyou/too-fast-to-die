extends Node

signal state_changed(new_state: StringName)
signal run_started(character: CharacterData)
signal run_ended(result: StringName, distance: int)

enum GameState { TITLE, CHARACTER_SELECT, MAP, COMBAT, EVENT, SHOP, REST, GAME_OVER, RESULT }

const MAX_ACT := 5

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
var pursuit_level: int = 0
var pursuit_triggered: bool = false
var oasis_info: Dictionary = {}
var faith: int = 80

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
	pursuit_level = 0
	pursuit_triggered = false
	oasis_info.clear()
	faith = 80
	ResourceManager.reset()
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
	ResourceManager.damage_bike(1)
	if ResourceManager.bike_durability <= 0:
		ResourceManager.consume_fuel(1)
	_tick_companion()
	_tick_pursuit()
	QuestManager.on_node_advanced()

func recruit_companion(companion: CompanionData) -> void:
	current_companion = companion
	companion_nodes_remaining = companion.duration_nodes

func dismiss_companion() -> void:
	current_companion = null
	companion_nodes_remaining = 0

func _tick_companion() -> void:
	if current_companion == null:
		return
	if current_companion.duration_nodes < 0:
		return
	companion_nodes_remaining -= 1
	if companion_nodes_remaining <= 0:
		_on_companion_depart()

func _on_companion_depart() -> void:
	if current_companion == null:
		return
	match current_companion.companion_type:
		CompanionData.CompanionType.TRAITOR:
			ResourceManager.consume_fuel(mini(5, ResourceManager.fuel))
		CompanionData.CompanionType.MERCHANT:
			ResourceManager.add_scrap(3)
		CompanionData.CompanionType.FIGHTER:
			pass
		CompanionData.CompanionType.REFUGEE:
			KarmaManager.add_karma(5)
	current_companion = null
	companion_nodes_remaining = 0

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
	return current_character.unique_system == &"acceleration"

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
	if current_character == null:
		return
	if current_character.unique_system != &"heat":
		return
	var gain := randi_range(5, 10)
	if current_companion != null and current_companion.companion_type == CompanionData.CompanionType.INFORMANT:
		gain = maxi(1, gain - 3)
	pursuit_level += gain
	if pursuit_level >= 100:
		pursuit_triggered = true
		pursuit_level = clampi(pursuit_level - 40, 0, 100)

func advance_act() -> void:
	current_act += 1
	current_node_index = -1
	map_nodes.clear()
	map_current_row = -1
	map_current_node_id = ""

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
