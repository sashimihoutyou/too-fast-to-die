extends Control

var card_buttons: Array[Button] = []
var enemy_panels: Array[PanelContainer] = []
var target_buttons: Array[Button] = []
var hp_labels: Array[Label] = []
var block_labels: Array[Label] = []
var intent_labels: Array[Label] = []
var selected_card: CardData = null
var awaiting_reward: bool = false

func _ready() -> void:
	_setup_signals()
	_build_enemy_display()
	_update_player_hud()
	_update_hand()
	_update_controls()

func _setup_signals() -> void:
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.card_played.connect(_on_card_played)
	CombatManager.enemy_defeated.connect(_on_enemy_defeated)
	CombatManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	CombatManager.enemy_block_changed.connect(_on_enemy_block_changed)
	CombatManager.enemy_intent_updated.connect(_on_enemy_intent_updated)
	CombatManager.player_hp_changed.connect(_on_player_hp_changed)
	CombatManager.player_block_changed.connect(_on_player_block_changed)
	CombatManager.ap_changed.connect(_on_ap_changed)
	CombatManager.combat_won.connect(_on_combat_won)
	CombatManager.combat_lost.connect(_on_combat_lost)
	CombatManager.player_fled.connect(_on_player_fled)
	DeckManager.cards_drawn.connect(_on_cards_drawn)
	$Controls/EndTurnButton.pressed.connect(_on_end_turn)
	$Controls/FleeButton.pressed.connect(_on_flee)
	$Controls/RerollButton.pressed.connect(_on_reroll)

func _build_enemy_display() -> void:
	for child in $EnemyArea.get_children():
		child.queue_free()
	enemy_panels.clear()
	target_buttons.clear()
	hp_labels.clear()
	block_labels.clear()
	intent_labels.clear()

	for i in CombatManager.enemies.size():
		var enemy: Dictionary = CombatManager.enemies[i]
		var data: EnemyData = enemy["data"]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(160, 200)
		var style := StyleBoxFlat.new()
		match data.category:
			EnemyData.Category.BEAST:
				style.bg_color = Color(0.3, 0.15, 0.1, 0.9)
			EnemyData.Category.HUMAN:
				style.bg_color = Color(0.2, 0.15, 0.15, 0.9)
			EnemyData.Category.MACHINE:
				style.bg_color = Color(0.15, 0.15, 0.25, 0.9)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)

		var name_label := Label.new()
		name_label.text = data.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
		name_label.name = "NameLabel"
		vbox.add_child(name_label)

		var icon_label := Label.new()
		match data.category:
			EnemyData.Category.BEAST: icon_label.text = "🐺"
			EnemyData.Category.HUMAN: icon_label.text = "🗡"
			EnemyData.Category.MACHINE: icon_label.text = "⚙"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 48)
		vbox.add_child(icon_label)

		var hp_label := Label.new()
		hp_label.name = "HPLabel"
		hp_label.text = "HP: %d/%d" % [enemy["hp"], enemy["max_hp"]]
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 14)
		hp_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		vbox.add_child(hp_label)

		if not data.weaknesses.is_empty():
			var weakness_label := Label.new()
			weakness_label.text = "弱点: %s" % _tags_to_text(data.weaknesses)
			weakness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			weakness_label.add_theme_font_size_override("font_size", 12)
			weakness_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
			vbox.add_child(weakness_label)

		var block_label := Label.new()
		block_label.name = "BlockLabel"
		block_label.text = ""
		block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block_label.add_theme_font_size_override("font_size", 14)
		block_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
		vbox.add_child(block_label)

		var intent_label := Label.new()
		intent_label.name = "IntentLabel"
		intent_label.text = ""
		intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_label.add_theme_font_size_override("font_size", 13)
		intent_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(intent_label)

		var target_btn := Button.new()
		target_btn.text = "攻撃対象"
		target_btn.add_theme_font_size_override("font_size", 12)
		target_btn.pressed.connect(_on_enemy_target.bind(i))
		target_btn.name = "TargetButton"
		vbox.add_child(target_btn)

		panel.add_child(vbox)
		$EnemyArea.add_child(panel)
		enemy_panels.append(panel)
		target_buttons.append(target_btn)
		hp_labels.append(hp_label)
		block_labels.append(block_label)
		intent_labels.append(intent_label)

func _update_hand() -> void:
	for child in $HandArea.get_children():
		child.queue_free()
	card_buttons.clear()

	for card: CardData in DeckManager.hand:
		var btn := _create_card_button(card)
		$HandArea.add_child(btn)
		card_buttons.append(btn)

