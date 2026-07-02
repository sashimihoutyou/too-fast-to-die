extends Control

var map_nodes: Array[Dictionary] = []
var current_row: int = -1
var node_buttons: Dictionary = {}
var _pending_act_intro: bool = false
var _awaiting_fragment: bool = false

func _ready() -> void:
	if _handle_post_boss():
		return
	if GameManager.map_nodes.is_empty():
		GameManager.map_nodes = MapGenerator.generate_act(GameManager.current_act)
		GameManager.map_current_row = -1
	map_nodes = GameManager.map_nodes
	current_row = GameManager.map_current_row
	_draw_map()
	_update_hud()
	ResourceManager.fuel_changed.connect(_on_fuel_changed)
	ResourceManager.bike_durability_changed.connect(_on_bike_durability_changed)
	$HUD/DeckButton.pressed.connect(_show_deck_popup)
	$HUD/MedicineButton.pressed.connect(_use_medicine)
	$HUD/CompanionButton.pressed.connect(_show_dismiss_dialog)
	if _pending_act_intro:
		_pending_act_intro = false
		_show_notification_then("区間 %d に進んだ。\n複数の旗が同じ道を奪い合っている――" % GameManager.current_act, func() -> void:
			_show_pending_companion_notifications(Callable(self, "_show_pending_companion_prompts"))
		)
	else:
		_show_pending_companion_notifications(Callable(self, "_show_pending_companion_prompts"))

# ボス撃破後にこの画面へ戻った場合の処理。
# 最終区間ならクリア画面へ、そうでなければ次の区間へ進める。
# 戻り値が true のとき呼び出し元はこのフレームの描画を中止する（クリア画面へ遷移するため）。
func _handle_post_boss() -> bool:
	if not GameManager.boss_cleared:
		return false
	GameManager.boss_cleared = false
	if GameManager.current_act >= GameManager.MAX_ACT:
		GameManager.pending_result = &"victory"
		get_tree().change_scene_to_file("res://scenes/main/game_over.tscn")
		return true
	GameManager.advance_act()
	_pending_act_intro = true
	return false

func _draw_map() -> void:
	for child in $MapScroll/MapContainer.get_children():
		child.queue_free()
	node_buttons.clear()

	var lines_node := Control.new()
	lines_node.name = "Lines"
	lines_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	$MapScroll/MapContainer.add_child(lines_node)

	_draw_start_node()

	for node: Dictionary in map_nodes:
		var btn := Button.new()
		var node_type: MapGenerator.NodeType = node["type"]
		var faction: int = int(node.get("faction", MapGenerator.Faction.NONE))
		var fuel_reward: int = int(node.get("fuel_reward", 0))
		btn.text = _get_node_button_text(node_type, fuel_reward, faction)
		btn.tooltip_text = _get_node_tooltip(node, fuel_reward)
		btn.custom_minimum_size = Vector2(50, 50)
		btn.position = node["position"] - Vector2(25, 25)
		var style := StyleBoxFlat.new()
		style.bg_color = MapGenerator.get_node_type_color(node_type)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8

		var nid := _node_id(node)
		var is_current := (nid == GameManager.map_current_node_id)

		if is_current:
			_apply_border(style)
		else:
			_apply_faction_border(style, faction)

		btn.add_theme_stylebox_override("normal", style)
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover_style)
		var pressed_style: StyleBoxFlat = style.duplicate()
		pressed_style.bg_color = style.bg_color.darkened(0.2)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		var disabled_style: StyleBoxFlat = style.duplicate()
		disabled_style.bg_color = style.bg_color.darkened(0.3)
		btn.add_theme_stylebox_override("disabled", disabled_style)
		btn.add_theme_font_size_override("font_size", 22)

		btn.pressed.connect(_on_node_pressed.bind(nid))
		$MapScroll/MapContainer.add_child(btn)
		node_buttons[nid] = btn

		if node["visited"] and not is_current:
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)

	_draw_connections()
	_update_available_nodes()

