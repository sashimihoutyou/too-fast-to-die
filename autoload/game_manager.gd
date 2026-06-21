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
var distance_km: int = 0
var event_flags: Dictionary = {}
var map_nodes: Array[Dictionary] = []
var map_current_row: int = -1
var map_current_node_id: String = ""
var boss_cleared: bool = false
var pending_result: StringName = &"defeat"

func start_run(character: CharacterData) -> void:
	current_character = character
	current_act = 1
	current_node_index = -1
	distance_km = 0
	event_flags.clear()
	map_nodes.clear()
	map_current_row = -1
	map_current_node_id = ""
	boss_cleared = false
	pending_result = &"defeat"
	ResourceManager.reset()
	DeckManager.build_starter_deck(character)
	KarmaManager.reset()
	CombatManager.reset_player_for_new_run()
	run_started.emit(character)
	change_state(GameState.MAP)

func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(GameState.keys()[new_state])

func advance_node() -> void:
	current_node_index += 1
	distance_km += randi_range(3, 6)
	ResourceManager.consume_fuel(2)

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
	run_ended.emit(result, distance_km)
	change_state(GameState.RESULT)

func go_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
	change_state(GameState.TITLE)
