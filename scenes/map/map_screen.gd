extends Control

var map_nodes: Array[Dictionary] = []
var current_row: int = -1
var node_buttons: Dictionary = {}
var _pending_act_intro: bool = false

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
	if _pending_act_intro:
		_pending_act_intro = false
		_show_notification("区間 %d に進んだ。\n新たな勢力圏が待つ――" % GameManager.current_act)

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
		var fuel_reward: int = int(node.get("fuel_reward", 0))
		btn.text = _get_node_button_text(node_type, fuel_reward)
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
	for nid: String in node_buttons:
		var btn: Button = node_buttons[nid]
		btn.disabled = true

	if current_row == -1:
		var first_row := MapGenerator._get_nodes_at_row(map_nodes, 0)
		for node: Dictionary in first_row:
			var nid := _node_id(node)
			if nid in node_buttons:
				node_buttons[nid].disabled = false
		return

	for node: Dictionary in map_nodes:
		if node["row"] != current_row or not node["visited"]:
			continue
		for conn_id: String in node["connections"]:
			var target := _find_node_by_id(conn_id)
			if not target.is_empty() and not target["visited"]:
				if conn_id in node_buttons:
					node_buttons[conn_id].disabled = false

func _on_node_pressed(nid: String) -> void:
	var node := _find_node_by_id(nid)
	if node.is_empty():
		return
	var previous_node := _get_current_map_node()
	var travel_cost := _get_travel_cost(previous_node, node)
	if not ResourceManager.consume_fuel(travel_cost):
		_show_notification("%sが足りない。\n必要: %d / 現在: %d" % [_get_travel_resource_name(), travel_cost, ResourceManager.fuel])
		return

	node["visited"] = true
	current_row = node["row"]
	GameManager.map_current_row = current_row
	GameManager.map_current_node_id = nid
	GameManager.advance_node(travel_cost)
	var fuel_reward: int = int(node.get("fuel_reward", 0))
	if fuel_reward > 0:
		ResourceManager.add_fuel(fuel_reward)
		node["fuel_reward"] = 0
		_show_notification("%sを発見した。\n+%d" % [_get_travel_resource_name(), fuel_reward])
	SaveManager.save_run()
	_update_hud()

	if GameManager.pursuit_triggered:
		GameManager.pursuit_triggered = false
		_enter_pursuit_combat()
		return

	var node_type: MapGenerator.NodeType = node["type"]
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
		var mod := QuestManager.get_boss_modifier(GameManager.current_act)
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
			var mod := QuestManager.get_boss_modifier(act)
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

func _update_hud() -> void:
	$HUD/FuelLabel.text = "%s: %d/%d" % [_get_travel_resource_name(), ResourceManager.fuel, ResourceManager.tank_capacity]
	$HUD/ScrapLabel.text = "スクラップ: %d" % ResourceManager.scrap
	$HUD/MedicineLabel.text = "医薬品: %d/%d" % [ResourceManager.medicine, ResourceManager.medicine_max]
	$HUD/BikeDurabilityLabel.text = "耐久: %d/%d" % [ResourceManager.bike_durability, ResourceManager.bike_max_durability]
	$HUD/KarmaLabel.text = "カルマ: %d %s" % [KarmaManager.karma, KarmaManager.get_band_display()]
	$HUD/DistanceLabel.text = "走行: %dkm" % GameManager.distance_km
	$HUD/ActLabel.text = "区間%d" % GameManager.current_act
	$HUD/QuestLabel.text = QuestManager.get_hud_summary()
	if GameManager.current_companion != null:
		$HUD/CompanionLabel.text = "同行者: %s (%dノード)" % [GameManager.current_companion.display_name, GameManager.companion_nodes_remaining]
	else:
		$HUD/CompanionLabel.text = "同行者: なし"
	if GameManager.current_character != null and GameManager.current_character.unique_system == &"heat":
		$HUD/CompanionLabel.text += "  追跡: %d%%" % GameManager.pursuit_level
	if GameManager.is_cultist():
		$HUD/CompanionLabel.text += "  信仰: %s" % GameManager.get_faith_display()

func _on_fuel_changed(_val: int, _max_val: int) -> void:
	_update_hud()

func _on_bike_durability_changed(_val: int, _max_val: int) -> void:
	_update_hud()

func _show_notification(text: String) -> void:
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
	close_btn.pressed.connect(panel.queue_free)
	panel.add_child(close_btn)
	add_child(panel)

func _get_current_map_node() -> Dictionary:
	if GameManager.map_current_node_id.is_empty():
		return {}
	return _find_node_by_id(GameManager.map_current_node_id)

func _get_travel_cost(from_node: Dictionary, to_node: Dictionary) -> int:
	return MapGenerator.calculate_travel_cost(from_node, to_node, GameManager.current_companion != null)

func _get_node_button_text(node_type: MapGenerator.NodeType, fuel_reward: int) -> String:
	var icon := MapGenerator.get_node_type_icon(node_type)
	if fuel_reward > 0:
		return "%s+%d\n%s" % [_get_travel_resource_icon(), fuel_reward, icon]
	return icon

func _get_node_tooltip(node: Dictionary, fuel_reward: int) -> String:
	var parts: Array[String] = [MapGenerator.get_node_type_name(node["type"])]
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

func _apply_border(style: StyleBoxFlat) -> void:
	style.border_color = Color.WHITE
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3

func _node_id(node: Dictionary) -> String:
	return "%d_%d" % [node["row"], node["col"]]

func _find_node_by_id(nid: String) -> Dictionary:
	for node: Dictionary in map_nodes:
		if _node_id(node) == nid:
			return node
	return {}
