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
var EventManager
var CompanionDatabase

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
	EventManager = root.get_node("EventManager")
	CompanionDatabase = root.get_node("CompanionDatabase")

func _run() -> void:
	var character_id: StringName = StringName(_args.get("character", "ex_raider"))
	var run_count: int = int(_args.get("runs", str(DEFAULT_RUNS)))
	var seed_val: int = int(_args.get("seed", "0"))
	var strategy: String = _args.get("strategy", "smart")
	var report_path: String = _args.get("report", "")

	print("=== 擬似テストプレイシミュレーター ===")
	print("キャラクター: %s / ラン数: %d / シード: %d / 戦略: %s" % [character_id, run_count, seed_val, strategy])

	# データ監査
	var audit: RefCounted = DataAuditScript.new(CardDatabase, EnemyDatabase, GameManager, ItemDatabase)
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
		var result := _simulate_run(character, run_seed, strategy)
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
	var report := _generate_report(character, run_results, audit, strategy)
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

func _simulate_run(character: CharacterData, run_seed: int, strategy: String) -> Dictionary:
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
		var map: Array[Dictionary] = MapGenerator.generate_act(act, rng.randi())
		GameManager.map_nodes = map
		GameManager.map_current_row = -1

		var previous_node: Dictionary = {}
		var current_node: Dictionary = _pick_first_node(map, rng, strategy)

		while not current_node.is_empty():
			var node: Dictionary = current_node
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
						var boss_id: StringName = &""
						if not enemies.is_empty():
							var boss: EnemyData = enemies[0]
							boss_id = boss.id
						var mod: Dictionary = QuestManager.get_boss_modifier(act, boss_id)
						boss_hp_scale = float(mod.get("hp_scale", 1.0))
					var agent: RefCounted = BattleAgentScript.new(CombatManager, DeckManager, rng, strategy, ItemDatabase)
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
					_apply_post_combat_items(node_type, enemies, rng)
					_pick_reward_card(character, act, rng, strategy)

				MapGenerator.NodeType.REST:
					_handle_rest(rng, strategy)
				MapGenerator.NodeType.SHOP:
					_handle_shop(rng, strategy)
				MapGenerator.NodeType.EVENT:
					var event_result: Dictionary = _handle_event(rng, strategy)
					if bool(event_result.get("battle", false)):
						battles_fought += 1
						total_turns += int(event_result.get("turns", 0))
						total_damage_taken += int(event_result.get("damage_taken", 0))
						total_cards_played += int(event_result.get("cards_played", 0))
						battle_logs.append({
							"act": act,
							"type": "イベント戦闘",
							"won": bool(event_result.get("won", true)),
							"turns": int(event_result.get("turns", 0)),
							"hp_before": int(event_result.get("hp_before", CombatManager.player_hp)),
							"hp_after": CombatManager.player_hp,
						})
						if not bool(event_result.get("won", true)):
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
				MapGenerator.NodeType.INFO:
					_handle_info(rng)

			_maybe_use_medicine(strategy)
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
			current_node = _pick_next_node(map, node, rng, strategy)

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

func _pick_first_node(map_nodes: Array[Dictionary], rng: RandomNumberGenerator, strategy: String) -> Dictionary:
	var first_row := MapGenerator._get_nodes_at_row(map_nodes, 0)
	if first_row.is_empty():
		return {}
	return _pick_node_by_strategy(first_row, rng, strategy)

func _pick_next_node(map_nodes: Array[Dictionary], current: Dictionary, rng: RandomNumberGenerator, strategy: String) -> Dictionary:
	var connections: Array = current.get("connections", [])
	if connections.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for next_id_variant: Variant in connections:
		var next_id: String = String(next_id_variant)
		var node: Dictionary = _find_node_by_id(map_nodes, next_id)
		if not node.is_empty():
			candidates.append(node)
	if candidates.is_empty():
		return {}
	return _pick_node_by_strategy(candidates, rng, strategy)

func _find_node_by_id(map_nodes: Array[Dictionary], node_id: String) -> Dictionary:
	for node: Dictionary in map_nodes:
		if "%d_%d" % [node["row"], node["col"]] == node_id:
			return node
	return {}

