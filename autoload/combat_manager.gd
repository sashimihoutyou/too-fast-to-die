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
signal enemy_status_changed(idx: int, status: Dictionary)
signal player_status_changed(status: Dictionary)
signal acceleration_changed(gauge: int, max_gauge: int)
signal player_buffs_changed(buffs: Dictionary)
signal ultimate_activated()

enum CombatState { INACTIVE, INIT, DRAW, PLAYER_TURN, DISCARD, ENEMY_TURN, CHECK_END, VICTORY, DEFEAT, FLED }

var state: CombatState = CombatState.INACTIVE
var turn_number: int = 0
var ap: int = 0
var max_ap: int = 5
var ap_cost_reduction: int = 0
var player_hp: int = 0
var player_max_hp: int = 0
var player_block: int = 0
var player_status: Dictionary = {}

var enemies: Array[Dictionary] = []

var acceleration_gauge: int = 0
const ACCELERATION_MAX := 30
const ACCEL_ATTACK := 3
const ACCEL_BUFF := 5
const ACCEL_BLOCK_CAP := 10
var player_buffs: Dictionary = {}

func _new_buffs_dict() -> Dictionary:
	return {"melee_power": 0, "ranged_double": 0, "overcharge": 0, "ultimate": 0}

func reset_player_for_new_run() -> void:
	player_max_hp = GameManager.current_character.max_hp
	player_hp = player_max_hp
	player_status = _new_status_dict()
	player_buffs = _new_buffs_dict()
	acceleration_gauge = 0

func start_combat(enemy_list: Array[EnemyData]) -> void:
	state = CombatState.INIT
	turn_number = 0
	player_max_hp = GameManager.current_character.max_hp
	player_hp = mini(player_hp, player_max_hp)
	player_block = 0
	player_status = _new_status_dict()
	player_buffs = _new_buffs_dict()
	acceleration_gauge = 0
	player_status_changed.emit(player_status)
	player_buffs_changed.emit(player_buffs)
	acceleration_changed.emit(acceleration_gauge, ACCELERATION_MAX)
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
			"status": _new_status_dict(),
		})
	DeckManager.start_combat()
	begin_turn()

func begin_turn() -> void:
	turn_number += 1
	state = CombatState.PLAYER_TURN
	ap = max_ap
	ap_cost_reduction = 0
	player_block = 0
	player_block_changed.emit(player_block)
	_tick_player_statuses()
	if player_hp <= 0:
		state = CombatState.DEFEAT
		combat_lost.emit()
		return
	ap_changed.emit(ap)
	_update_all_intents()
	DeckManager.draw_cards()
	turn_started.emit(turn_number)

func get_effective_ap_cost(card: CardData) -> int:
	var reduction := ap_cost_reduction
	if int(player_buffs.get("ultimate", 0)) > 0:
		reduction += 1
	if reduction > 0:
		return maxi(0, card.ap_cost - reduction)
	return card.ap_cost

# 指定した敵にこのカードを使った場合の与ダメージ（ブロック前・全ヒット合計）を予測する。
# 筋力・弱体・弱点・脆弱を反映。UIのダメージプレビュー用。
func preview_damage(card: CardData, idx: int) -> int:
	if idx < 0 or idx >= enemies.size():
		return 0
	var base := card.get_effective_damage()
	if base <= 0:
		return 0
	var per_hit := _apply_player_attack_mods(base, card.tags, false)
	if is_weak_against(idx, card.tags):
		per_hit = int(per_hit * 1.5)
	if int(enemies[idx]["status"].get("vulnerable", 0)) > 0:
		per_hit = int(per_hit * 1.5)
	return per_hit * card.hit_count

func can_play_card(card: CardData) -> bool:
	if state != CombatState.PLAYER_TURN:
		return false
	if card.is_unplayable:
		return false
	var cost := get_effective_ap_cost(card)
	if cost > ap and int(player_buffs.get("overcharge", 0)) <= 0:
		return false
	if card.fuel_cost > 0 and ResourceManager.fuel < card.fuel_cost:
		return false
	return true

func has_playable_card() -> bool:
	for card: CardData in DeckManager.hand:
		if can_play_card(card):
			return true
	return false

