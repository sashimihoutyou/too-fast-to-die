extends Control

const SHOP_ITEMS := [
	{"name": "医薬品", "cost": 4, "type": "medicine"},
	{"name": "スクラップ×5", "cost": 3, "type": "scrap"},
	{"name": "バイク修理+6", "cost": 3, "type": "repair_bike"},
	{"name": "カード削除", "cost": 5, "type": "remove_card"},
]

var _stock_cards: Array[CardData] = []
var _stock_parts: Array[BikePartData] = []
var _stock_items: Array[ItemData] = []

func _ready() -> void:
	$TitleLabel.text = "ショップ"
	_roll_stock()
	_build_shop()
	$LeaveButton.pressed.connect(_on_leave)
	_update_fuel_display()

func _get_discount() -> float:
	if GameManager.has_companion_type(CompanionData.CompanionType.MERCHANT):
		return 0.9
	return 1.0

func _discounted(base_cost: int) -> int:
	return maxi(1, int(float(base_cost) * _get_discount()))

func _build_shop() -> void:
	for child in $ItemContainer.get_children():
		child.queue_free()

	if _get_discount() < 1.0:
		var disc_label := Label.new()
		disc_label.text = "商人同行者の割引: 10%OFF"
		disc_label.add_theme_font_size_override("font_size", 14)
		disc_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		$ItemContainer.add_child(disc_label)

	for item: Dictionary in SHOP_ITEMS:
		var cost: int = _discounted(int(item["cost"]))
		var btn := Button.new()
		btn.text = "%s — %d%s" % [item["name"], cost, GameManager.get_travel_resource_name()]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy.bind(item))
		$ItemContainer.add_child(btn)

	_build_bike_part_shop()
	_build_item_shop()

	for card: CardData in _stock_cards:
		var cost: int = _discounted(4 + int(card.rarity) * 3)
		var btn := Button.new()
		btn.text = "%s [%s] — %d%s" % [card.get_display_name(), card.description, cost, GameManager.get_travel_resource_name()]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy_card.bind(card, cost))
		$ItemContainer.add_child(btn)

func _roll_stock() -> void:
	_stock_cards.clear()
	_stock_parts.clear()
	_stock_items.clear()

	var card_pool: Array[CardData] = CardDatabase.get_reward_pool(GameManager.current_act, GameManager.current_character.id)
	card_pool.shuffle()
	for i: int in mini(4, card_pool.size()):
		_stock_cards.append(card_pool[i])

	var all_parts: Array[BikePartData] = []
	for slot_val: BikePartData.Slot in [BikePartData.Slot.ENGINE, BikePartData.Slot.TIRES, BikePartData.Slot.FRAME, BikePartData.Slot.TANK]:
		var parts: Array[BikePartData] = BikePartsDatabase.get_parts_by_slot(slot_val)
		all_parts.append_array(parts)
	all_parts.shuffle()
	for i: int in mini(2, all_parts.size()):
		_stock_parts.append(all_parts[i])

	var all_items: Array[ItemData] = ItemDatabase.get_all_items()
	all_items.shuffle()
	for i: int in mini(2, all_items.size()):
		_stock_items.append(all_items[i])

func _build_bike_part_shop() -> void:
	for part: BikePartData in _stock_parts:
		var base_cost: int = 5 + int(part.rarity) * 4
		var cost: int = _discounted(base_cost)
		var slot_name: String = _slot_display_name(part.slot)
		var btn := Button.new()
		btn.text = "[%s] %s — %d%s" % [slot_name, part.display_name, cost, GameManager.get_travel_resource_name()]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy_part.bind(part, cost))
		$ItemContainer.add_child(btn)

func _slot_display_name(slot: BikePartData.Slot) -> String:
	match slot:
		BikePartData.Slot.ENGINE: return "エンジン"
		BikePartData.Slot.TIRES: return "タイヤ"
		BikePartData.Slot.FRAME: return "フレーム"
		BikePartData.Slot.TANK: return "タンク"
		BikePartData.Slot.DECORATION: return "装飾"
	return "パーツ"

func _build_item_shop() -> void:
	for item: ItemData in _stock_items:
		var base_cost: int = 3 + int(item.rarity) * 3
		if item.item_type == ItemData.ItemType.RELIC:
			base_cost += 4
		var cost: int = _discounted(base_cost)
		var type_str: String = "遺物" if item.item_type == ItemData.ItemType.RELIC else "消耗品"
		var btn := Button.new()
		btn.text = "[%s] %s (%s) — %d%s" % [type_str, item.display_name, item.description, cost, GameManager.get_travel_resource_name()]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy_item.bind(item, cost))
		$ItemContainer.add_child(btn)

func _on_buy_item(item: ItemData, cost: int) -> void:
	if not ResourceManager.consume_fuel(cost):
		return
	ItemDatabase.add_to_inventory(item.id)
	_stock_items.erase(item)
	_build_shop()
	_update_fuel_display()

func _on_buy_part(part: BikePartData, cost: int) -> void:
	if not ResourceManager.consume_fuel(cost):
		return
	ResourceManager.equip_part(part)
	_stock_parts.erase(part)
	_build_shop()
	_update_fuel_display()

func _on_buy(item: Dictionary) -> void:
	var cost: int = _discounted(int(item["cost"]))
	if ResourceManager.fuel < cost:
		return
	if item["type"] == "remove_card":
		_show_remove_card_ui(cost)
		return
	if not ResourceManager.consume_fuel(cost):
		return
	match item["type"]:
		"medicine":
			ResourceManager.add_medicine(1)
		"scrap":
			ResourceManager.add_scrap(5)
		"repair_bike":
			ResourceManager.repair_bike(6)
	_build_shop()
	_update_fuel_display()

func _show_remove_card_ui(cost: int) -> void:
	var popup := DeckListPopup.new()
	popup.card_selected.connect(func(card: CardData) -> void:
		_on_remove_card(card, cost)
	)
	popup.closed.connect(_cancel_remove_card)
	add_child(popup)
	popup.setup("削除するカードを選択 (%d%s)" % [cost, GameManager.get_travel_resource_name()], DeckManager.master_deck, true, "やめる")

func _on_remove_card(card: CardData, cost: int) -> void:
	if not ResourceManager.consume_fuel(cost):
		_cancel_remove_card()
		return
	DeckManager.remove_card_from_deck(card)
	_build_shop()
	_update_fuel_display()

func _cancel_remove_card() -> void:
	_build_shop()
	_update_fuel_display()

func _on_buy_card(card: CardData, cost: int) -> void:
	if not ResourceManager.consume_fuel(cost):
		return
	DeckManager.add_card_to_deck(card)
	_stock_cards.erase(card)
	_build_shop()
	_update_fuel_display()

func _update_fuel_display() -> void:
	$FuelLabel.text = "所持%s: %d / 耐久: %d/%d" % [
		GameManager.get_travel_resource_name(),
		ResourceManager.fuel,
		ResourceManager.bike_durability,
		ResourceManager.bike_max_durability,
	]

func _on_leave() -> void:
	GameManager.clear_pending_combat()
	SaveManager.save_run()
	GameManager.go_to_state(GameManager.GameState.MAP)