func _pick_node_by_strategy(candidates: Array[Dictionary], rng: RandomNumberGenerator, strategy: String) -> Dictionary:
	if strategy == "reckless":
		return candidates[rng.randi() % candidates.size()]
	var best_nodes: Array[Dictionary] = []
	var best_score: int = -999999
	for node: Dictionary in candidates:
		var score: int = _score_node(node)
		if score > best_score:
			best_score = score
			best_nodes.clear()
			best_nodes.append(node)
		elif score == best_score:
			best_nodes.append(node)
	if best_nodes.is_empty():
		return candidates[rng.randi() % candidates.size()]
	return best_nodes[rng.randi() % best_nodes.size()]

func _score_node(node: Dictionary) -> int:
	var node_type: MapGenerator.NodeType = node["type"]
	var hp_pct: float = float(CombatManager.player_hp) / float(CombatManager.player_max_hp)
	var score: int = 0
	match node_type:
		MapGenerator.NodeType.BOSS:
			score = 100
		MapGenerator.NodeType.REST:
			score = 45 if hp_pct < 0.75 else 8
		MapGenerator.NodeType.EVENT:
			score = 24
		MapGenerator.NodeType.SHOP:
			score = 18
			if ResourceManager.scrap >= 5 or ResourceManager.fuel < 10:
				score += 10
		MapGenerator.NodeType.INFO:
			score = 12
		MapGenerator.NodeType.COMBAT:
			score = 10 if hp_pct >= 0.45 else -10
		MapGenerator.NodeType.ELITE:
			score = 20 if hp_pct >= 0.75 else -35
	var fuel_reward: int = int(node.get("fuel_reward", 0))
	if ResourceManager.fuel < 10:
		score += fuel_reward * 4
	else:
		score += fuel_reward
	return score

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
			var boss_id: StringName = boss.id if boss != null else &""
			var mod: Dictionary = QuestManager.get_boss_modifier(act, boss_id)
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

func _pick_reward_card(character: CharacterData, act: int, rng: RandomNumberGenerator, strategy: String) -> void:
	var pool: Array[CardData] = CardDatabase.get_reward_pool(act, character.id)
	if pool.is_empty():
		return
	_shuffle_cards(pool, rng)
	var candidates: Array[CardData] = []
	for i in mini(3, pool.size()):
		candidates.append(pool[i])
	if strategy == "reckless":
		if character.deck_limit > 0 and DeckManager.master_deck.size() >= character.deck_limit:
			return
		DeckManager.add_card_to_deck(candidates[rng.randi() % candidates.size()])
		return
	var best: CardData = candidates[0]
	var best_score: int = _card_score(best)
	for i in range(1, candidates.size()):
		var score: int = _card_score(candidates[i])
		if score > best_score:
			best = candidates[i]
			best_score = score
	if character.deck_limit > 0 and DeckManager.master_deck.size() >= character.deck_limit:
		return
	var skip_threshold := 9
	if DeckManager.master_deck.size() >= 22:
		skip_threshold = 16
	elif DeckManager.master_deck.size() >= 18:
		skip_threshold = 13
	if best_score < skip_threshold:
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

func _handle_rest(rng: RandomNumberGenerator, strategy: String) -> void:
	var hp_pct := float(CombatManager.player_hp) / float(CombatManager.player_max_hp)
	var heal_threshold := 0.85 if strategy == "smart" else 0.35
	if hp_pct < heal_threshold:
		var heal := ceili(float(CombatManager.player_max_hp) * 0.5)
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
			var heal := ceili(float(CombatManager.player_max_hp) * 0.5)
			CombatManager.player_hp = mini(CombatManager.player_hp + heal, CombatManager.player_max_hp)

func _handle_shop(rng: RandomNumberGenerator, strategy: String) -> void:
	if strategy == "smart":
		_buy_shop_medicine()
		_buy_shop_item(rng)
		_buy_shop_card(rng)
	if ResourceManager.scrap >= 5 and ResourceManager.fuel < ResourceManager.tank_capacity - 5:
		ResourceManager.consume_scrap(5)
		ResourceManager.add_fuel(8)

func _buy_shop_medicine() -> void:
	var medicine_cost := 4
	if ResourceManager.medicine >= ResourceManager.medicine_max:
		return
	if ResourceManager.fuel < medicine_cost + 10:
		return
	if CombatManager.player_hp >= CombatManager.player_max_hp and ResourceManager.medicine >= 1:
		return
	if ResourceManager.consume_fuel(medicine_cost):
		ResourceManager.add_medicine(1)

