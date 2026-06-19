extends Control

var map_nodes: Array[Dictionary] = []
var current_row: int = -1
var node_buttons: Dictionary = {}

func _ready() -> void:
	if GameManager.map_nodes.is_empty():
		GameManager.map_nodes = MapGenerator.generate_act(GameManager.current_act)
		GameManager.map_current_row = -1
	map_nodes = GameManager.map_nodes
	current_row = GameManager.map_current_row
	_draw_map()
	_update_hud()
	ResourceManager.fuel_changed.connect(_on_fuel_changed)

func _draw_map() -> void:
	for child in $MapScroll/MapContainer.get_children():
		child.queue_free()
	node_buttons.clear()

	var lines_node := Control.new()
	lines_node.name = "Lines"
	lines_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	$MapScroll/MapContainer.add_child(lines_node)

	for node: Dictionary in map_nodes:
		var btn := Button.new()
		var node_type: MapGenerator.NodeType = node["type"]
		btn.text = MapGenerator.get_node_type_icon(node_type)
		btn.tooltip_text = MapGenerator.get_node_type_name(node_type)
		btn.custom_minimum_size = Vector2(50, 50)
		btn.position = node["position"] - Vector2(25, 25)
		var style := StyleBoxFlat.new()
		style.bg_color = MapGenerator.get_node_type_color(node_type)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover_style)
		var pressed_style := style.duplicate()
		pressed_style.bg_color = style.bg_color.darkened(0.2)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_font_size_override("font_size", 22)

		var nid := _node_id(node)
		btn.pressed.connect(_on_node_pressed.bind(nid))
		$MapScroll/MapContainer.add_child(btn)
		node_buttons[nid] = btn

		if node["visited"]:
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

	node["visited"] = true
	current_row = node["row"]
	GameManager.map_current_row = current_row
	GameManager.advance_node()
	_update_hud()

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
	CombatManager.start_combat(enemies)
	get_tree().change_scene_to_file("res://scenes/combat/combat_screen.tscn")

func _get_enemies_for_node(node_type: MapGenerator.NodeType) -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	match node_type:
		MapGenerator.NodeType.COMBAT:
			var roll := randf()
			if roll < 0.4:
				enemies.append(_make_enemy(&"devilwolf", "デビルフ", EnemyData.Category.BEAST, 28))
			elif roll < 0.7:
				enemies.append(_make_enemy(&"bandit", "荒野の盗賊", EnemyData.Category.HUMAN, 35))
			else:
				for i in 3:
					enemies.append(_make_enemy(&"wild_dog", "野犬", EnemyData.Category.BEAST, 15))
		MapGenerator.NodeType.ELITE:
			var roll := randf()
			if roll < 0.5:
				enemies.append(_make_enemy(&"devilwolf_leader", "デビルフの群れリーダー", EnemyData.Category.BEAST, 65, true))
			else:
				enemies.append(_make_enemy(&"rogue_rider", "ならず者ライダー", EnemyData.Category.HUMAN, 55, true))
		MapGenerator.NodeType.BOSS:
			var boss := _make_enemy(&"alpha_devilwolf", "アルファ・デビルフ", EnemyData.Category.BEAST, 150, false, true)
			enemies.append(boss)
	return enemies

func _make_enemy(id: StringName, display: String, cat: EnemyData.Category, hp: int, elite: bool = false, boss: bool = false) -> EnemyData:
	var e := EnemyData.new()
	e.id = id
	e.display_name = display
	e.category = cat
	e.base_hp = hp
	e.is_elite = elite
	e.is_boss = boss
	e.act = GameManager.current_act
	return e

func _enter_event() -> void:
	get_tree().change_scene_to_file("res://scenes/event/event_screen.tscn")

func _enter_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop/shop_screen.tscn")

func _enter_rest() -> void:
	get_tree().change_scene_to_file("res://scenes/rest/rest_screen.tscn")

func _enter_info() -> void:
	_show_notification("オアシスの噂を聞いた…\n「東に楽園があるらしい」")
	_draw_map()

func _update_hud() -> void:
	$HUD/FuelLabel.text = "燃料: %d/%d" % [ResourceManager.fuel, ResourceManager.tank_capacity]
	$HUD/ScrapLabel.text = "スクラップ: %d" % ResourceManager.scrap
	$HUD/MedicineLabel.text = "医薬品: %d/%d" % [ResourceManager.medicine, ResourceManager.medicine_max]
	$HUD/KarmaLabel.text = "カルマ: %d %s" % [KarmaManager.karma, KarmaManager.get_band_display()]
	$HUD/DistanceLabel.text = "走行: %dkm" % GameManager.distance_km
	$HUD/ActLabel.text = "区間%d" % GameManager.current_act

func _on_fuel_changed(_val: int, _max_val: int) -> void:
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

func _node_id(node: Dictionary) -> String:
	return "%d_%d" % [node["row"], node["col"]]

func _find_node_by_id(nid: String) -> Dictionary:
	for node: Dictionary in map_nodes:
		if _node_id(node) == nid:
			return node
	return {}
