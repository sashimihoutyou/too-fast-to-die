class_name MapGenerator

enum NodeType { COMBAT, EVENT, SHOP, REST, INFO, ELITE, BOSS }

static func generate_act(act: int, seed_val: int = 0) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else randi()

	var nodes: Array[Dictionary] = []
	var rows := 10
	var cols := 3

	for row in rows:
		var node_count := rng.randi_range(2, cols)
		if row == 0:
			node_count = 2
		if row == rows - 1:
			node_count = 1

		for col in node_count:
			var node_type := _pick_node_type(row, rows, rng, act)
			nodes.append({
				"row": row,
				"col": col,
				"type": node_type,
				"connections": [],
				"visited": false,
				"fuel_reward": 0,
				"position": Vector2.ZERO,
			})

	_ensure_node_type_guarantees(nodes, rows, rng)
	_build_connections(nodes, rows, rng)
	_assign_positions(nodes, rows, cols)
	_assign_fuel_rewards(nodes, rng)
	return nodes

static func _pick_node_type(row: int, total_rows: int, rng: RandomNumberGenerator, _act: int) -> NodeType:
	if row == total_rows - 1:
		return NodeType.BOSS
	if row == total_rows - 2:
		return NodeType.REST
	if row == 0:
		return NodeType.COMBAT

	var roll := rng.randf()
	if row == total_rows - 3:
		if roll < 0.45:
			return NodeType.ELITE
		elif roll < 0.75:
			return NodeType.COMBAT
		elif roll < 0.88:
			return NodeType.REST
		else:
			return NodeType.INFO
	if row == 5:
		if roll < 0.4:
			return NodeType.ELITE
		elif roll < 0.7:
			return NodeType.COMBAT
		elif roll < 0.85:
			return NodeType.EVENT
		else:
			return NodeType.REST

	if roll < 0.3:
		return NodeType.COMBAT
	elif roll < 0.55:
		return NodeType.EVENT
	elif roll < 0.67:
		return NodeType.SHOP
	elif roll < 0.8:
		return NodeType.REST
	elif roll < 0.9:
		return NodeType.INFO
	else:
		return NodeType.ELITE

static func _ensure_node_type_guarantees(nodes: Array[Dictionary], total_rows: int, _rng: RandomNumberGenerator) -> void:
	var guaranteed: Array[Dictionary] = [
		{"type": NodeType.SHOP, "preferred_rows": [3, 4, 8], "min_count": 1},
		{"type": NodeType.EVENT, "preferred_rows": [2, 3, 6, 7, 8], "min_count": 3},
		{"type": NodeType.INFO, "preferred_rows": [4, 6, 8], "min_count": 1},
		{"type": NodeType.REST, "preferred_rows": [6, 7], "min_count": 1},
	]
	var fixed_rows: Array[int] = [0, total_rows - 1, total_rows - 2, total_rows - 3, 5]

	for rule: Dictionary in guaranteed:
		var target_type: NodeType = rule["type"]
		var min_count: int = rule["min_count"]
		var preferred_rows: Array = rule["preferred_rows"]

		var existing_count := 0
		for node: Dictionary in nodes:
			var nt: NodeType = node["type"]
			if nt == target_type:
				existing_count += 1

		if existing_count >= min_count:
			continue

		var needed := min_count - existing_count
		for pref_row: int in preferred_rows:
			if needed <= 0:
				break
			if pref_row in fixed_rows:
				continue
			var row_nodes := _get_nodes_at_row(nodes, pref_row)
			for node: Dictionary in row_nodes:
				var nt: NodeType = node["type"]
				if nt == NodeType.COMBAT and needed > 0:
					node["type"] = target_type
					needed -= 1
					break

