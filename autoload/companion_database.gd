extends Node

var _companions: Dictionary = {}

func _ready() -> void:
	_load_companions_from_directory("res://resources/companions")

func get_companion(id: StringName) -> CompanionData:
	return _companions.get(id, null)

func get_all_companions() -> Array[CompanionData]:
	var result: Array[CompanionData] = []
	for comp: CompanionData in _companions.values():
		result.append(comp)
	return result

func _load_companions_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var comp: CompanionData = load(full_path)
			if comp != null and comp.id != &"":
				_companions[comp.id] = comp
		file_name = dir.get_next()