func play_card(card: CardData, target_idx: int = -1) -> void:
	if not can_play_card(card):
		return
	var cost := get_effective_ap_cost(card)
	var ap_before := ap
	ap -= cost
	if int(player_buffs.get("overcharge", 0)) > 0 and ap < 0:
		var debt := maxi(0, cost - maxi(0, ap_before))
		if debt > 0:
			player_hp = maxi(0, player_hp - debt * 3)
			player_hp_changed.emit(player_hp, player_max_hp)
	if card.fuel_cost > 0:
		ResourceManager.consume_fuel(card.fuel_cost)
	if card.ap_cost_reduction > 0:
		ap_cost_reduction = maxi(ap_cost_reduction, card.ap_cost_reduction)
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
	_tick_player_buffs()
	state = CombatState.ENEMY_TURN
	_execute_enemy_turns()
	_check_enemies_alive()
	if state == CombatState.VICTORY:
		return
	state = CombatState.CHECK_END
	if player_hp <= 0:
		state = CombatState.DEFEAT
		combat_lost.emit()
		return
	begin_turn()

func flee() -> bool:
	if state != CombatState.PLAYER_TURN:
		return false
	if has_boss_enemy():
		return false
	if not ResourceManager.consume_fuel(1):
		return false
	state = CombatState.FLED
	player_fled.emit()
	return true

func has_boss_enemy() -> bool:
	for enemy: Dictionary in enemies:
		var data: EnemyData = enemy["data"]
		if data.is_boss:
			return true
	return false

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
		var hit_dmg := _apply_player_attack_mods(dmg, card.tags)
		if card.is_aoe:
			for i in enemies.size():
				if enemies[i]["alive"]:
					_damage_enemy(i, hit_dmg * card.hit_count, card.tags)
		else:
			if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				for h in card.hit_count:
					if enemies[target_idx]["alive"]:
						_damage_enemy(target_idx, hit_dmg, card.tags)

	if card.status_effect != &"" and card.status_stacks != 0:
		if _is_player_effect(card.status_effect):
			_apply_player_effect(card.status_effect, card.status_stacks)
		else:
			var mapped := _map_status(card.status_effect)
			if mapped != &"":
				if card.is_aoe:
					for i in enemies.size():
						if enemies[i]["alive"]:
							_add_enemy_status(i, mapped, card.status_stacks)
				elif target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
					_add_enemy_status(target_idx, mapped, card.status_stacks)

	if _is_cultist():
		_fill_acceleration_from_card(card)

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
	var enemy_status: Dictionary = enemy["status"]
	if int(enemy_status.get("vulnerable", 0)) > 0:
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

func _damage_player(amount: int, from_enemy: bool = false) -> void:
	var remaining := amount
	if from_enemy and int(player_status.get("vulnerable", 0)) > 0:
		remaining = int(remaining * 1.5)
	var blocked := 0
	if player_block > 0:
		if player_block >= remaining:
			blocked = remaining
			player_block -= remaining
			remaining = 0
		else:
			blocked = player_block
			remaining -= player_block
			player_block = 0
		player_block_changed.emit(player_block)
	if remaining > 0:
		player_hp = maxi(0, player_hp - remaining)
		player_hp_changed.emit(player_hp, player_max_hp)
	if from_enemy and blocked > 0 and _is_cultist():
		_add_acceleration(mini(blocked, ACCEL_BLOCK_CAP))

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
		# ターン開始時：継続ダメージ（炎上・出血）を適用
		if _apply_dot_to_enemy(i):
			continue  # 継続ダメージで撃破された
		var status: Dictionary = enemies[i]["status"]
		var weak_active := int(status.get("weak", 0)) > 0
		var intent: Dictionary = enemies[i]["intent"]
		enemies[i]["block"] = 0
		enemy_block_changed.emit(i, 0)
		match intent.get("type", ""):
			"attack":
				var dmg: int = _apply_weak(intent.get("value", 0), weak_active)
				var hits: int = intent.get("hits", 1)
				for h in hits:
					_damage_player(dmg, true)
			"defend":
				var blk: int = intent.get("value", 0)
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
			"attack_defend":
				var dmg: int = _apply_weak(intent.get("attack", 0), weak_active)
				var blk: int = intent.get("block", 0)
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
				_damage_player(dmg, true)
		# ターン終了時：弱体・脆弱を1減衰
		_decay_debuffs(status)
		enemy_status_changed.emit(i, status)
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
	return _get_scaled_intent(data, tc, hp_pct)

