extends Control

const SHOP_ITEMS := [
	{"name": "医薬品", "cost": 4, "type": "medicine"},
	{"name": "スクラップ×5", "cost": 3, "type": "scrap"},
	{"name": "カード削除", "cost": 5, "type": "remove_card"},
]

func _ready() -> void:
	$TitleLabel.text = "ショップ"
	_build_shop()
	$LeaveButton.pressed.connect(_on_leave)
	_update_fuel_display()

func _get_discount() -> float:
	if GameManager.current_companion != null and GameManager.current_companion.companion_type == CompanionData.CompanionType.MERCHANT:
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

	for item in SHOP_ITEMS:
		var cost := _discounted(item["cost"])
		var btn := Button.new()
		btn.text = "%s — %d燃料" % [item["name"], cost]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy.bind(item))
		$ItemContainer.add_child(btn)

	_build_bike_part_shop()

	var card_pool := CardDatabase.get_reward_pool(GameManager.current_act, GameManager.current_character.id)
	card_pool.shuffle()
	for i in mini(4, card_pool.size()):
		var card: CardData = card_pool[i]
		var cost := _discounted(4 + card.rarity * 3)
		var btn := Button.new()
		btn.text = "%s [%s] — %d燃料" % [card.get_display_name(), card.description, cost]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy_card.bind(card, cost))
		$ItemContainer.add_child(btn)

func _build_bike_part_shop() -> void:
	var all_parts: Array[BikePartData] = []
	for slot_val in [BikePartData.Slot.ENGINE, BikePartData.Slot.TIRES, BikePartData.Slot.FRAME, BikePartData.Slot.TANK]:
		var parts := BikePartsDatabase.get_parts_by_slot(slot_val)
		all_parts.append_array(parts)
	all_parts.shuffle()
	var count := mini(2, all_parts.size())
	for i in count:
		var part: BikePartData = all_parts[i]
		var base_cost := 5 + int(part.rarity) * 4
		var cost := _discounted(base_cost)
		var slot_name := _slot_display_name(part.slot)
		var btn := Button.new()
		btn.text = "[%s] %s — %d燃料" % [slot_name, part.display_name, cost]
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

func _on_buy_part(part: BikePartData, cost: int) -> void:
	if not ResourceManager.consume_fuel(cost):
		return
	ResourceManager.equip_part(part)
	_build_shop()
	_update_fuel_display()

func _on_buy(item: Dictionary) -> void:
	var cost := _discounted(item["cost"])
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
	_build_shop()
	_update_fuel_display()

func _show_remove_card_ui(cost: int) -> void:
	for child in $ItemContainer.get_children():
		child.queue_free()
	var info := Label.new()
	info.text = "削除するカードを選択 (%d燃料):" % cost
	info.add_theme_font_size_override("font_size", 18)
	$ItemContainer.add_child(info)
	for card: CardData in DeckManager.master_deck:
		var btn := Button.new()
		btn.text = "%s — %s" % [card.get_display_name(), card.description]
		btn.custom_minimum_size = Vector2(400, 40)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_remove_card.bind(card, cost))
		$ItemContainer.add_child(btn)
	var cancel := Button.new()
	cancel.text = "やめる"
	cancel.custom_minimum_size = Vector2(400, 40)
	cancel.add_theme_font_size_override("font_size", 15)
	cancel.pressed.connect(_cancel_remove_card)
	$ItemContainer.add_child(cancel)

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
	_build_shop()
	_update_fuel_display()

func _update_fuel_display() -> void:
	$FuelLabel.text = "所持燃料: %d" % ResourceManager.fuel

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
