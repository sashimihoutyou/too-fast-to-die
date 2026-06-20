extends Node

var _parts: Dictionary = {}

func _ready() -> void:
	_load_parts_from_directory("res://resources/bike_parts")

func get_part(id: StringName) -> BikePartData:
	return _parts.get(id, null)

func get_parts_by_slot(slot: BikePartData.Slot) -> Array[BikePartData]:
	var result: Array[BikePartData] = []
	for part: BikePartData in _parts.values():
		if part.slot == slot:
			result.append(part)
	return result

func get_parts_by_rarity(rarity: BikePartData.PartRarity) -> Array[BikePartData]:
	var result: Array[BikePartData] = []
	for part: BikePartData in _parts.values():
		if part.rarity == rarity:
			result.append(part)
	return result

func reload() -> void:
	_parts.clear()
	_load_parts_from_directory("res://resources/bike_parts")


func _load_parts_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var part: BikePartData = load(full_path)
			if part != null and part.id != &"":
				_parts[part.id] = part
		file_name = dir.get_next()
