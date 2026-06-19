extends Control

func _ready() -> void:
	$RestButton.pressed.connect(_on_rest)
	$UpgradeButton.pressed.connect(_on_upgrade)
	_update_display()

func _update_display() -> void:
	$HPLabel.text = "現在HP: %d/%d" % [CombatManager.player_hp, CombatManager.player_max_hp]
	var heal := CombatManager.player_max_hp * 30 / 100
	$RestButton.text = "休息 (HP %d 回復)" % heal

func _on_rest() -> void:
	var heal := CombatManager.player_max_hp * 30 / 100
	CombatManager.player_hp = mini(CombatManager.player_hp + heal, CombatManager.player_max_hp)
	_return_to_map()

func _on_upgrade() -> void:
	if DeckManager.master_deck.is_empty():
		_return_to_map()
		return
	for child in $CardContainer.get_children():
		child.queue_free()
	$RestButton.visible = false
	$UpgradeButton.visible = false
	$InfoLabel.text = "強化するカードを選択:"

	for card: CardData in DeckManager.master_deck:
		if card.upgraded:
			continue
		var btn := Button.new()
		btn.text = "%s — %s" % [card.display_name, card.description]
		btn.custom_minimum_size = Vector2(400, 40)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_card_upgrade.bind(card))
		$CardContainer.add_child(btn)

func _on_card_upgrade(card: CardData) -> void:
	card.upgraded = true
	_return_to_map()

func _return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