func _draw_connections() -> void:
	for node: Dictionary in map_nodes:
		for conn_id: String in node["connections"]:
			var target := _find_node_by_id(conn_id)
			if target.is_empty():
				continue
			var line := Line2D.new()
			line.add_point(node["position"])
			line.add_point(target["position"])
			line.width = 2.0
			line.default_color = Color(0.4, 0.35, 0.25, 0.6)
			$MapScroll/MapContainer.add_child(line)
			$MapScroll/MapContainer.move_child(line, 0)

func _update_available_nodes() -> void:
	var available_ids: Array[String] = []

	for nid: String in node_buttons:
		var btn: Button = node_buttons[nid]
		btn.disabled = true

	if current_row == -1:
		var first_row := MapGenerator._get_nodes_at_row(map_nodes, 0)
		for node: Dictionary in first_row:
			var nid := _node_id(node)
			if nid in node_buttons:
				node_buttons[nid].disabled = false
				available_ids.append(nid)
	else:
		for node: Dictionary in map_nodes:
			if node["row"] != current_row or not node["visited"]:
				continue
			for conn_id: String in node["connections"]:
				var target := _find_node_by_id(conn_id)
				if not target.is_empty() and not target["visited"]:
					if conn_id in node_buttons:
						node_buttons[conn_id].disabled = false
						available_ids.append(conn_id)

	_apply_available_highlights(available_ids)

func _apply_available_highlights(available_ids: Array[String]) -> void:
	for nid: String in available_ids:
		var btn: Button = node_buttons[nid]
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(btn, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.5)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.5)

		var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
		style.border_color = Color(1.0, 0.9, 0.5)
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		btn.add_theme_stylebox_override("normal", style)

	_highlight_connections(available_ids)

func _highlight_connections(available_ids: Array[String]) -> void:
	if current_row == -1:
		var start_pos := Vector2(25, 480)
		for nid: String in available_ids:
			var target := _find_node_by_id(nid)
			if target.is_empty():
				continue
			var line := Line2D.new()
			line.add_point(start_pos)
			line.add_point(target["position"])
			line.width = 3.0
			line.default_color = Color(1.0, 0.9, 0.5, 0.8)
			$MapScroll/MapContainer.add_child(line)
		return

	for node: Dictionary in map_nodes:
		if node["row"] != current_row or not node["visited"]:
			continue
		for conn_id: String in node["connections"]:
			if conn_id not in available_ids:
				continue
			var target := _find_node_by_id(conn_id)
			if target.is_empty():
				continue
			var line := Line2D.new()
			line.add_point(node["position"])
			line.add_point(target["position"])
			line.width = 3.0
			line.default_color = Color(1.0, 0.9, 0.5, 0.8)
			$MapScroll/MapContainer.add_child(line)

func _on_node_pressed(nid: String) -> void:
	if _awaiting_fragment:
		return
	var node: Dictionary = _find_node_by_id(nid)
	if node.is_empty():
		return
	_awaiting_fragment = true
	var previous_node: Dictionary = _get_current_map_node()
	var travel_cost: int = _get_travel_cost(previous_node, node)
	if not ResourceManager.consume_fuel(travel_cost):
		_awaiting_fragment = false
		_show_notification("%sが足りない。\n必要: %d / 現在: %d" % [_get_travel_resource_name(), travel_cost, ResourceManager.fuel])
		return

	node["visited"] = true
	current_row = node["row"]
	GameManager.map_current_row = current_row
	GameManager.map_current_node_id = nid
	GameManager.advance_node(travel_cost)
	var node_type: MapGenerator.NodeType = node["type"]
	var fuel_reward: int = int(node.get("fuel_reward", 0))
	var fuel_message: String = ""
	if fuel_reward > 0:
		ResourceManager.add_fuel(fuel_reward)
		node["fuel_reward"] = 0
		fuel_message = "%s +%d" % [_get_travel_resource_name(), fuel_reward]
		_show_notification("%sを発見した。\n+%d" % [_get_travel_resource_name(), fuel_reward])
	SaveManager.save_run()
	_update_hud()

	var proceed: Callable = Callable(self, "_process_node_type").bind(node_type)
	_show_pending_companion_notifications(func() -> void:
		_show_pending_companion_prompts(func() -> void:
			if GameManager.pursuit_triggered:
				GameManager.pursuit_triggered = false
				AmbientFragment.consume_transient_context()
				_show_notification_then("追跡部隊が現れた。", Callable(self, "_start_pursuit_combat"))
				return
			if fuel_message != "":
				_show_notification_then(fuel_message, Callable(self, "_maybe_show_ambient_fragment").bind(node_type, proceed))
			else:
				_maybe_show_ambient_fragment(node_type, proceed)
		)
	)

