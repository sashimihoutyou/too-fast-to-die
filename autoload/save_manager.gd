extends Node

const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_run() -> void:
	var deck_ids: Array[String] = []
	for card: CardData in DeckManager.master_deck:
		var card_id: String = card.id
		if card.upgraded:
			card_id += "+"
		deck_ids.append(card_id)

	var companion_id: String = ""
	if GameManager.current_companion != null:
		companion_id = GameManager.current_companion.id
	var secondary_companion_id: String = ""
	if GameManager.secondary_companion != null:
		secondary_companion_id = GameManager.secondary_companion.id

	var equipped: Dictionary = {}
	for slot_key: Variant in ResourceManager.equipped_parts:
		var part: BikePartData = ResourceManager.equipped_parts[slot_key]
		equipped[str(slot_key)] = str(part.id)

	var pending_enemy_ids: Array[String] = []
	for enemy_id: StringName in GameManager.pending_combat_enemy_ids:
		pending_enemy_ids.append(str(enemy_id))

	var data := {
		"character_id": str(GameManager.current_character.id),
		"current_act": GameManager.current_act,
		"current_node_index": GameManager.current_node_index,
		"total_nodes_visited": GameManager.total_nodes_visited,
		"distance_km": GameManager.distance_km,
		"map_current_row": GameManager.map_current_row,
		"map_current_node_id": GameManager.map_current_node_id,
		"pending_combat_node_type": GameManager.pending_combat_node_type,
		"pending_combat_enemy_ids": pending_enemy_ids,
		"pending_combat_boss_hp_scale": GameManager.pending_combat_boss_hp_scale,
		"boss_cleared": GameManager.boss_cleared,
		"pending_result": str(GameManager.pending_result),
		"event_flags": GameManager.event_flags,
		"pursuit_level": GameManager.pursuit_level,
		"faith": GameManager.faith,
		"oasis_info": GameManager.oasis_info,
		"companion_id": companion_id,
		"companion_nodes_remaining": GameManager.companion_nodes_remaining,
		"companion_hp": GameManager.companion_hp,
		"companion_is_settled": GameManager.companion_is_settled,
		"companion_bond": GameManager.companion_bond,
		"companion_pending_offer": GameManager.companion_pending_offer,
		"secondary_companion_id": secondary_companion_id,
		"secondary_companion_nodes_remaining": GameManager.secondary_companion_nodes_remaining,
		"secondary_companion_hp": GameManager.secondary_companion_hp,
		"secondary_companion_is_settled": GameManager.secondary_companion_is_settled,
		"secondary_companion_bond": GameManager.secondary_companion_bond,
		"secondary_companion_pending_offer": GameManager.secondary_companion_pending_offer,
		"player_hp": CombatManager.player_hp,
		"player_max_hp": CombatManager.player_max_hp,
		"player_heat": CombatManager.player_heat,
		"player_euphoria": CombatManager.player_euphoria,
		"fuel": ResourceManager.fuel,
		"tank_capacity": ResourceManager.tank_capacity,
		"scrap": ResourceManager.scrap,
		"medicine": ResourceManager.medicine,
		"bike_durability": ResourceManager.bike_durability,
		"bike_max_durability": ResourceManager.bike_max_durability,
		"equipped_parts": equipped,
		"karma": KarmaManager.karma,
		"deck": deck_ids,
		"map_nodes": _serialize_map_nodes(),
		"inventory": ItemDatabase.get_save_data(),
		"quests": QuestManager.get_save_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	var data: Dictionary = json.data

	var char_id: StringName = StringName(data.get("character_id", ""))
	var character: CharacterData = _find_character(char_id)
	if character == null:
		return false

	GameManager.current_character = character
	GameManager.current_act = int(data.get("current_act", 1))
	GameManager.current_node_index = int(data.get("current_node_index", -1))
	GameManager.total_nodes_visited = int(data.get("total_nodes_visited", 0))
	GameManager.distance_km = int(data.get("distance_km", 0))
	GameManager.map_current_row = int(data.get("map_current_row", -1))
	GameManager.map_current_node_id = str(data.get("map_current_node_id", ""))
	GameManager.pending_combat_node_type = int(data.get("pending_combat_node_type", -1))
	GameManager.pending_combat_enemy_ids.clear()
	var pending_enemy_data: Array = data.get("pending_combat_enemy_ids", [])
	for raw_enemy_id: Variant in pending_enemy_data:
		GameManager.pending_combat_enemy_ids.append(StringName(str(raw_enemy_id)))
	GameManager.pending_combat_boss_hp_scale = float(data.get("pending_combat_boss_hp_scale", 1.0))
	GameManager.boss_cleared = bool(data.get("boss_cleared", false))
	GameManager.pending_result = StringName(data.get("pending_result", "defeat"))
	GameManager.event_flags = data.get("event_flags", {})
	GameManager.pursuit_level = int(data.get("pursuit_level", 0))
	GameManager.faith = int(data.get("faith", 80))
	GameManager.oasis_info = data.get("oasis_info", {})
	GameManager.companion_nodes_remaining = int(data.get("companion_nodes_remaining", 0))
	GameManager.companion_hp = int(data.get("companion_hp", 0))
	GameManager.companion_is_settled = bool(data.get("companion_is_settled", false))
	GameManager.companion_bond = int(data.get("companion_bond", 0))
	GameManager.companion_pending_offer = bool(data.get("companion_pending_offer", false))
	GameManager.secondary_companion_nodes_remaining = int(data.get("secondary_companion_nodes_remaining", 0))
	GameManager.secondary_companion_hp = int(data.get("secondary_companion_hp", 0))
	GameManager.secondary_companion_is_settled = bool(data.get("secondary_companion_is_settled", false))
	GameManager.secondary_companion_bond = int(data.get("secondary_companion_bond", 0))
	GameManager.secondary_companion_pending_offer = bool(data.get("secondary_companion_pending_offer", false))
	GameManager.pending_bond_slot = -1
	GameManager.pursuit_triggered = false

	var comp_id: String = data.get("companion_id", "")
	if comp_id != "":
		GameManager.current_companion = CompanionDatabase.get_companion(StringName(comp_id))
		if GameManager.current_companion != null and GameManager.companion_hp <= 0:
			GameManager.companion_hp = GameManager.current_companion.max_hp
	else:
		GameManager.current_companion = null
		GameManager.companion_hp = 0
		GameManager.companion_is_settled = false
	var secondary_comp_id: String = data.get("secondary_companion_id", "")
	if secondary_comp_id != "":
		GameManager.secondary_companion = CompanionDatabase.get_companion(StringName(secondary_comp_id))
		if GameManager.secondary_companion != null and GameManager.secondary_companion_hp <= 0:
			GameManager.secondary_companion_hp = GameManager.secondary_companion.max_hp
	else:
		GameManager.secondary_companion = null
		GameManager.secondary_companion_hp = 0
		GameManager.secondary_companion_is_settled = false

	CombatManager.player_hp = int(data.get("player_hp", character.max_hp))
	CombatManager.player_max_hp = int(data.get("player_max_hp", character.max_hp))
	CombatManager.player_heat = int(data.get("player_heat", 0))
	CombatManager.player_euphoria = int(data.get("player_euphoria", 50 if character.unique_system == &"euphoria" else 0))

	ResourceManager.fuel = int(data.get("fuel", 20))
	ResourceManager.tank_capacity = int(data.get("tank_capacity", 30))
	ResourceManager.scrap = int(data.get("scrap", 0))
	ResourceManager.medicine = int(data.get("medicine", 1))
	ResourceManager.bike_durability = int(data.get("bike_durability", 15))
	ResourceManager.bike_max_durability = int(data.get("bike_max_durability", 15))

	ResourceManager.equipped_parts.clear()
	var equipped: Dictionary = data.get("equipped_parts", {})
	for slot_str: String in equipped:
		var part_id: StringName = StringName(equipped[slot_str])
		var part := BikePartsDatabase.get_part(part_id)
		if part != null:
			ResourceManager.equipped_parts[int(slot_str)] = part

	KarmaManager.karma = int(data.get("karma", 0))

	DeckManager.master_deck.clear()
	var deck: Array = data.get("deck", [])
	for card_str: Variant in deck:
		var id_str: String = str(card_str)
		var is_upgraded := id_str.ends_with("+")
		if is_upgraded:
			id_str = id_str.left(-1)
		var card := CardDatabase.get_card(StringName(id_str))
		if card != null:
			var copy := card.duplicate_card()
			if is_upgraded:
				copy.upgraded = true
			DeckManager.master_deck.append(copy)

	ItemDatabase.load_save_data(data.get("inventory", []))
	QuestManager.load_save_data(data.get("quests", {}))

	GameManager.map_nodes.clear()
	var map_data: Array = data.get("map_nodes", [])
	for node_data: Variant in map_data:
		var nd: Dictionary = node_data as Dictionary
		var node: Dictionary = {
			"row": int(nd.get("row", 0)),
			"col": int(nd.get("col", 0)),
			"type": int(nd.get("type", 0)),
			"faction": int(nd.get("faction", 0)),
			"site": int(nd.get("site", 0)),
			"position": Vector2(float(nd.get("pos_x", 0)), float(nd.get("pos_y", 0))),
			"connections": nd.get("connections", []),
			"visited": nd.get("visited", false),
			"fuel_reward": int(nd.get("fuel_reward", 0)),
		}
		GameManager.map_nodes.append(node)

	delete_save()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func _find_character(id: StringName) -> CharacterData:
	var dir := DirAccess.open("res://resources/characters/")
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := "res://resources/characters/".path_join(file_name)
			var character: CharacterData = load(full_path)
			if character != null and character.id == id:
				return character
		file_name = dir.get_next()
	return null

func _serialize_map_nodes() -> Array:
	var result: Array = []
	for node: Dictionary in GameManager.map_nodes:
		var pos: Vector2 = node.get("position", Vector2.ZERO)
		result.append({
			"row": node.get("row", 0),
			"col": node.get("col", 0),
			"type": node.get("type", 0),
			"faction": int(node.get("faction", 0)),
			"site": int(node.get("site", 0)),
			"pos_x": pos.x,
			"pos_y": pos.y,
			"connections": node.get("connections", []),
			"visited": node.get("visited", false),
			"fuel_reward": int(node.get("fuel_reward", 0)),
		})
	return result