static func _build_connections(nodes: Array[Dictionary], total_rows: int, rng: RandomNumberGenerator) -> void:
	for row in total_rows - 1:
		var current_row_nodes := _get_nodes_at_row(nodes, row)
		var next_row_nodes := _get_nodes_at_row(nodes, row + 1)
		if current_row_nodes.is_empty() or next_row_nodes.is_empty():
			continue
		for node: Dictionary in current_row_nodes:
			var target_idx := rng.randi() % next_row_nodes.size()
			var target_node: Dictionary = next_row_nodes[target_idx]
			var target_node_id := _node_id(target_node)
			if target_node_id not in node["connections"]:
				node["connections"].append(target_node_id)
			if next_row_nodes.size() > 1 and rng.randf() > 0.5:
				var alt_idx := (target_idx + 1) % next_row_nodes.size()
				var alt_node: Dictionary = next_row_nodes[alt_idx]
				var alt_id := _node_id(alt_node)
				if alt_id not in node["connections"]:
					node["connections"].append(alt_id)
		for next_node: Dictionary in next_row_nodes:
			var has_incoming := false
			for node: Dictionary in current_row_nodes:
				if _node_id(next_node) in node["connections"]:
					has_incoming = true
					break
			if not has_incoming:
				var source: Dictionary = current_row_nodes[rng.randi() % current_row_nodes.size()]
				source["connections"].append(_node_id(next_node))

static func _assign_positions(nodes: Array[Dictionary], total_rows: int, cols: int) -> void:
	var x_spacing := 150.0
	var y_spacing := 150.0
	for node in nodes:
		var row_nodes := _get_nodes_at_row(nodes, node["row"])
		var count := row_nodes.size()
		var idx := row_nodes.find(node)
		var y_offset := (float(idx) - float(count - 1) / 2.0) * y_spacing
		node["position"] = Vector2(100.0 + node["row"] * x_spacing, 480.0 + y_offset)

static func _assign_fuel_rewards(nodes: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for node: Dictionary in nodes:
		var node_type: NodeType = node["type"]
		if node_type == NodeType.BOSS or node_type == NodeType.REST:
			continue
		if rng.randf() < 0.22:
			node["fuel_reward"] = rng.randi_range(2, 5)

static func calculate_travel_cost(from_node: Dictionary, to_node: Dictionary, has_companion: bool) -> int:
	var from_pos := Vector2(0.0, 480.0)
	if not from_node.is_empty():
		from_pos = from_node.get("position", from_pos)
	var to_pos: Vector2 = to_node.get("position", from_pos)
	var distance_cost := ceili(from_pos.distance_to(to_pos) / 150.0)
	var cost := maxi(1, distance_cost) + 1
	if has_companion:
		cost += 1
	var _tree: SceneTree = Engine.get_main_loop() as SceneTree
	if _tree and _tree.root.has_node("ItemDatabase"):
		var _item_db = _tree.root.get_node("ItemDatabase")
		if _item_db.has_relic(&"old_compass"):
			cost = maxi(1, cost - 1)
	return cost

static func _get_nodes_at_row(nodes: Array[Dictionary], row: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for n in nodes:
		if n["row"] == row:
			result.append(n)
	return result

static func _node_id(node: Dictionary) -> String:
	return "%d_%d" % [node["row"], node["col"]]

static func get_node_type_name(t: NodeType) -> String:
	match t:
		NodeType.COMBAT: return "戦闘"
		NodeType.EVENT: return "イベント"
		NodeType.SHOP: return "ショップ"
		NodeType.REST: return "休息"
		NodeType.INFO: return "情報"
		NodeType.ELITE: return "エリート"
		NodeType.BOSS: return "ボス"
	return ""

static func get_node_type_icon(t: NodeType) -> String:
	match t:
		NodeType.COMBAT: return "⚔"
		NodeType.EVENT: return "!"
		NodeType.SHOP: return "$"
		NodeType.REST: return "🔥"
		NodeType.INFO: return "?"
		NodeType.ELITE: return "💀"
		NodeType.BOSS: return "👑"
	return ""

static func get_node_type_color(t: NodeType) -> Color:
	match t:
		NodeType.COMBAT: return Color(0.9, 0.3, 0.3)
		NodeType.EVENT: return Color(0.9, 0.9, 0.3)
		NodeType.SHOP: return Color(0.3, 0.9, 0.3)
		NodeType.REST: return Color(0.9, 0.6, 0.2)
		NodeType.INFO: return Color(0.3, 0.5, 0.9)
		NodeType.ELITE: return Color(0.7, 0.3, 0.9)
		NodeType.BOSS: return Color(0.9, 0.8, 0.2)
	return Color.WHITE
