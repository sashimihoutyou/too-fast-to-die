class_name DebugResourceHotReload extends RefCounted


static func reload_for_path(path: String) -> void:
	if path.begins_with("res://resources/cards/"):
		CardDatabase.reload()
	elif path.begins_with("res://resources/enemies/"):
		EnemyDatabase.reload()
	elif path.begins_with("res://resources/bike_parts/"):
		BikePartsDatabase.reload()
	elif path.begins_with("res://resources/events/"):
		EventManager.reload()


static func is_combat_active() -> bool:
	return GameManager.current_state == GameManager.GameState.COMBAT