# 区間（act）・カテゴリ・残HPに応じてザコ/エリートの行動を生成する。
# 敵データに固有ムーブセットが無くても、区間が進むほど脅威が増すよう数値をスケールさせる。
func _get_scaled_intent(data: EnemyData, tc: int, hp_pct: float) -> Dictionary:
	var act := clampi(data.act, 1, GameManager.MAX_ACT)
	var atk := 5 + act * 3
	var blk := 3 + act * 2
	if data.is_elite:
		atk = int(atk * 1.4)
		blk = int(blk * 1.4)

	match data.category:
		EnemyData.Category.BEAST:
			if tc % 3 == 2:
				return {"type": "attack", "value": maxi(1, int(atk * 0.6)), "hits": 2, "label": "連撃"}
			elif hp_pct < 0.4:
				return {"type": "attack", "value": int(atk * 1.5), "label": "手負いの猛攻"}
			else:
				return {"type": "attack", "value": atk, "label": "噛みつき"}
		EnemyData.Category.MACHINE:
			if tc % 3 == 0:
				return {"type": "defend", "value": int(blk * 1.3), "label": "装甲展開"}
			else:
				return {"type": "attack", "value": int(atk * 1.2), "label": "砲撃"}
		_:
			if tc % 4 == 1:
				return {"type": "defend", "value": blk, "label": "身構える"}
			elif tc % 4 == 3:
				return {"type": "attack", "value": int(atk * 1.3), "label": "狙い撃ち"}
			else:
				return {"type": "attack", "value": atk, "label": "攻撃"}

func _get_boss_intent(data: EnemyData, tc: int, hp_pct: float) -> Dictionary:
	var act := clampi(data.act, 1, GameManager.MAX_ACT)
	var atk := 8 + act * 4
	if hp_pct <= 0.5:
		# 後半フェイズ（激昂）
		if tc % 3 == 2:
			return {"type": "attack", "value": maxi(1, int(atk * 0.9)), "hits": 2, "label": "猛襲（二連）"}
		else:
			return {"type": "attack", "value": int(atk * 1.4), "label": "激昂の一撃"}
	else:
		if tc % 4 == 3:
			return {"type": "attack", "value": int(atk * 1.6), "label": "渾身の一撃"}
		elif tc % 4 == 1:
			return {"type": "defend", "value": 8 + act * 3, "label": "防御態勢"}
		else:
			return {"type": "attack", "value": atk, "label": "攻撃"}

func _generate_rewards() -> Array:
	var act := clampi(GameManager.current_act, 1, GameManager.MAX_ACT)
	var is_elite := false
	var has_machine := false
	for e: Dictionary in enemies:
		var d: EnemyData = e["data"]
		if d.is_elite or d.is_boss:
			is_elite = true
		if d.category == EnemyData.Category.MACHINE:
			has_machine = true

	var rewards := []
	# 燃料：区間とエリートでスケール
	var fuel_min := 6 + act * 2
	var fuel_max := 11 + act * 3
	if is_elite:
		fuel_min += 6
		fuel_max += 8
	rewards.append({"type": "fuel", "amount": randi_range(fuel_min, fuel_max)})
	# 機械系の敵を含む場合はスクラップを選択肢に追加
	if has_machine:
		rewards.append({"type": "scrap", "amount": randi_range(3, 6)})
	# カード報酬（エリート/ボスは選択肢が増える）
	var card_slots := 2 if is_elite else 1
	for i in card_slots:
		rewards.append({"type": "card"})
	return rewards

# ===== ステータス効果システム =====
# weak（弱体）= 与ダメ -25% / vulnerable（脆弱）= 被ダメ +50%
# burn（炎上）/ bleed（出血）= ターン開始時に固定ダメージ、毎ターン1減衰
# strength（筋力）= 攻撃に +固定値（将来用）
# heat / aura / beast はキャラ固有ゲージのため、ここでは扱わない（無視）。

func _new_status_dict() -> Dictionary:
	return {"weak": 0, "vulnerable": 0, "burn": 0, "bleed": 0, "strength": 0}

func _map_status(se: StringName) -> StringName:
	match se:
		&"weaken", &"weak":
			return &"weak"
		&"vulnerable", &"vuln":
			return &"vulnerable"
		&"burn":
			return &"burn"
		&"bleed":
			return &"bleed"
		&"strength":
			return &"strength"
	return &""