func _buy_shop_item(rng: RandomNumberGenerator) -> void:
	var all_items: Array[ItemData] = ItemDatabase.get_all_items()
	if all_items.is_empty():
		return
	_shuffle_items(all_items, rng)
	var best_item: ItemData = null
	var best_score: int = -999
	var offer_count: int = mini(2, all_items.size())
	for i in offer_count:
		var item: ItemData = all_items[i]
		if ItemDatabase.get_inventory_count(item.id) >= item.max_stack:
			continue
		var score: int = _item_shop_score(item)
		if score > best_score:
			best_item = item
			best_score = score
	if best_item == null or best_score < 10:
		return
	var cost: int = _item_shop_cost(best_item)
	if ResourceManager.fuel < cost + 8:
		return
	if ResourceManager.consume_fuel(cost):
		ItemDatabase.add_to_inventory(best_item.id)

func _buy_shop_card(rng: RandomNumberGenerator) -> void:
	var character: CharacterData = GameManager.current_character
	if character == null:
		return
	if character.deck_limit > 0 and DeckManager.master_deck.size() >= character.deck_limit:
		return
	var pool: Array[CardData] = CardDatabase.get_reward_pool(GameManager.current_act, character.id)
	if pool.is_empty():
		return
	_shuffle_cards(pool, rng)
	var best: CardData = pool[0]
	var best_score: int = _card_score(best)
	for i in range(1, mini(4, pool.size())):
		var card: CardData = pool[i]
		var score: int = _card_score(card)
		if score > best_score:
			best = card
			best_score = score
	var threshold := 13
	if DeckManager.master_deck.size() <= 15:
		threshold = 10
	if best_score < threshold:
		return
	var cost: int = 4 + int(best.rarity) * 3
	if ResourceManager.fuel < cost + 8:
		return
	if ResourceManager.consume_fuel(cost):
		DeckManager.add_card_to_deck(best)

func _item_shop_score(item: ItemData) -> int:
	match item.id:
		&"sacred_amulet":
			return 28
		&"mutant_jacket":
			return 24
		&"old_compass":
			return 18
		&"stim_shot":
			return 18
		&"flash_bomb":
			return 14
		&"fuel_additive":
			return 8
	var score: int = 0
	if item.item_type == ItemData.ItemType.RELIC:
		score += 14 + int(item.rarity) * 4
	score += item.hp_change
	score += item.block_change * 2
	score += item.draw_change * 4
	score += item.fuel_change
	return score

func _item_shop_cost(item: ItemData) -> int:
	var cost: int = 3 + int(item.rarity) * 3
	if item.item_type == ItemData.ItemType.RELIC:
		cost += 4
	return cost

func _maybe_use_medicine(strategy: String) -> void:
	if strategy != "smart":
		return
	if ResourceManager.medicine <= 0:
		return
	if CombatManager.player_hp <= 0 or CombatManager.player_hp >= CombatManager.player_max_hp:
		return
	var hp_pct: float = float(CombatManager.player_hp) / float(CombatManager.player_max_hp)
	var missing_hp: int = CombatManager.player_max_hp - CombatManager.player_hp
	if hp_pct > 0.55 and missing_hp < 18:
		return
	if ResourceManager.use_medicine():
		CombatManager.player_hp = mini(CombatManager.player_hp + 15, CombatManager.player_max_hp)

