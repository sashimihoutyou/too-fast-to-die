extends SceneTree

const DataAuditScript := preload("res://tools/sim/data_audit.gd")
const BattleAgentScript := preload("res://tools/sim/battle_agent.gd")

const DEFAULT_RUNS := 10

# --script モードではAutoloadグローバルがコンパイル時に解決されない。
# 同名のインスタンス変数を定義し、_process 内で root.get_node() により解決する。
var GameManager
var CombatManager
var DeckManager
var ResourceManager
var QuestManager
var ItemDatabase
var CardDatabase
var EnemyDatabase
var KarmaManager

var _args: Dictionary = {}

func _init() -> void:
	_parse_args()

func _process(_delta: float) -> bool:
	_resolve_autoloads()
	_run()
	quit()
	return true

func _resolve_autoloads() -> void:
	GameManager = root.get_node("GameManager")
	CombatManager = root.get_node("CombatManager")
	DeckManager = root.get_node("DeckManager")
	ResourceManager = root.get_node("ResourceManager")
	QuestManager = root.get_node("QuestManager")
	ItemDatabase = root.get_node("ItemDatabase")
	CardDatabase = root.get_node("CardDatabase")
	EnemyDatabase = root.get_node("EnemyDatabase")
	KarmaManager = root.get_node("KarmaManager")

func _run() -> void:
	var character_id: StringName = StringName(_args.get("character", "ex_raider"))
	var run_count: int = int(_args.get("runs", str(DEFAULT_RUNS)))
	var seed_val: int = int(_args.get("seed", "0"))
	var report_path: String = _args.get("report", "")

	print("=== 擬似テストプレイシミュレーター ===")
	print("キャラクター: %s / ラン数: %d / シード: %d" % [character_id, run_count, seed_val])

	# データ監査
	var audit: RefCounted = DataAuditScript.new(CardDatabase, EnemyDatabase, GameManager)
	audit.run_all()
	print("")
	print(audit.get_report_text())

	# キャラクター読み込み
	var character: CharacterData = _load_character(character_id)
	if character == null:
		print("[FATAL] キャラクター '%s' が見つからない" % character_id)
		return

	# シミュレーション実行
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	var run_results: Array[Dictionary] = []
	for run_idx in run_count:
		var run_seed: int = rng.randi()
		var result := _simulate_run(character, run_seed)
		result["run_index"] = run_idx
		result["seed"] = run_seed
		run_results.append(result)
		var status: String = "CLEAR" if result["cleared"] else "DEFEAT(Act%d)" % result["reached_act"]
		print("  Run %d: %s | HP %d/%d | 戦闘数 %d | ターン合計 %d" % [
			run_idx + 1, status,
			result["final_hp"], result["max_hp"],
			result["battles_fought"], result["total_turns"],
		])

	# レポート生成
	var report := _generate_report(character, run_results, audit)
	print("")
	print(report)

	if not report_path.is_empty():
		var dir_path := report_path.get_base_dir()
		if not dir_path.is_empty():
			DirAccess.make_dir_recursive_absolute(dir_path)
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f != null:
			f.store_string(report)
			f.close()
			print("\nレポート出力: %s" % report_path)
		else:
			print("\n[ERROR] レポート出力失敗: %s" % report_path)

	# JSON出力
	if not report_path.is_empty():
		var json_path := report_path.get_basename() + ".json"
		var json_data := _build_json(character, run_results, audit)
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(json_data, "  "))
			f.close()
			print("JSON出力: %s" % json_path)