func _maybe_show_ambient_fragment(node_type: MapGenerator.NodeType, on_done: Callable) -> void:
	var fragment: Dictionary = AmbientFragment.pick(node_type)
	AmbientFragment.consume_transient_context()
	if fragment.is_empty():
		_awaiting_fragment = false
		on_done.call()
		return
	AmbientFragment.mark_seen(fragment)
	_show_ambient_fragment(fragment, func() -> void:
		_awaiting_fragment = false
		on_done.call()
	)

func _process_node_type(node_type: MapGenerator.NodeType) -> void:
	match node_type:
		MapGenerator.NodeType.COMBAT, MapGenerator.NodeType.ELITE, MapGenerator.NodeType.BOSS:
			_enter_combat(node_type)
		MapGenerator.NodeType.EVENT:
			_enter_event()
		MapGenerator.NodeType.SHOP:
			_enter_shop()
		MapGenerator.NodeType.REST:
			_enter_rest()
		MapGenerator.NodeType.INFO:
			_enter_info()

func _enter_combat(node_type: MapGenerator.NodeType) -> void:
	var enemies := _get_enemies_for_node(node_type)
	var boss_hp_scale := 1.0
	if node_type == MapGenerator.NodeType.BOSS:
		var boss_id: StringName = &""
		if not enemies.is_empty():
			var boss: EnemyData = enemies[0]
			boss_id = boss.id
		var mod := QuestManager.get_boss_modifier(GameManager.current_act, boss_id)
		boss_hp_scale = float(mod.get("hp_scale", 1.0))
	CombatManager.start_combat(enemies, boss_hp_scale)
	get_tree().change_scene_to_file("res://scenes/combat/combat_screen.tscn")

func _get_enemies_for_node(node_type: MapGenerator.NodeType) -> Array[EnemyData]:
	var act := GameManager.current_act
	var enemies: Array[EnemyData] = []
	match node_type:
		MapGenerator.NodeType.COMBAT:
			var pool := EnemyDatabase.get_enemies_for_act(act)
			if pool.is_empty():
				pool = EnemyDatabase.get_enemies_for_act(1)
			if pool.is_empty():
				enemies.append(_fallback_enemy(act, false, false))
				return enemies
			pool.shuffle()
			var count := 1
			var roll := randf()
			if roll < 0.30 and pool.size() >= 3:
				count = 3
			elif roll < 0.55 and pool.size() >= 2:
				count = 2
			for i in count:
				enemies.append(pool[i % pool.size()])
		MapGenerator.NodeType.ELITE:
			var elites := EnemyDatabase.get_elites_for_act(act)
			if elites.is_empty():
				elites = EnemyDatabase.get_elites_for_act(1)
			if elites.is_empty():
				enemies.append(_fallback_enemy(act, true, false))
			else:
				elites.shuffle()
				enemies.append(elites[0])
		MapGenerator.NodeType.BOSS:
			var boss: EnemyData = _get_boss_for_current_act(act)
			if boss == null:
				boss = _fallback_enemy(act, false, true)
			enemies.append(boss)
			# サブストーリーのアウトカムに応じてボスに取り巻きを追加する。
			var mod := QuestManager.get_boss_modifier(act, boss.id)
			var adds: int = int(mod.get("adds", 0))
			var add_id: StringName = mod.get("add_enemy", &"")
			if adds > 0 and add_id != &"":
				var add_enemy := EnemyDatabase.get_enemy(add_id)
				if add_enemy != null:
					for i in adds:
						enemies.append(add_enemy)
	return enemies

