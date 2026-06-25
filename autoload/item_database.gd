extends Node

var _items: Dictionary = {}
var inventory: Array[Dictionary] = []

func _ready() -> void:
	_load_items("res://resources/items/consumable/")
	_load_items("res://resources/items/relic/")

func _load_items(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res := load(path + fname) as ItemData
			if res != null:
				_items[res.id] = res
		fname = dir.get_next()

func get_item(item_id: StringName) -> ItemData:
	return _items.get(item_id, null)

func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _items.values():
		result.append(item)
	return result

func get_items_by_type(item_type: ItemData.ItemType) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _items.values():
		if item.item_type == item_type:
			result.append(item)
	return result

func add_to_inventory(item_id: StringName, count: int = 1) -> void:
	for entry: Dictionary in inventory:
		if entry["id"] == item_id:
			var item := get_item(item_id)
			if item != null:
				entry["count"] = mini(int(entry["count"]) + count, item.max_stack)
			return
	inventory.append({"id": item_id, "count": count})

func remove_from_inventory(item_id: StringName, count: int = 1) -> bool:
	for i in inventory.size():
		if inventory[i]["id"] == item_id:
			var current: int = int(inventory[i]["count"])
			if current < count:
				return false
			current -= count
			if current <= 0:
				inventory.remove_at(i)
			else:
				inventory[i]["count"] = current
			return true
	return false

func get_inventory_count(item_id: StringName) -> int:
	for entry: Dictionary in inventory:
		if entry["id"] == item_id:
			return int(entry["count"])
	return 0

func has_relic(item_id: StringName) -> bool:
	return get_inventory_count(item_id) > 0

func get_relics() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for entry: Dictionary in inventory:
		var item := get_item(entry["id"])
		if item != null and item.item_type == ItemData.ItemType.RELIC:
			result.append(item)
	return result

func get_consumables() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in inventory:
		var item := get_item(entry["id"])
		if item != null and item.item_type == ItemData.ItemType.CONSUMABLE:
			result.append({"item": item, "count": int(entry["count"])})
	return result

func use_consumable(item_id: StringName) -> bool:
	var item := get_item(item_id)
	if item == null:
		return false
	if item.item_type != ItemData.ItemType.CONSUMABLE:
		return false
	if not remove_from_inventory(item_id):
		return false
	_apply_item_effect(item)
	return true

func _apply_item_effect(item: ItemData) -> void:
	if item.hp_change != 0:
		CombatManager.player_hp = clampi(
			CombatManager.player_hp + item.hp_change, 0, CombatManager.player_max_hp)
		CombatManager.player_hp_changed.emit(CombatManager.player_hp, CombatManager.player_max_hp)
	if item.fuel_change > 0:
		ResourceManager.add_fuel(item.fuel_change)
	elif item.fuel_change < 0:
		ResourceManager.consume_fuel(-item.fuel_change)
	if item.scrap_change > 0:
		ResourceManager.add_scrap(item.scrap_change)

func reset() -> void:
	inventory.clear()

func get_save_data() -> Array:
	return inventory.duplicate(true)

func load_save_data(data: Array) -> void:
	inventory.clear()
	for entry in data:
		inventory.append(entry)