func _simulate_run(character: CharacterData, run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed

	GameManager.start_run(character)
	GameManager.dismiss_companion()

	_assign_random_relics(rng)

	var battles_fought: int = 0
	var total_turns: int = 0
	var total_damage_taken: int = 0
	var total_cards_played: int = 0
	var battle_logs: Array[Dictionary] = []

	var max_act: int = GameManager.MAX_ACT
	for act in range(1, max_act + 1):
		GameManager.current_act = act
		var map := MapGenerator.generate_act(act, rng.randi())
		GameManager.map_nodes = map
		GameManager.map_current_row = -1

		var path := _pick_map_path(map, rng)
		var previous_node: Dictionary = {}

		for node: Dictionary in path:
			var travel_cost := MapGenerator.calculate_travel_cost(previous_node, node, false)
			if not ResourceManager.consume_fuel(travel_cost):
				var penalty: int = travel_cost * 3
				CombatManager.player_hp = maxi(1, CombatManager.player_hp - penalty)
			GameManager.advance_node(travel_cost)

			var fuel_reward: int = int(node.get("fuel_reward", 0))
			if fuel_reward > 0:
				ResourceManager.add_fuel(fuel_reward)

			var node_type: MapGenerator.NodeType = node["type"]
			match node_type:
				MapGenerator.NodeType.COMBAT, MapGenerator.NodeType.ELITE, MapGenerator.NodeType.BOSS:
					var enemies := _get_enemies_for_node(node_type, act, rng)
					var boss_hp_scale := 1.0
					if node_type == MapGenerator.NodeType.BOSS:
						var mod: Dictionary = QuestManager.get_boss_modifier(act)
						boss_hp_scale = float(mod.get("hp_scale", 1.0))
					var agent: RefCounted = BattleAgentScript.new(CombatManager, DeckManager, rng)
					var hp_before: int = CombatManager.player_hp
					var result: Dictionary = agent.fight(enemies, boss_hp_scale)
					battles_fought += 1
					total_turns += result["turns"]
					total_damage_taken += maxi(0, hp_before - result["player_hp"])
					for entry: Dictionary in result["log"]:
						if entry.get("action", "") == "play":
							total_cards_played += 1
					battle_logs.append({
						"act": act,
						"type": MapGenerator.get_node_type_name(node_type),
						"won": result["won"],
						"turns": result["turns"],
						"hp_before": hp_before,
						"hp_after": result["player_hp"],
					})

					if not result["won"]:
						return {
							"cleared": false,
							"reached_act": act,
							"final_hp": 0,
							"max_hp": CombatManager.player_max_hp,
							"battles_fought": battles_fought,
							"total_turns": total_turns,
							"total_damage_taken": total_damage_taken,
							"total_cards_played": total_cards_played,
							"battle_logs": battle_logs,
							"fuel_remaining": ResourceManager.fuel,
						}

					var act_fuel := rng.randi_range(6 + act * 2, 11 + act * 3)
					ResourceManager.add_fuel(act_fuel)
					_pick_reward_card(character, act, rng)

				MapGenerator.NodeType.REST:
					_handle_rest(rng)
				MapGenerator.NodeType.SHOP:
					_handle_shop(rng)
				MapGenerator.NodeType.EVENT:
					pass
				MapGenerator.NodeType.INFO:
					pass

			previous_node = node

			if CombatManager.player_hp <= 0:
				return {
					"cleared": false,
					"reached_act": act,
					"final_hp": 0,
					"max_hp": CombatManager.player_max_hp,
					"battles_fought": battles_fought,
					"total_turns": total_turns,
					"total_damage_taken": total_damage_taken,
					"total_cards_played": total_cards_played,
					"battle_logs": battle_logs,
					"fuel_remaining": ResourceManager.fuel,
				}

		GameManager.advance_act()

	return {
		"cleared": true,
		"reached_act": max_act,
		"final_hp": CombatManager.player_hp,
		"max_hp": CombatManager.player_max_hp,
		"battles_fought": battles_fought,
		"total_turns": total_turns,
		"total_damage_taken": total_damage_taken,
		"total_cards_played": total_cards_played,
		"battle_logs": battle_logs,
		"fuel_remaining": ResourceManager.fuel,
	}

func _pick_map_path(map_nodes: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var path: Array[Dictionary] = []
	var rows := 12

	var first_row := MapGenerator._get_nodes_at_row(map_nodes, 0)
	if first_row.is_empty():
		return path
	var current := first_row[rng.randi() % first_row.size()]
	path.append(current)

	for row in range(1, rows):
		var connections: Array = current.get("connections", [])
		if connections.is_empty():
			break
		var next_id: String = connections[rng.randi() % connections.size()]
		var found := false
		for node: Dictionary in map_nodes:
			if "%d_%d" % [node["row"], node["col"]] == next_id:
				current = node
				path.append(current)
				found = true
				break
		if not found:
			break

	return path

func _get_enemies_for_node(node_type: MapGenerator.NodeType, act: int, rng: RandomNumberGenerator) -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	match node_type:
		MapGenerator.NodeType.COMBAT:
			var pool: Array[EnemyData] = EnemyDatabase.get_enemies_for_act(act)
			if pool.is_empty():
				pool = EnemyDatabase.get_enemies_for_act(1)
			if not pool.is_empty():
				pool.shuffle()
				var roll := rng.randf()
				var count := 1
				if roll < 0.30 and pool.size() >= 3:
					count = 3
				elif roll < 0.55 and pool.size() >= 2:
					count = 2
				for i in count:
					enemies.append(pool[i % pool.size()])
		MapGenerator.NodeType.ELITE:
			var elites: Array[EnemyData] = EnemyDatabase.get_elites_for_act(act)
			if elites.is_empty():
				elites = EnemyDatabase.get_elites_for_act(1)
			if not elites.is_empty():
				elites.shuffle()
				enemies.append(elites[0])
		MapGenerator.NodeType.BOSS:
			var boss := _get_boss_for_act(act)
			if boss != null:
				enemies.append(boss)
			var mod: Dictionary = QuestManager.get_boss_modifier(act)
			var adds: int = int(mod.get("adds", 0))
			var add_id: StringName = mod.get("add_enemy", &"")
			if adds > 0 and add_id != &"":
				var add_enemy: EnemyData = EnemyDatabase.get_enemy(add_id)
				if add_enemy != null:
					for i in adds:
						enemies.append(add_enemy)

	if enemies.is_empty():
		var fallback := EnemyData.new()
		fallback.id = &"wasteland_threat"
		fallback.display_name = "荒野の脅威"
		fallback.category = EnemyData.Category.HUMAN
		fallback.base_hp = 30 + act * 10
		fallback.act = act
		enemies.append(fallback)

	return enemies

func _get_boss_for_act(act: int) -> EnemyData:
	var max_act: int = GameManager.MAX_ACT
	if act >= max_act:
		var boss_map := {
			&"cultist": &"v8cult_high_priest",
			&"ex_raider": &"cockatrice_boss",
			&"wanderer": &"chainlink_informant",
			&"beast_master": &"chainlink_executive",
			&"conqueror": &"gatekeeper",
			&"hedonist": &"neon_eden_queen",
		}
		var char_id: StringName = GameManager.current_character.id
		var boss_id: StringName = boss_map.get(char_id, &"")
		if boss_id != &"":
			var boss: EnemyData = EnemyDatabase.get_enemy(boss_id)
			if boss != null:
				return boss
	return EnemyDatabase.get_boss_for_act(act)

func _assign_random_relics(rng: RandomNumberGenerator) -> void:
	var all_relics: Array[ItemData] = ItemDatabase.get_items_by_type(ItemData.ItemType.RELIC)
	if all_relics.is_empty():
		return
	all_relics.shuffle()
	var count := rng.randi_range(0, mini(2, all_relics.size()))
	for i in count:
		ItemDatabase.add_to_inventory(all_relics[i].id)

func _pick_reward_card(character: CharacterData, act: int, rng: RandomNumberGenerator) -> void:
	var pool: Array[CardData] = CardDatabase.get_reward_pool(act, character.id)
	if pool.is_empty():
		return
	pool.shuffle()
	var candidates: Array[CardData] = []
	for i in mini(3, pool.size()):
		candidates.append(pool[i])
	var best: CardData = candidates[0]
	var best_score: int = _card_score(best)
	for i in range(1, candidates.size()):
		var score := _card_score(candidates[i])
		if score > best_score:
			best = candidates[i]
			best_score = score
	if character.deck_limit > 0 and DeckManager.master_deck.size() >= character.deck_limit:
		return
	DeckManager.add_card_to_deck(best)

func _card_score(card: CardData) -> int:
	var score: int = card.get_effective_damage() * card.hit_count
	score += card.get_effective_block()
	if card.draw_count > 0:
		score += 3
	if card.bonus_ap > 0:
		score += 4
	if card.restriction != CardData.CharacterRestriction.NONE:
		score += 2
	return score

func _handle_rest(rng: RandomNumberGenerator) -> void:
	var hp_pct := float(CombatManager.player_hp) / float(CombatManager.player_max_hp)
	if hp_pct < 0.6:
		var heal := ceili(float(CombatManager.player_max_hp) * 0.3)
		CombatManager.player_hp = mini(CombatManager.player_hp + heal, CombatManager.player_max_hp)
	else:
		var upgradeable: Array[CardData] = []
		for card: CardData in DeckManager.master_deck:
			if not card.upgraded:
				upgradeable.append(card)
		if not upgradeable.is_empty():
			var card: CardData = upgradeable[rng.randi() % upgradeable.size()]
			card.upgraded = true
		else:
			var heal := ceili(float(CombatManager.player_max_hp) * 0.3)
			CombatManager.player_hp = mini(CombatManager.player_hp + heal, CombatManager.player_max_hp)

func _handle_shop(rng: RandomNumberGenerator) -> void:
	if ResourceManager.scrap >= 5 and ResourceManager.fuel < ResourceManager.tank_capacity - 5:
		ResourceManager.consume_scrap(5)
		ResourceManager.add_fuel(8)

func _generate_report(character: CharacterData, results: Array[Dictionary], audit: RefCounted) -> String:
	var lines: Array[String] = []
	lines.append("# 擬似テストプレイ レポート")
	lines.append("")
	lines.append("- キャラクター: %s (%s)" % [character.display_name, character.id])
	lines.append("- ラン数: %d" % results.size())
	lines.append("- 日時: %s" % Time.get_datetime_string_from_system())
	lines.append("")

	lines.append("## データ監査")
	lines.append("- エラー: %d 件" % audit.errors.size())
	lines.append("- 警告: %d 件" % audit.warnings.size())
	for e: Dictionary in audit.errors:
		lines.append("  - [ERROR] %s: %s" % [e["source"], e["message"]])
	for w: Dictionary in audit.warnings:
		lines.append("  - [WARN] %s: %s" % [w["source"], w["message"]])
	lines.append("")

	var clears: int = 0
	var total_hp: int = 0
	var total_battles: int = 0
	var total_turns: int = 0
	var total_damage: int = 0
	var total_cards: int = 0
	var act_reached: Array[int] = []
	var fuel_remaining_sum: int = 0

	for r: Dictionary in results:
		if r["cleared"]:
			clears += 1
		total_hp += r["final_hp"]
		total_battles += r["battles_fought"]
		total_turns += r["total_turns"]
		total_damage += r["total_damage_taken"]
		total_cards += r["total_cards_played"]
		act_reached.append(r["reached_act"])
		fuel_remaining_sum += int(r.get("fuel_remaining", 0))

	var n := results.size()
	lines.append("## 総合結果")
	lines.append("| 指標 | 値 |")
	lines.append("|---|---|")
	lines.append("| クリア率 | %d/%d (%.1f%%) |" % [clears, n, float(clears) / float(n) * 100.0])
	lines.append("| 平均到達Act | %.1f |" % [_avg_arr(act_reached)])
	lines.append("| 平均残HP | %.1f |" % [float(total_hp) / float(n)])
	lines.append("| 平均戦闘数 | %.1f |" % [float(total_battles) / float(n)])
	lines.append("| 平均ターン数 | %.1f |" % [float(total_turns) / float(n)])
	lines.append("| 平均被ダメージ | %.1f |" % [float(total_damage) / float(n)])
	lines.append("| 平均使用カード数 | %.1f |" % [float(total_cards) / float(n)])
	lines.append("| 平均残燃料 | %.1f |" % [float(fuel_remaining_sum) / float(n)])
	lines.append("")

	lines.append("## ラン別詳細")
	lines.append("| # | Seed | 結果 | 到達Act | 残HP | 戦闘数 | ターン | 残燃料 |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for r: Dictionary in results:
		var status: String = "CLEAR" if r["cleared"] else "DEFEAT"
		lines.append("| %d | %d | %s | %d | %d/%d | %d | %d | %d |" % [
			r["run_index"] + 1, r["seed"], status,
			r["reached_act"], r["final_hp"], r["max_hp"],
			r["battles_fought"], r["total_turns"],
			int(r.get("fuel_remaining", 0)),
		])

	return "\n".join(lines)

func _build_json(character: CharacterData, results: Array[Dictionary], audit: RefCounted) -> Dictionary:
	var clears: int = 0
	for r: Dictionary in results:
		if r["cleared"]:
			clears += 1
	return {
		"character_id": str(character.id),
		"character_name": character.display_name,
		"run_count": results.size(),
		"clear_count": clears,
		"clear_rate": float(clears) / float(results.size()),
		"audit_errors": audit.errors.size(),
		"audit_warnings": audit.warnings.size(),
		"runs": results,
	}

func _avg_arr(arr: Array[int]) -> float:
	if arr.is_empty():
		return 0.0
	var total: int = 0
	for v: int in arr:
		total += v
	return float(total) / float(arr.size())

func _load_character(id: StringName) -> CharacterData:
	var dir := DirAccess.open("res://resources/characters")
	if dir == null:
		return null
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var ch: CharacterData = load("res://resources/characters/" + fname)
			if ch != null and ch.id == id:
				return ch
		fname = dir.get_next()
	return null

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		if arg.begins_with("--") and i + 1 < args.size():
			_args[arg.substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