# 最終区間（区間5）のボスはGDD通りプレイキャラ固有の因縁ボスにする。
func _get_boss_for_current_act(act: int) -> EnemyData:
	if act >= GameManager.MAX_ACT:
		var boss := _get_character_final_boss()
		if boss != null:
			return boss
	return EnemyDatabase.get_boss_for_act(act)

func _get_character_final_boss() -> EnemyData:
	var boss_by_character := {
		&"cultist": &"v8cult_high_priest",
		&"ex_raider": &"cockatrice_boss",
		&"wanderer": &"chainlink_informant",
		&"beast_master": &"chainlink_executive",
		&"conqueror": &"gatekeeper",
		&"hedonist": &"neon_eden_queen",
	}
	var char_id: StringName = GameManager.current_character.id
	var boss_id: StringName = boss_by_character.get(char_id, &"")
	if boss_id != &"":
		return EnemyDatabase.get_enemy(boss_id)
	return null

# DBに該当する敵が無い場合の保険。区間に応じてHPだけスケールさせた汎用敵を生成する。
func _fallback_enemy(act: int, elite: bool, boss: bool) -> EnemyData:
	var hp := 30 + act * 10
	if elite:
		hp = 60 + act * 20
	if boss:
		hp = 150 + act * 25
	return _make_enemy(&"wasteland_threat", "荒野の脅威", EnemyData.Category.HUMAN, hp, elite, boss)

func _make_enemy(id: StringName, display: String, cat: EnemyData.Category, hp: int, elite: bool = false, boss: bool = false, weaknesses: Array[CardData.Tag] = []) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.display_name = display
	e.category = cat
	e.base_hp = hp
	e.is_elite = elite
	e.is_boss = boss
	e.act = GameManager.current_act
	e.weaknesses.assign(weaknesses)
	return e

func _enter_event() -> void:
	get_tree().change_scene_to_file("res://scenes/event/event_screen.tscn")

func _enter_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop/shop_screen.tscn")

func _enter_rest() -> void:
	get_tree().change_scene_to_file("res://scenes/rest/rest_screen.tscn")

func _enter_pursuit_combat() -> void:
	_show_notification("コカトリスの追手が現れた！")
	var enemies: Array[EnemyData] = []
	var elites := EnemyDatabase.get_elites_for_act(GameManager.current_act)
	if not elites.is_empty():
		elites.shuffle()
		enemies.append(elites[0])
	else:
		enemies.append(_fallback_enemy(GameManager.current_act, true, false))
	CombatManager.start_combat(enemies)
	get_tree().change_scene_to_file("res://scenes/combat/combat_screen.tscn")

func _enter_info() -> void:
	var info_text := GameManager.advance_oasis_info()
	_show_notification("オアシスの噂を聞いた…\n%s" % info_text)
	_draw_map()

func _start_pursuit_combat() -> void:
	var enemies: Array[EnemyData] = []
	var elites := EnemyDatabase.get_elites_for_act(GameManager.current_act)
	if not elites.is_empty():
		elites.shuffle()
		enemies.append(elites[0])
	else:
		enemies.append(_fallback_enemy(GameManager.current_act, true, false))
	CombatManager.start_combat(enemies)
	get_tree().change_scene_to_file("res://scenes/combat/combat_screen.tscn")

