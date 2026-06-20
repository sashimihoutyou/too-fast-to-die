extends Node

var _enemies: Dictionary = {}

func _ready() -> void:
	for act_num in range(1, 6):
		_load_enemies_from_directory("res://resources/enemies/act%d" % act_num)

func get_enemy(id: StringName) -> EnemyData:
	return _enemies.get(id, null)

func get_enemies_for_act(act: int) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for enemy: EnemyData in _enemies.values():
		if enemy.act == act and not enemy.is_elite and not enemy.is_boss:
			result.append(enemy)
	return result

func get_elites_for_act(act: int) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for enemy: EnemyData in _enemies.values():
		if enemy.act == act and enemy.is_elite:
			result.append(enemy)
	return result

func get_boss_for_act(act: int) -> EnemyData:
	for enemy: EnemyData in _enemies.values():
		if enemy.act == act and enemy.is_boss:
			return enemy
	return null

func reload() -> void:
	_enemies.clear()
	for act_num: int in range(1, 6):
		_load_enemies_from_directory("res://resources/enemies/act%d" % act_num)


func _load_enemies_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var enemy: EnemyData = load(full_path)
			if enemy != null and enemy.id != &"":
				_enemies[enemy.id] = enemy
		file_name = dir.get_next()
