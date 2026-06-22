extends Node

var _events: Dictionary = {}

func _ready() -> void:
	_load_events_from_directory("res://resources/events/settlement")
	_load_events_from_directory("res://resources/events/faction")
	_load_events_from_directory("res://resources/events/character")
	_load_events_from_directory("res://resources/events/travel")

func get_event(id: StringName) -> EventData:
	return _events.get(id, null)

func get_available_events(character_id: StringName, karma: int, act: int) -> Array[EventData]:
	var available: Array[EventData] = []
	for event: EventData in _events.values():
		if event.payload_only:
			continue
		if event.required_character != &"" and event.required_character != character_id:
			continue
		if karma < event.required_karma_min or karma > event.required_karma_max:
			continue
		if event.required_act != -1 and act < event.required_act:
			continue
		available.append(event)
	return available

func reload() -> void:
	_events.clear()
	_load_events_from_directory("res://resources/events/settlement")
	_load_events_from_directory("res://resources/events/faction")
	_load_events_from_directory("res://resources/events/character")
	_load_events_from_directory("res://resources/events/travel")


func _load_events_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var event: EventData = load(full_path)
			if event != null and event.id != &"":
				_events[event.id] = event
		file_name = dir.get_next()