func _update_hud() -> void:
	$HUD/FuelLabel.text = "%s: %d/%d" % [_get_travel_resource_name(), ResourceManager.fuel, ResourceManager.tank_capacity]
	$HUD/ScrapLabel.text = "スクラップ: %d" % ResourceManager.scrap
	$HUD/MedicineLabel.text = "医薬品: %d/%d" % [ResourceManager.medicine, ResourceManager.medicine_max]
	$HUD/MedicineButton.disabled = ResourceManager.medicine <= 0 or CombatManager.player_hp >= CombatManager.player_max_hp
	$HUD/BikeDurabilityLabel.text = "耐久: %d/%d" % [ResourceManager.bike_durability, ResourceManager.bike_max_durability]
	$HUD/KarmaLabel.text = "カルマ: %d %s" % [KarmaManager.karma, KarmaManager.get_band_display()]
	$HUD/DistanceLabel.text = "走行: %dkm" % GameManager.distance_km
	$HUD/ActLabel.text = "区間%d" % GameManager.current_act
	$HUD/QuestLabel.text = QuestManager.get_hud_summary()
	var companion_texts: Array[String] = []
	var companion_tooltips: Array[String] = []
	for slot: int in range(2):
		var comp: CompanionData = GameManager.get_companion_in_slot(slot)
		if comp == null:
			continue
		var remaining_text: String = GameManager.get_companion_remaining_display(slot)
		var label_text: String = "%s(%s)" % [comp.display_name, remaining_text]
		var tooltip_text: String = "%s\n希望: %s\nパッシブ: %s\nリスク: %s\n達成報酬: %s" % [comp.display_name, GameManager.get_companion_request_display(slot), comp.passive_description, comp.risk_description, comp.departure_reward_description]
		if comp.max_hp > 0:
			label_text += " HP:%d/%d" % [GameManager.get_companion_hp(slot), comp.max_hp]
			tooltip_text += "\nHP: %d/%d" % [GameManager.get_companion_hp(slot), comp.max_hp]
		if comp.companion_type == CompanionData.CompanionType.TRAITOR and GameManager.get_companion_nodes_remaining(slot) <= 1:
			label_text += " 荷物を見ている"
			tooltip_text += "\n予兆: こちらの荷物に目が行き過ぎている。"
		companion_texts.append(label_text)
		companion_tooltips.append(tooltip_text)
	if companion_texts.is_empty():
		$HUD/CompanionLabel.text = "同行者: なし"
		$HUD/CompanionLabel.tooltip_text = ""
	else:
		$HUD/CompanionLabel.text = "同行者: %s" % " / ".join(companion_texts)
		$HUD/CompanionLabel.tooltip_text = "\n\n".join(companion_tooltips)
	$HUD/CompanionButton.visible = GameManager.has_any_companion()
	if GameManager.pursuit_level > 0 or (GameManager.current_character != null and GameManager.current_character.unique_system == &"heat"):
		$HUD/CompanionLabel.text += "  追跡: %d%%" % GameManager.pursuit_level
	if GameManager.is_cultist():
		$HUD/CompanionLabel.text += "  信仰: %s" % GameManager.get_faith_display()

func _on_fuel_changed(_val: int, _max_val: int) -> void:
	_update_hud()

func _on_bike_durability_changed(_val: int, _max_val: int) -> void:
	_update_hud()

func _show_notification(text: String) -> void:
	if _awaiting_fragment:
		return
	_show_notification_then(text)

func _show_notification_then(text: String, on_close: Callable = Callable()) -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400, 200)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_top = -100
	panel.offset_right = 200
	panel.offset_bottom = 100
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	var close_btn := Button.new()
	close_btn.text = "閉じる"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.offset_left = -50
	close_btn.offset_top = -50
	close_btn.offset_right = 50
	close_btn.offset_bottom = -10
	close_btn.pressed.connect(func() -> void:
		panel.queue_free()
		if on_close.is_valid():
			on_close.call()
	)
	panel.add_child(close_btn)
	add_child(panel)

func _show_pending_companion_notifications(on_done: Callable = Callable()) -> void:
	var messages: Array[String] = GameManager.consume_companion_notifications()
	_show_companion_notification_chain(messages, 0, on_done)

