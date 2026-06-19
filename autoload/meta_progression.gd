extends Node

const SAVE_PATH := "user://meta.json"

var total_distance_km: int = 0
var unlocked_characters: Array[StringName] = [&"cultist"]
var cleared_characters: Array[StringName] = []
var total_runs: int = 0

func _ready() -> void:
	load_data()

func add_distance(km: int) -> void:
	total_distance_km += km
	total_runs += 1
	_check_unlocks()
	save_data()

func mark_cleared(character_id: StringName) -> void:
	if character_id not in cleared_characters:
		cleared_characters.append(character_id)
	_check_unlocks()
	save_data()

func is_unlocked(character_id: StringName) -> bool:
	return character_id in unlocked_characters

func _check_unlocks() -> void:
	if total_distance_km >= 100 and &"ex_raider" not in unlocked_characters:
		unlocked_characters.append(&"ex_raider")
	if total_distance_km >= 250 and &"wanderer" not in unlocked_characters:
		unlocked_characters.append(&"wanderer")
	if total_distance_km >= 500 and &"beast_master" not in unlocked_characters:
		unlocked_characters.append(&"beast_master")
	if not cleared_characters.is_empty() and &"conqueror" not in unlocked_characters:
		unlocked_characters.append(&"conqueror")

func save_data() -> void:
	var data := {
		"total_distance_km": total_distance_km,
		"unlocked_characters": unlocked_characters,
		"cleared_characters": cleared_characters,
		"total_runs": total_runs,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	total_distance_km = data.get("total_distance_km", 0)
	total_runs = data.get("total_runs", 0)
	unlocked_characters.clear()
	for c in data.get("unlocked_characters", ["cultist"]):
		unlocked_characters.append(StringName(c))
	cleared_characters.clear()
	for c in data.get("cleared_characters", []):
		cleared_characters.append(StringName(c))
