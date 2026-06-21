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

func _build_shop() -> void:
	for child in $ItemContainer.get_children():
		child.queue_free()

	for item in SHOP_ITEMS:
		var btn := Button.new()
		btn.text = "%s — %d燃料" % [item["name"], item["cost"]]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.disabled = ResourceManager.fuel < item["cost"]
		btn.pressed.connect(_on_buy.bind(item))
		$ItemContainer.add_child(btn)

	var card_pool := CardDatabase.get_reward_pool(GameManager.current_act, GameManager.current_character.id)
	card_pool.shuffle()
	for i in mini(4, card_pool.size()):
		var card: CardData = card_pool[i]
		var cost := 4 + card.rarity * 3
		var btn := Button.new()
		btn.text = "%s [%s] — %d燃料" % [card.display_name, card.description, cost]
		btn.custom_minimum_size = Vector2(400, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = ResourceManager.fuel < cost
		btn.pressed.connect(_on_buy_card.bind(card, cost))
		$ItemContainer.add_child(btn)

func _on_buy(item: Dictionary) -> void:
	var cost: int = item["cost"]
	if ResourceManager.fuel < cost:
		return
	# カード削除は対象選択 → 確定時に燃料消費（誤購入で燃料を失わない）
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
		btn.text = "%s — %s" % [card.display_name, card.description]
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