func _show_companion_notification_chain(messages: Array[String], index: int, on_done: Callable) -> void:
	if index >= messages.size():
		if on_done.is_valid():
			on_done.call()
		return
	_show_notification_then(messages[index], func() -> void:
		_show_companion_notification_chain(messages, index + 1, on_done)
	)

# 定着打診→絆イベントの順で保留中の同行者プロンプトを消費する。
func _show_pending_companion_prompts(on_done: Callable = Callable()) -> void:
	var offer_slot: int = GameManager.get_pending_offer_slot()
	if offer_slot != -1:
		_show_settle_offer(offer_slot, on_done)
		return
	var bond_slot: int = GameManager.pending_bond_slot
	if bond_slot != -1 and GameManager.get_companion_in_slot(bond_slot) != null:
		_show_bond_event(bond_slot, on_done)
		return
	if on_done.is_valid():
		on_done.call()

func _show_settle_offer(slot: int, on_done: Callable) -> void:
	_show_choice_dialog(
		GameManager.get_settle_offer_text(slot),
		"",
		[
			{"label": "乗せていく", "cost": "", "disabled": false},
			{"label": "ここで別れる", "cost": "", "disabled": false},
		],
		func(choice: int) -> void:
			if choice == 0:
				GameManager.accept_settle_offer(slot)
			else:
				GameManager.decline_settle_offer(slot)
			_update_hud()
			_show_pending_companion_notifications(func() -> void:
				_show_pending_companion_prompts(on_done)
			)
	)

func _show_bond_event(slot: int, on_done: Callable) -> void:
	var can_pay: bool = ResourceManager.fuel >= GameManager.BOND_EVENT_FUEL_COST
	_show_choice_dialog(
		"",
		GameManager.get_bond_event_text(slot),
		[
			{"label": "時間を割いて付き合う", "cost": "%s -%d" % [_get_travel_resource_name(), GameManager.BOND_EVENT_FUEL_COST], "disabled": not can_pay},
			{"label": "先を急ぐ", "cost": "", "disabled": false},
		],
		func(choice: int) -> void:
			GameManager.resolve_bond_event(slot, choice == 0)
			_update_hud()
			_show_pending_companion_notifications(func() -> void:
				_show_pending_companion_prompts(on_done)
			)
	)

# 汎用の選択ダイアログ。options は {label, cost, disabled} の配列。
# コストは選択肢の文面に混ぜず、ボタン下の別ラベルとして表示する。
func _show_choice_dialog(title_text: String, body_text: String, options: Array[Dictionary], on_pick: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 320)
	panel.offset_left = -280
	panel.offset_top = -160
	panel.offset_right = 280
	panel.offset_bottom = 160
	overlay.add_child(panel)

	var title := Label.new()
	title.text = title_text
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 24
	title.offset_top = 18
	title.offset_right = -24
	title.offset_bottom = 78
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	panel.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.set_anchors_preset(Control.PRESET_TOP_WIDE)
	body.offset_left = 32
	body.offset_top = 82
	body.offset_right = -32
	body.offset_bottom = 180
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 17)
	panel.add_child(body)

	var button_row := HBoxContainer.new()
	button_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button_row.offset_left = -250
	button_row.offset_top = -110
	button_row.offset_right = 250
	button_row.offset_bottom = -20
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 24)
	panel.add_child(button_row)

	for i: int in options.size():
		var option: Dictionary = options[i]
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn := Button.new()
		btn.text = String(option.get("label", ""))
		btn.custom_minimum_size = Vector2(200, 46)
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = bool(option.get("disabled", false))
		btn.pressed.connect(func() -> void:
			overlay.queue_free()
			on_pick.call(i)
		)
		column.add_child(btn)
		var cost_text: String = String(option.get("cost", ""))
		if not cost_text.is_empty():
			var cost_label := Label.new()
			cost_label.text = cost_text
			cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cost_label.add_theme_font_size_override("font_size", 13)
			cost_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.5))
			column.add_child(cost_label)
		button_row.add_child(column)