func _tag_name(tag: CardData.Tag) -> String:
	match tag:
		CardData.Tag.MELEE: return "近接"
		CardData.Tag.RANGED: return "射撃"
		CardData.Tag.BIKE: return "バイク"
		CardData.Tag.DEFENSE: return "防御"
		CardData.Tag.SKILL: return "スキル"
		CardData.Tag.CHARACTER: return "固有"
	return ""

func _tags_to_bracket_text(tags: Array[CardData.Tag]) -> String:
	var text := ""
	for tag in tags:
		text += "[%s]" % _tag_name(tag)
	return text

func _tags_to_text(tags: Array[CardData.Tag]) -> String:
	var names: Array[String] = []
	for tag in tags:
		names.append(_tag_name(tag))
	return "・".join(names)

func _create_card_button(card: CardData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 190)

	var can_play := CombatManager.can_play_card(card)
	var effective_cost := CombatManager.get_effective_ap_cost(card)
	var cost_text := "%dAP" % effective_cost
	if effective_cost != card.ap_cost:
		cost_text = "%dAP(半額)" % effective_cost
	if card.fuel_cost > 0:
		cost_text += "+%d燃" % card.fuel_cost

	var tag_text := _tags_to_bracket_text(card.tags)

	btn.text = "%s\n%s\n%s\n%s" % [cost_text, card.display_name, tag_text, card.description]
	btn.disabled = not can_play or card.is_unplayable
	btn.pressed.connect(_on_card_selected.bind(card))

	var style := StyleBoxFlat.new()
	if card.is_unplayable:
		style.bg_color = Color(0.3, 0.1, 0.3, 0.9)
	elif can_play:
		match card.rarity:
			CardData.Rarity.COMMON: style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
			CardData.Rarity.UNCOMMON: style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
			CardData.Rarity.RARE: style.bg_color = Color(0.3, 0.25, 0.1, 0.9)
	else:
		style.bg_color = Color(0.15, 0.12, 0.1, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	match card.rarity:
		CardData.Rarity.COMMON: style.border_color = Color(0.4, 0.4, 0.4)
		CardData.Rarity.UNCOMMON: style.border_color = Color(0.3, 0.5, 0.8)
		CardData.Rarity.RARE: style.border_color = Color(0.8, 0.7, 0.2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

func _on_card_selected(card: CardData) -> void:
	if not CombatManager.can_play_card(card):
		return
	var needs_target := card.base_damage > 0 and not card.is_aoe
	if needs_target:
		selected_card = card
		_show_target_buttons(true)
	else:
		CombatManager.play_card(card, 0)
		_after_card_play()

func _on_enemy_target(idx: int) -> void:
	if selected_card == null:
		return
	CombatManager.play_card(selected_card, idx)
	selected_card = null
	_show_target_buttons(false)
	_after_card_play()

func _show_target_buttons(show: bool) -> void:
	for i in target_buttons.size():
		if i < CombatManager.enemies.size():
			target_buttons[i].visible = show and CombatManager.enemies[i]["alive"]

func _after_card_play() -> void:
	_update_hand()
	_update_player_hud()
	_update_controls()

func _update_player_hud() -> void:
	$PlayerHUD/HPLabel.text = "HP: %d/%d" % [CombatManager.player_hp, CombatManager.player_max_hp]
	$PlayerHUD/HPBar.max_value = CombatManager.player_max_hp
	$PlayerHUD/HPBar.value = CombatManager.player_hp
	$PlayerHUD/APLabel.text = "AP: %d/%d" % [CombatManager.ap, CombatManager.max_ap]
	$PlayerHUD/BlockLabel.text = "ブロック: %d" % CombatManager.player_block
	$PlayerHUD/FuelLabel.text = "燃料: %d/%d" % [ResourceManager.fuel, ResourceManager.tank_capacity]
	$PlayerHUD/DeckLabel.text = "山札: %d | 捨札: %d" % [DeckManager.get_deck_count(), DeckManager.get_discard_count()]

func _update_controls() -> void:
	var in_turn := CombatManager.state == CombatManager.CombatState.PLAYER_TURN
	$Controls/EndTurnButton.disabled = not in_turn
	$Controls/FleeButton.disabled = not in_turn
	$Controls/RerollButton.disabled = not in_turn or ResourceManager.fuel < 1
	$Controls/FleeButton.text = "逃走 (1燃料)"

func _on_end_turn() -> void:
	selected_card = null
	_show_target_buttons(false)
	CombatManager.end_player_turn()

func _on_flee() -> void:
	CombatManager.flee()

func _on_reroll() -> void:
	CombatManager.emergency_reroll()
	_update_hand()
	_update_player_hud()
	_update_controls()

func _on_turn_started(_turn: int) -> void:
	_update_hand()
	_update_player_hud()
	_update_controls()

func _on_card_played(_card: CardData) -> void:
	pass

func _on_cards_drawn(_cards: Array[CardData]) -> void:
	_update_hand()

func _on_enemy_defeated(idx: int) -> void:
	if idx < enemy_panels.size():
		enemy_panels[idx].modulate = Color(0.3, 0.3, 0.3, 0.5)
	if idx < target_buttons.size():
		target_buttons[idx].visible = false

func _on_enemy_hp_changed(idx: int, hp: int, max_hp: int) -> void:
	if idx < hp_labels.size():
		hp_labels[idx].text = "HP: %d/%d" % [hp, max_hp]

func _on_enemy_block_changed(idx: int, block: int) -> void:
	if idx < block_labels.size():
		block_labels[idx].text = "ブロック: %d" % block if block > 0 else ""

func _on_enemy_intent_updated(idx: int, intent: Dictionary) -> void:
	if idx < intent_labels.size():
		var label: Label = intent_labels[idx]
		var intent_type: String = intent.get("type", "")
		var intent_label_text: String = intent.get("label", "")
		var val: int = intent.get("value", 0)
		match intent_type:
			"attack":
				label.text = "⚔ %s (%d)" % [intent_label_text, val]
				label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			"defend":
				label.text = "🛡 %s (%d)" % [intent_label_text, val]
				label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
			_:
				label.text = "? %s" % intent_label_text

func _on_player_hp_changed(hp: int, max_hp: int) -> void:
	$PlayerHUD/HPLabel.text = "HP: %d/%d" % [hp, max_hp]
	$PlayerHUD/HPBar.value = hp

func _on_player_block_changed(block: int) -> void:
	$PlayerHUD/BlockLabel.text = "ブロック: %d" % block

func _on_ap_changed(new_ap: int) -> void:
	$PlayerHUD/APLabel.text = "AP: %d/%d" % [new_ap, CombatManager.max_ap]
	_update_hand()
	_update_controls()

func _on_combat_won(rewards: Array) -> void:
	_show_reward_screen(rewards)

func _on_combat_lost() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main/game_over.tscn")

func _on_player_fled() -> void:
	_return_to_map()

func _show_reward_screen(rewards: Array) -> void:
	for child in $HandArea.get_children():
		child.queue_free()
	_update_controls()

	var reward_panel := PanelContainer.new()
	reward_panel.name = "RewardPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	reward_panel.add_theme_stylebox_override("panel", style)
	reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	reward_panel.custom_minimum_size = Vector2(700, 400)
	reward_panel.offset_left = -350
	reward_panel.offset_top = -200
	reward_panel.offset_right = 350
	reward_panel.offset_bottom = 200

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)

	var title_label := Label.new()
	title_label.text = "勝利！"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	vbox.add_child(title_label)

	var card_label := Label.new()
	card_label.text = "報酬を1つ選択（スキップ可）:"
	card_label.add_theme_font_size_override("font_size", 16)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(card_label)

	var choice_hbox := HBoxContainer.new()
	choice_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_hbox.add_theme_constant_override("separation", 10)

	var pool := CardDatabase.get_reward_pool(GameManager.current_act, GameManager.current_character.id)
	pool.shuffle()
	var pool_idx := 0
	for reward: Dictionary in rewards:
		match reward.get("type", "card"):
			"fuel":
				var amount: int = reward.get("amount", 0)
				var fuel_btn := _create_fuel_reward_button(amount)
				fuel_btn.pressed.connect(_on_reward_fuel_picked.bind(amount))
				choice_hbox.add_child(fuel_btn)
			_:
				if pool_idx < pool.size():
					var card: CardData = pool[pool_idx]
					pool_idx += 1
					var btn := _create_card_button(card)
					btn.disabled = false
					btn.pressed.connect(_on_reward_card_picked.bind(card))
					choice_hbox.add_child(btn)
	vbox.add_child(choice_hbox)

	var skip_btn := Button.new()
	skip_btn.text = "スキップ"
	skip_btn.custom_minimum_size = Vector2(200, 40)
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_return_to_map)
	vbox.add_child(skip_btn)

	reward_panel.add_child(vbox)
	add_child(reward_panel)
	awaiting_reward = true

func _create_fuel_reward_button(amount: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 190)
	btn.text = "燃料\n+%d" % amount
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.25, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.6, 0.4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _on_reward_fuel_picked(amount: int) -> void:
	ResourceManager.add_fuel(amount)
	_return_to_map()

func _on_reward_card_picked(card: CardData) -> void:
	DeckManager.add_card_to_deck(card)
	_return_to_map()

func _return_to_map() -> void:
	CombatManager.state = CombatManager.CombatState.INACTIVE
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
