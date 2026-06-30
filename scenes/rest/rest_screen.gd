extends Control

func _ready() -> void:
	$RestButton.pressed.connect(_on_rest)
	$UpgradeButton.pressed.connect(_on_upgrade)
	_update_display()
	_show_monologue()

func _update_display() -> void:
	$HPLabel.text = "現在HP: %d/%d" % [CombatManager.player_hp, CombatManager.player_max_hp]
	var heal := CombatManager.player_max_hp * 50 / 100
	$RestButton.text = "休息 (HP %d 回復)" % heal
	$UpgradeButton.disabled = _get_upgradeable_cards().is_empty()

func _on_rest() -> void:
	var heal := CombatManager.player_max_hp * 50 / 100
	CombatManager.player_hp = mini(CombatManager.player_hp + heal, CombatManager.player_max_hp)
	if GameManager.is_companion_active(&"penny"):
		CombatManager.recover_tiger_after_rest()
	_return_to_map()

func _on_upgrade() -> void:
	var upgradeable_cards := _get_upgradeable_cards()
	if upgradeable_cards.is_empty():
		$InfoLabel.text = "強化できるカードがありません。休息を選んでください。"
		$UpgradeButton.disabled = true
		return
	for child in $CardContainer.get_children():
		child.queue_free()
	$RestButton.visible = false
	$UpgradeButton.visible = false
	$InfoLabel.text = "強化するカードを選択:"

	for card: CardData in upgradeable_cards:
		var btn := Button.new()
		btn.text = _get_upgrade_preview(card)
		btn.custom_minimum_size = Vector2(500, 40)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_card_upgrade.bind(card))
		$CardContainer.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "やめる"
	cancel_btn.custom_minimum_size = Vector2(200, 35)
	cancel_btn.add_theme_font_size_override("font_size", 15)
	cancel_btn.pressed.connect(_cancel_upgrade)
	$CardContainer.add_child(cancel_btn)

func _on_card_upgrade(card: CardData) -> void:
	card.upgraded = true
	_return_to_map()

func _get_upgradeable_cards() -> Array[CardData]:
	var upgradeable_cards: Array[CardData] = []
	for card: CardData in DeckManager.master_deck:
		if not card.upgraded:
			upgradeable_cards.append(card)
	return upgradeable_cards

func _get_upgrade_preview(card: CardData) -> String:
	var parts: Array[String] = [card.get_display_name(), card.description]
	if not card.upgrade_description.is_empty():
		parts.append("強化: %s" % card.upgrade_description)
	else:
		var diffs: Array[String] = []
		if card.upgraded_damage > 0 and card.upgraded_damage != card.base_damage:
			diffs.append("ダメージ %d→%d" % [card.base_damage, card.upgraded_damage])
		if card.upgraded_block > 0 and card.upgraded_block != card.base_block:
			diffs.append("ブロック %d→%d" % [card.base_block, card.upgraded_block])
		if not diffs.is_empty():
			parts.append("強化: %s" % " / ".join(diffs))
	return " — ".join(parts)

func _cancel_upgrade() -> void:
	for child in $CardContainer.get_children():
		child.queue_free()
	$RestButton.visible = true
	$UpgradeButton.visible = true
	$InfoLabel.text = "束の間の安らぎ。何をする？"

func _show_monologue() -> void:
	if GameManager.current_character == null:
		return
	var text: String = RestMonologue.get_monologue(GameManager.current_character.id)
	if text.is_empty():
		return
	$MonologueLabel.text = text

func _return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