# 同行者を下ろすダイアログ。希望進行中の相手には警告を挟む。
func _show_dismiss_dialog() -> void:
	var options: Array[Dictionary] = []
	var slots: Array[int] = []
	for slot: int in range(2):
		var comp: CompanionData = GameManager.get_companion_in_slot(slot)
		if comp == null:
			continue
		options.append({
			"label": "%sを下ろす" % comp.display_name,
			"cost": GameManager.get_companion_remaining_display(slot),
			"disabled": false,
		})
		slots.append(slot)
	if slots.is_empty():
		return
	options.append({"label": "やめる", "cost": "", "disabled": false})
	_show_choice_dialog("誰を下ろす？", "", options, func(choice: int) -> void:
		if choice >= slots.size():
			return
		_confirm_dismiss(slots[choice])
	)

func _confirm_dismiss(slot: int) -> void:
	var comp: CompanionData = GameManager.get_companion_in_slot(slot)
	if comp == null:
		return
	var warning: String = ""
	if GameManager.has_active_request(slot):
		warning = "頼みはまだ果たしていない。ここで降ろせば、それは約束を破るということだ。"
	_show_choice_dialog(
		"%sを下ろす" % comp.display_name,
		warning,
		[
			{"label": "下ろす", "cost": "", "disabled": false},
			{"label": "やめる", "cost": "", "disabled": false},
		],
		func(choice: int) -> void:
			if choice != 0:
				return
			GameManager.dismiss_companion_slot(slot)
			_update_hud()
			_show_pending_companion_notifications()
	)

func _show_ambient_fragment(fragment: Dictionary, on_close: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 420)
	panel.offset_left = -380
	panel.offset_top = -210
	panel.offset_right = 380
	panel.offset_bottom = 210
	overlay.add_child(panel)

	var title := Label.new()
	title.text = String(fragment.get("title", ""))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 28
	title.offset_top = 24
	title.offset_right = -28
	title.offset_bottom = 62
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	panel.add_child(title)

	var body := Label.new()
	body.text = String(fragment.get("body", ""))
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 46
	body.offset_top = 88
	body.offset_right = -46
	body.offset_bottom = -82
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84))
	panel.add_child(body)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.custom_minimum_size = Vector2(140, 40)
	close_btn.offset_left = -70
	close_btn.offset_top = -58
	close_btn.offset_right = 70
	close_btn.offset_bottom = -18
	close_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		on_close.call()
	)
	panel.add_child(close_btn)

func _get_current_map_node() -> Dictionary:
	if GameManager.map_current_node_id.is_empty():
		return {}
	return _find_node_by_id(GameManager.map_current_node_id)

func _get_travel_cost(from_node: Dictionary, to_node: Dictionary) -> int:
	return MapGenerator.calculate_travel_cost(from_node, to_node, GameManager.has_any_companion()) + GameManager.get_companion_extra_travel_cost()

func _get_node_button_text(node_type: MapGenerator.NodeType, fuel_reward: int, faction: int) -> String:
	var icon := MapGenerator.get_node_type_icon(node_type)
	var faction_label := MapGenerator.get_faction_short_name(faction)
	if fuel_reward > 0:
		return "%s+%d\n%s" % [_get_travel_resource_icon(), fuel_reward, faction_label]
	return "%s\n%s" % [icon, faction_label]

func _get_node_tooltip(node: Dictionary, fuel_reward: int) -> String:
	var parts: Array[String] = [MapGenerator.get_node_type_name(node["type"])]
	var faction: int = int(node.get("faction", MapGenerator.Faction.NONE))
	var site: int = int(node.get("site", MapGenerator.SiteType.WILDERNESS))
	parts.append("%s / %s" % [MapGenerator.get_faction_name(faction), MapGenerator.get_site_name(site)])
	var travel_cost := _get_travel_cost(_get_current_map_node(), node)
	parts.append("%s消費: %d" % [_get_travel_resource_name(), travel_cost])
	if fuel_reward > 0:
		parts.append("%s獲得: +%d" % [_get_travel_resource_name(), fuel_reward])
	return "\n".join(parts)

