extends Node

signal turn_started(turn_number: int)
signal turn_ended()
signal card_played(card: CardData)
signal enemy_defeated(enemy_idx: int)
signal combat_won(rewards: Array)
signal combat_lost()
signal player_fled()
signal player_hp_changed(hp: int, max_hp: int)
signal player_block_changed(block: int)
signal ap_changed(ap: int)
signal enemy_hp_changed(idx: int, hp: int, max_hp: int)
signal enemy_block_changed(idx: int, block: int)
signal enemy_intent_updated(idx: int, intent: Dictionary)

enum CombatState { INACTIVE, INIT, DRAW, PLAYER_TURN, DISCARD, ENEMY_TURN, CHECK_END, VICTORY, DEFEAT, FLED }

var state: CombatState = CombatState.INACTIVE
var turn_number: int = 0
var ap: int = 0
var max_ap: int = 6
var ap_cost_halved: bool = false
var player_hp: int = 0
var player_max_hp: int = 0
var player_block: int = 0

var enemies: Array[Dictionary] = []

func reset_player_for_new_run() -> void:
	player_max_hp = GameManager.current_character.max_hp
	player_hp = player_max_hp

func start_combat(enemy_list: Array[EnemyData]) -> void:
	state = CombatState.INIT
	turn_number = 0
	player_max_hp = GameManager.current_character.max_hp
	player_hp = mini(player_hp, player_max_hp)
	player_block = 0
	enemies.clear()
	for ed: EnemyData in enemy_list:
		enemies.append({
			"data": ed,
			"hp": ed.base_hp,
			"max_hp": ed.base_hp,
			"block": 0,
			"alive": true,
			"intent": {},
			"turn_counter": 0,
		})
	DeckManager.start_combat()
	begin_turn()

func begin_turn() -> void:
	turn_number += 1
	state = CombatState.PLAYER_TURN
	ap = max_ap
	ap_cost_halved = false
	player_block = 0
	player_block_changed.emit(player_block)
	ap_changed.emit(ap)
	_update_all_intents()
	DeckManager.draw_cards()
	turn_started.emit(turn_number)

func get_effective_ap_cost(card: CardData) -> int:
	if ap_cost_halved:
		return (card.ap_cost + 1) / 2
	return card.ap_cost

func can_play_card(card: CardData) -> bool:
	if state != CombatState.PLAYER_TURN:
		return false
	if card.is_unplayable:
		return false
	if get_effective_ap_cost(card) > ap:
		return false
	if card.fuel_cost > 0 and ResourceManager.fuel < card.fuel_cost:
		return false
	return true

func play_card(card: CardData, target_idx: int = -1) -> void:
	if not can_play_card(card):
		return
	ap -= get_effective_ap_cost(card)
	if card.fuel_cost > 0:
		ResourceManager.consume_fuel(card.fuel_cost)
	if card.halves_ap_this_turn:
		ap_cost_halved = true
	ap_changed.emit(ap)
	_apply_card_effects(card, target_idx)
	DeckManager.play_card(card)
	card_played.emit(card)
	_check_enemies_alive()

func end_player_turn() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	state = CombatState.DISCARD
	DeckManager.discard_hand()
	state = CombatState.ENEMY_TURN
	_execute_enemy_turns()
	state = CombatState.CHECK_END
	if player_hp <= 0:
		state = CombatState.DEFEAT
		combat_lost.emit()
		return
	begin_turn()

func flee() -> bool:
	if state != CombatState.PLAYER_TURN:
		return false
	if not ResourceManager.consume_fuel(1):
		return false
	state = CombatState.FLED
	player_fled.emit()
	return true

func emergency_reroll() -> bool:
	if state != CombatState.PLAYER_TURN:
		return false
	if not ResourceManager.consume_fuel(1):
		return false
	DeckManager.discard_hand()
	DeckManager.draw_cards()
	return true

func _apply_card_effects(card: CardData, target_idx: int) -> void:
	var dmg := card.get_effective_damage()
	var blk := card.get_effective_block()

	if blk > 0:
		player_block += blk
		player_block_changed.emit(player_block)

	if card.self_damage > 0:
		_damage_player(card.self_damage)

	if card.draw_count > 0:
		DeckManager.draw_cards(card.draw_count)

	if card.bonus_ap > 0:
		ap += card.bonus_ap
		ap_changed.emit(ap)

	if dmg > 0:
		if card.is_aoe:
			for i in enemies.size():
				if enemies[i]["alive"]:
					_damage_enemy(i, dmg * card.hit_count, card.tags)
		else:
			if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				for h in card.hit_count:
					if enemies[target_idx]["alive"]:
						_damage_enemy(target_idx, dmg, card.tags)

	if card.status_effect != &"" and target_idx >= 0:
		pass

func is_weak_against(idx: int, tags: Array[CardData.Tag]) -> bool:
	if idx < 0 or idx >= enemies.size():
		return false
	var data: EnemyData = enemies[idx]["data"]
	for tag in tags:
		if tag in data.weaknesses:
			return true
	return false