func _apply_player_attack_mods(base: int, tags: Array[CardData.Tag] = [], consume: bool = true) -> int:
	var dmg := base + int(player_status.get("strength", 0))
	if CardData.Tag.MELEE in tags and int(player_buffs.get("melee_power", 0)) > 0:
		dmg += 3
	if int(player_buffs.get("overcharge", 0)) > 0 and ap <= 0:
		dmg += 3
	if int(player_status.get("weak", 0)) > 0:
		dmg = int(dmg * 0.75)
	if CardData.Tag.RANGED in tags and int(player_buffs.get("ranged_double", 0)) > 0:
		dmg *= 2
		if consume:
			player_buffs["ranged_double"] = int(player_buffs.get("ranged_double", 0)) - 1
			player_buffs_changed.emit(player_buffs)
	return maxi(0, dmg)

func _apply_weak(base: int, weak_active: bool) -> int:
	if weak_active:
		return int(base * 0.75)
	return base

func _add_enemy_status(idx: int, status: StringName, stacks: int) -> void:
	if idx < 0 or idx >= enemies.size():
		return
	if not enemies[idx]["alive"]:
		return
	var s: Dictionary = enemies[idx]["status"]
	s[status] = int(s.get(status, 0)) + stacks
	enemy_status_changed.emit(idx, s)

func _decay_debuffs(status: Dictionary) -> void:
	status["weak"] = maxi(0, int(status.get("weak", 0)) - 1)
	status["vulnerable"] = maxi(0, int(status.get("vulnerable", 0)) - 1)
	status["burn"] = maxi(0, int(status.get("burn", 0)) - 1)
	status["bleed"] = maxi(0, int(status.get("bleed", 0)) - 1)

# 敵への継続ダメージを適用。撃破されたら true。
func _apply_dot_to_enemy(idx: int) -> bool:
	var enemy := enemies[idx]
	var s: Dictionary = enemy["status"]
	var dot: int = int(s.get("burn", 0)) + int(s.get("bleed", 0))
	if dot > 0:
		enemy["hp"] = maxi(0, enemy["hp"] - dot)
		enemy_hp_changed.emit(idx, enemy["hp"], enemy["max_hp"])
		if enemy["hp"] <= 0:
			enemy["alive"] = false
			_decay_debuffs(s)
			enemy_status_changed.emit(idx, s)
			enemy_defeated.emit(idx)
			return true
	return false

func _tick_player_statuses() -> void:
	var dot: int = int(player_status.get("burn", 0)) + int(player_status.get("bleed", 0))
	if dot > 0:
		player_hp = maxi(0, player_hp - dot)
		player_hp_changed.emit(player_hp, player_max_hp)
	_decay_debuffs(player_status)
	player_status_changed.emit(player_status)

func _tick_player_buffs() -> void:
	var changed := false
	for key: String in ["melee_power", "overcharge", "ultimate"]:
		var val: int = int(player_buffs.get(key, 0))
		if val > 0:
			player_buffs[key] = val - 1
			changed = true
	if changed:
		player_buffs_changed.emit(player_buffs)

func _is_cultist() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"acceleration"

func _is_player_effect(effect: StringName) -> bool:
	match effect:
		&"overcharge", &"melee_power", &"ranged_double":
			return true
	return false

func _apply_player_effect(effect: StringName, stacks: int) -> void:
	match effect:
		&"overcharge":
			player_buffs["overcharge"] = maxi(int(player_buffs.get("overcharge", 0)), stacks)
		&"melee_power":
			player_buffs["melee_power"] = maxi(int(player_buffs.get("melee_power", 0)), stacks)
		&"ranged_double":
			player_buffs["ranged_double"] = int(player_buffs.get("ranged_double", 0)) + stacks
	player_buffs_changed.emit(player_buffs)

func _add_acceleration(amount: int) -> void:
	if acceleration_gauge >= ACCELERATION_MAX:
		return
	acceleration_gauge = mini(acceleration_gauge + amount, ACCELERATION_MAX)
	acceleration_changed.emit(acceleration_gauge, ACCELERATION_MAX)
	if acceleration_gauge >= ACCELERATION_MAX:
		_activate_ultimate()

func _activate_ultimate() -> void:
	player_buffs["ultimate"] = 3
	acceleration_gauge = 0
	acceleration_changed.emit(acceleration_gauge, ACCELERATION_MAX)
	player_buffs_changed.emit(player_buffs)
	DeckManager.draw_cards(3)
	ultimate_activated.emit()

func _fill_acceleration_from_card(card: CardData) -> void:
	if card.get_effective_damage() > 0:
		_add_acceleration(ACCEL_ATTACK)
	else:
		_add_acceleration(ACCEL_BUFF)