func _get_travel_resource_name() -> String:
	return GameManager.get_travel_resource_name()

func _get_travel_resource_icon() -> String:
	return GameManager.get_travel_resource_icon()

func _draw_start_node() -> void:
	var start_pos := Vector2(25, 480)
	var btn := Button.new()
	btn.text = "▶"
	btn.tooltip_text = "スタート"
	btn.custom_minimum_size = Vector2(50, 50)
	btn.position = start_pos - Vector2(25, 25)
	btn.disabled = true
	btn.add_theme_font_size_override("font_size", 22)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	if current_row == -1:
		_apply_border(style)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("disabled", style)
	$MapScroll/MapContainer.add_child(btn)

	if current_row >= 0:
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)

	var first_row := MapGenerator._get_nodes_at_row(map_nodes, 0)
	for node: Dictionary in first_row:
		var line := Line2D.new()
		line.add_point(start_pos)
		line.add_point(node["position"])
		line.width = 2.0
		line.default_color = Color(0.4, 0.35, 0.25, 0.6)
		$MapScroll/MapContainer.add_child(line)
		$MapScroll/MapContainer.move_child(line, 0)

func _show_deck_popup() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 500)
	panel.offset_left = -350
	panel.offset_top = -250
	panel.offset_right = 350
	panel.offset_bottom = 250
	overlay.add_child(panel)

	var title := Label.new()
	title.text = "デッキ (%d枚)" % DeckManager.master_deck.size()
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 35
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 45
	scroll.offset_bottom = -50
	scroll.offset_left = 10
	scroll.offset_right = -10
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	for card: CardData in DeckManager.master_deck:
		var label := Label.new()
		var parts: Array[String] = []
		parts.append(card.get_display_name())
		parts.append("AP:%d" % card.ap_cost)
		if card.get_effective_damage() > 0:
			parts.append("DMG:%d" % card.get_effective_damage())
		if card.get_effective_block() > 0:
			parts.append("BLK:%d" % card.get_effective_block())
		parts.append(card.description)
		label.text = " | ".join(parts)
		label.add_theme_font_size_override("font_size", 14)
		if card.upgraded:
			label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		vbox.add_child(label)

	var close_btn := Button.new()
	close_btn.text = "閉じる"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.custom_minimum_size = Vector2(120, 35)
	close_btn.offset_left = -60
	close_btn.offset_top = -45
	close_btn.offset_right = 60
	close_btn.offset_bottom = -10
	close_btn.pressed.connect(overlay.queue_free)
	panel.add_child(close_btn)

func _use_medicine() -> void:
	if ResourceManager.medicine <= 0:
		_show_notification("医薬品がない。")
		return
	var heal_amount := 15
	if CombatManager.player_hp >= CombatManager.player_max_hp:
		_show_notification("HPは満タンだ。")
		return
	ResourceManager.use_medicine()
	CombatManager.player_hp = mini(CombatManager.player_hp + heal_amount, CombatManager.player_max_hp)
	CombatManager.player_hp_changed.emit(CombatManager.player_hp, CombatManager.player_max_hp)
	_update_hud()
	_show_notification("医薬品を使用した。HP +%d" % heal_amount)

func _apply_border(style: StyleBoxFlat) -> void:
	style.border_color = Color.WHITE
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3

func _apply_faction_border(style: StyleBoxFlat, faction: int) -> void:
	style.border_color = MapGenerator.get_faction_color(faction)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2

func _node_id(node: Dictionary) -> String:
	return "%d_%d" % [node["row"], node["col"]]

func _find_node_by_id(nid: String) -> Dictionary:
	for node: Dictionary in map_nodes:
		if _node_id(node) == nid:
			return node
	return {}