func _damage_enemy(idx: int, amount: int, source_tags: Array[CardData.Tag] = []) -> void:
	if idx < 0 or idx >= enemies.size():
		return
	var enemy := enemies[idx]
	if not enemy["alive"]:
		return
	var remaining := amount
	if is_weak_against(idx, source_tags):
		remaining = int(remaining * 1.5)
	if enemy["block"] > 0:
		if enemy["block"] >= remaining:
			enemy["block"] -= remaining
			remaining = 0
		else:
			remaining -= enemy["block"]
			enemy["block"] = 0
		enemy_block_changed.emit(idx, enemy["block"])
	if remaining > 0:
		enemy["hp"] = maxi(0, enemy["hp"] - remaining)
		enemy_hp_changed.emit(idx, enemy["hp"], enemy["max_hp"])

func _damage_player(amount: int) -> void:
	var remaining := amount
	if player_block > 0:
		if player_block >= remaining:
			player_block -= remaining
			remaining = 0
		else:
			remaining -= player_block
			player_block = 0
		player_block_changed.emit(player_block)
	if remaining > 0:
		player_hp = maxi(0, player_hp - remaining)
		player_hp_changed.emit(player_hp, player_max_hp)

func _check_enemies_alive() -> void:
	var all_dead := true
	for i in enemies.size():
		if enemies[i]["hp"] <= 0 and enemies[i]["alive"]:
			enemies[i]["alive"] = false
			enemy_defeated.emit(i)
		if enemies[i]["alive"]:
			all_dead = false
	if all_dead:
		state = CombatState.VICTORY
		combat_won.emit(_generate_rewards())

func _execute_enemy_turns() -> void:
	for i in enemies.size():
		if not enemies[i]["alive"]:
			continue
		var intent: Dictionary = enemies[i]["intent"]
		enemies[i]["block"] = 0
		enemy_block_changed.emit(i, 0)
		match intent.get("type", ""):
			"attack":
				var dmg: int = intent.get("value", 0)
				_damage_player(dmg)
			"defend":
				var blk: int = intent.get("value", 0)
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
			"attack_defend":
				var dmg: int = intent.get("attack", 0)
				var blk: int = intent.get("block", 0)
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
				_damage_player(dmg)
		enemies[i]["turn_counter"] += 1

func _update_all_intents() -> void:
	for i in enemies.size():
		if not enemies[i]["alive"]:
			continue
		enemies[i]["intent"] = _get_enemy_intent(enemies[i])
		enemy_intent_updated.emit(i, enemies[i]["intent"])

func _get_enemy_intent(enemy: Dictionary) -> Dictionary:
	var data: EnemyData = enemy["data"]
	var tc: int = enemy["turn_counter"]
	var hp_pct := float(enemy["hp"]) / float(enemy["max_hp"])

	if data.is_boss:
		return _get_boss_intent(data, tc, hp_pct)

	match data.id:
		&"devilwolf":
			if (tc % 3) == 2:
				return {"type": "attack", "value": 12, "label": "飛びかかり"}
			else:
				return {"type": "attack", "value": 8, "label": "噛みつき"}
		&"bandit":
			if tc % 3 == 0:
				return {"type": "defend", "value": 6, "label": "身構える"}
			else:
				return {"type": "attack", "value": 9, "label": "ナイフ"}
		&"wild_dog":
			return {"type": "attack", "value": 5, "label": "噛みつき"}
		&"devilwolf_leader":
			if hp_pct > 0.5:
				return {"type": "attack", "value": 12, "label": "引き裂く"}
			else:
				return {"type": "attack", "value": 18, "label": "猛襲"}
		&"rogue_rider":
			if tc % 3 == 2:
				return {"type": "attack", "value": 16, "label": "体当たり"}
			elif tc % 2 == 0:
				return {"type": "attack", "value": 14, "label": "突撃"}
			else:
				return {"type": "attack", "value": 10, "label": "射撃"}
		_:
			return {"type": "attack", "value": 6, "label": "攻撃"}

func _get_boss_intent(data: EnemyData, tc: int, hp_pct: float) -> Dictionary:
	match data.id:
		&"alpha_devilwolf":
			if hp_pct > 0.5:
				if tc % 4 == 3:
					return {"type": "attack", "value": 24, "label": "二連撃"}
				elif tc % 2 == 0:
					return {"type": "attack", "value": 12, "label": "噛みつき"}
				else:
					return {"type": "attack", "value": 6, "label": "遠吠え"}
			else:
				if tc % 3 == 2:
					return {"type": "attack", "value": 25, "label": "飛びかかり"}
				else:
					return {"type": "attack", "value": 18, "label": "猛攻"}
	return {"type": "attack", "value": 10, "label": "攻撃"}

func _generate_rewards() -> Array:
	var slot_count := 3
	var rewards := []
	if randf() < 0.5:
		rewards.append({"type": "fuel", "amount": randi_range(8, 15)})
		slot_count -= 1
	for i in slot_count:
		rewards.append({"type": "card"})
	return rewards