func _shuffle_cards(cards: Array[CardData], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp

func _shuffle_items(items: Array[ItemData], rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: ItemData = items[i]
		items[i] = items[j]
		items[j] = tmp

func _handle_event(rng: RandomNumberGenerator, strategy: String) -> Dictionary:
	var event: EventData = _pick_event_for_sim(rng)
	if event == null:
		return {}
	var choices: Array[EventChoiceData] = []
	for choice: EventChoiceData in event.choices:
		if _check_choice_requirement(choice.requirement):
			choices.append(choice)
	if choices.is_empty():
		return {}
	var choice: EventChoiceData = _pick_choice_by_strategy(choices, strategy, rng)
	_apply_choice(choice)
	if not choice.triggers_combat:
		return {}
	var enemies: Array[EnemyData] = _enemies_from_ids(choice.combat_enemy_ids, rng)
	if enemies.is_empty():
		return {}
	var hp_before: int = CombatManager.player_hp
	var agent: RefCounted = BattleAgentScript.new(CombatManager, DeckManager, rng, strategy, ItemDatabase)
	var result: Dictionary = agent.fight(enemies)
	var cards_played: int = 0
	for entry: Dictionary in result["log"]:
		if entry.get("action", "") == "play":
			cards_played += 1
	return {
		"battle": true,
		"won": bool(result["won"]),
		"turns": int(result["turns"]),
		"hp_before": hp_before,
		"damage_taken": maxi(0, hp_before - int(result["player_hp"])),
		"cards_played": cards_played,
	}

func _handle_info(_rng: RandomNumberGenerator) -> void:
	if CombatManager.player_hp < CombatManager.player_max_hp:
		CombatManager.player_hp = mini(CombatManager.player_hp + 3, CombatManager.player_max_hp)

func _pick_event_for_sim(rng: RandomNumberGenerator) -> EventData:
	var forced_id: StringName = QuestManager.get_pending_payload(GameManager.current_act)
	if forced_id != &"":
		var forced: EventData = EventManager.get_event(forced_id)
		if forced != null:
			return forced
	var available: Array[EventData] = EventManager.get_available_events(
		GameManager.current_character.id, KarmaManager.karma, GameManager.current_act)
	if available.is_empty():
		return null
	return available[rng.randi() % available.size()]

func _pick_choice_by_strategy(choices: Array[EventChoiceData], strategy: String, rng: RandomNumberGenerator) -> EventChoiceData:
	if choices.size() == 1:
		return choices[0]
	var best_choice: EventChoiceData = choices[0]
	var best_score: int = _choice_score(best_choice)
	for i in range(1, choices.size()):
		var choice: EventChoiceData = choices[i]
		var score: int = _choice_score(choice)
		if strategy == "reckless":
			if score < best_score:
				best_choice = choice
				best_score = score
		elif score > best_score:
			best_choice = choice
			best_score = score
	if strategy == "reckless" and rng.randf() < 0.25:
		return choices[rng.randi() % choices.size()]
	return best_choice

func _choice_score(choice: EventChoiceData) -> int:
	var score: int = 0
	score += choice.fuel_change * 2
	score += choice.scrap_change * 3
	score += choice.medicine_change * 8
	score += choice.hp_change * 2
	score += choice.karma_change
	score += choice.bike_durability_change * 3
	if choice.item_reward_id != &"":
		score += 10 * maxi(1, choice.item_reward_count)
	for card_id: StringName in choice.deck_card_ids:
		var card: CardData = CardDatabase.get_card(card_id)
		if card != null and card.is_unplayable:
			score -= 18
		else:
			score += 8
	if choice.triggers_combat:
		score -= 12
	if choice.companion_id != &"":
		score += 12
	if choice.starts_quest != &"":
		score += 5
	return score

func _apply_choice(choice: EventChoiceData) -> void:
	if choice.fuel_change > 0:
		ResourceManager.add_fuel(choice.fuel_change)
	elif choice.fuel_change < 0:
		ResourceManager.consume_fuel(-choice.fuel_change)
	if choice.scrap_change > 0:
		ResourceManager.add_scrap(choice.scrap_change)
	elif choice.scrap_change < 0:
		ResourceManager.consume_scrap(-choice.scrap_change)
	if choice.medicine_change > 0:
		ResourceManager.add_medicine(choice.medicine_change)
	elif choice.medicine_change < 0:
		ResourceManager.use_medicine()
	if choice.bike_durability_change > 0:
		ResourceManager.repair_bike(choice.bike_durability_change)
	elif choice.bike_durability_change < 0:
		ResourceManager.damage_bike(-choice.bike_durability_change)
	for card_id: StringName in choice.deck_card_ids:
		var _added_card: bool = DeckManager.add_card_id_to_deck(card_id)
	if choice.item_reward_id != &"":
		ItemDatabase.add_to_inventory(choice.item_reward_id, maxi(1, choice.item_reward_count))
	if choice.karma_change != 0:
		KarmaManager.add_karma(choice.karma_change)
	if choice.hp_change != 0:
		CombatManager.player_hp = clampi(
			CombatManager.player_hp + choice.hp_change, 0, CombatManager.player_max_hp)
	if choice.sets_flag != &"":
		GameManager.event_flags[choice.sets_flag] = true
	if choice.starts_quest != &"":
		QuestManager.record_outcome(choice.starts_quest, choice.quest_outcome)
	if choice.faith_change != 0:
		GameManager.add_faith(choice.faith_change)
	if choice.heat_change != 0:
		CombatManager.player_heat = clampi(
			CombatManager.player_heat + choice.heat_change, 0, CombatManager.HEAT_MAX)
	if choice.euphoria_change != 0:
		CombatManager.player_euphoria = clampi(
			CombatManager.player_euphoria + choice.euphoria_change, 0, CombatManager.EUPHORIA_MAX)
	if choice.companion_id != &"":
		var comp: CompanionData = CompanionDatabase.get_companion(choice.companion_id)
		if comp != null:
			GameManager.recruit_companion(comp)

func _check_choice_requirement(req: String) -> bool:
	if req == "":
		return true
	if req.begins_with("medicine>="):
		return ResourceManager.medicine >= int(req.split(">=")[1])
	if req.begins_with("fuel>="):
		return ResourceManager.fuel >= int(req.split(">=")[1])
	if req.begins_with("scrap>="):
		return ResourceManager.scrap >= int(req.split(">=")[1])
	if req.begins_with("hp>="):
		return CombatManager.player_hp >= int(req.split(">=")[1])
	if req.begins_with("karma>="):
		return KarmaManager.karma >= int(req.split(">=")[1])
	if req.begins_with("character=="):
		return GameManager.current_character.id == StringName(req.split("==")[1])
	if req.begins_with("flag=="):
		return bool(GameManager.event_flags.get(StringName(req.split("==")[1]), false))
	if req.begins_with("flag!="):
		return not bool(GameManager.event_flags.get(StringName(req.split("!=")[1]), false))
	if req.begins_with("companion=="):
		if GameManager.current_companion == null:
			return false
		return GameManager.current_companion.id == StringName(req.split("==")[1])
	if req == "no_companion":
		return GameManager.current_companion == null
	if req.begins_with("faith>="):
		return GameManager.faith >= int(req.split(">=")[1])
	if req.begins_with("faith<="):
		return GameManager.faith <= int(req.split("<=")[1])
	if req.begins_with("heat>="):
		return CombatManager.player_heat >= int(req.split(">=")[1])
	if req.begins_with("euphoria>="):
		return CombatManager.player_euphoria >= int(req.split(">=")[1])
	return false

func _enemies_from_ids(enemy_ids: Array[StringName], rng: RandomNumberGenerator) -> Array[EnemyData]:
	var enemies: Array[EnemyData] = []
	for eid: StringName in enemy_ids:
		var ed: EnemyData = EnemyDatabase.get_enemy(eid)
		if ed != null:
			enemies.append(ed)
	if enemies.is_empty():
		var pool: Array[EnemyData] = EnemyDatabase.get_enemies_for_act(GameManager.current_act)
		if pool.is_empty():
			pool = EnemyDatabase.get_enemies_for_act(1)
		if not pool.is_empty():
			enemies.append(pool[rng.randi() % pool.size()])
	return enemies

func _apply_post_combat_items(node_type: MapGenerator.NodeType, enemies: Array[EnemyData], rng: RandomNumberGenerator) -> void:
	var has_machine: bool = false
	for enemy: EnemyData in enemies:
		if enemy.category == EnemyData.Category.MACHINE:
			has_machine = true
			break
	if has_machine:
		ResourceManager.add_scrap(rng.randi_range(3, 6))
	var elite_reward: bool = node_type == MapGenerator.NodeType.ELITE or node_type == MapGenerator.NodeType.BOSS
	if elite_reward and rng.randf() < 0.5:
		var relics: Array[ItemData] = ItemDatabase.get_items_by_type(ItemData.ItemType.RELIC)
		if not relics.is_empty():
			ItemDatabase.add_to_inventory(relics[rng.randi() % relics.size()].id)
	elif rng.randf() < 0.25:
		var consumables: Array[ItemData] = ItemDatabase.get_items_by_type(ItemData.ItemType.CONSUMABLE)
		if not consumables.is_empty():
			ItemDatabase.add_to_inventory(consumables[rng.randi() % consumables.size()].id)

func _generate_report(character: CharacterData, results: Array[Dictionary], audit: RefCounted, strategy: String) -> String:
	var lines: Array[String] = []
	lines.append("# 擬似テストプレイ レポート")
	lines.append("")
	lines.append("- キャラクター: %s (%s)" % [character.display_name, character.id])
	lines.append("- ラン数: %d" % results.size())
	lines.append("- 戦略: %s" % strategy)
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
