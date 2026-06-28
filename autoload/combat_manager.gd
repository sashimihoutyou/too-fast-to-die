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
signal heat_changed(value: int, max_value: int)
signal acceleration_changed(gauge: int, max_gauge: int)
signal aura_changed(value: int, max_value: int)
signal euphoria_changed(value: int, max_value: int)
signal player_buffs_changed(buffs: Dictionary)
signal ultimate_activated()
signal climax_activated()
signal beast_changed()

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

# 元レイダー固有資源「ヒート（激情）」
const HEAT_MAX: int = 100
var player_heat: int = 0

# 覇者固有資源「闘気（オーラ）」
const AURA_MAX: int = 100
var player_aura: int = 0

# 享楽者固有資源「エクスタシー」
const EUPHORIA_MAX: int = 100
var player_euphoria: int = 0
var _climax_active: bool = false
var _overdose_pending: bool = false
var _love_slave_used_this_combat: bool = false
const LOVE_SLAVE_CARD_ID := &"eu11"
const LOVE_SLAVE_CHARM_THRESHOLD := 3

# 調教師固有「獣スロット」
var player_beasts: Array[Dictionary] = []
const BEAST_MAX := 5

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
	player_heat = 0
	player_aura = 0
	player_euphoria = 50 if _is_hedonist() else 0
	player_beasts.clear()
	player_buffs = _new_buffs_dict()
	acceleration_gauge = 0
	_climax_active = false
	_overdose_pending = false
	_love_slave_used_this_combat = false

func start_combat(enemy_list: Array[EnemyData], boss_hp_scale: float = 1.0) -> void:
	state = CombatState.INIT
	turn_number = 0
	player_max_hp = GameManager.current_character.max_hp
	player_hp = mini(player_hp, player_max_hp)
	player_block = 0
	player_status = _new_status_dict()
	player_buffs = _new_buffs_dict()
	acceleration_gauge = 0
	_climax_active = false
	_overdose_pending = false
	_love_slave_used_this_combat = false
	if _is_hedonist() and player_euphoria >= EUPHORIA_MAX:
		player_euphoria = 0
	player_status_changed.emit(player_status)
	player_heat = 0
	heat_changed.emit(player_heat, HEAT_MAX)
	player_aura = 0
	aura_changed.emit(player_aura, AURA_MAX)
	if _is_hedonist():
		euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)
	player_buffs_changed.emit(player_buffs)
	acceleration_changed.emit(acceleration_gauge, ACCELERATION_MAX)
	enemies.clear()
	for ed: EnemyData in enemy_list:
		var ehp := ed.base_hp
		if ed.is_boss and boss_hp_scale != 1.0:
			ehp = maxi(1, int(round(float(ed.base_hp) * boss_hp_scale)))
		enemies.append({
			"data": ed,
			"hp": ehp,
			"max_hp": ehp,
			"block": 0,
			"alive": true,
			"intent": {},
			"turn_counter": 0,
			"status": _new_status_dict(),
		})
	_apply_relic_triggers(ItemData.TriggerTiming.ON_COMBAT_START)
	DeckManager.start_combat()
	begin_turn()

func begin_turn() -> void:
	turn_number += 1
	state = CombatState.PLAYER_TURN
	ap = max_ap
	ap_cost_reduction = 0
	player_block = 0
	player_block_changed.emit(player_block)

	# オーバードーズ（享楽者：クライマックス翌ターン）
	if _overdose_pending:
		_overdose_pending = false
		ap = 0
		player_hp = maxi(1, ceili(float(player_hp) / 2.0))
		player_max_hp = maxi(1, player_max_hp - 3)
		player_hp = mini(player_hp, player_max_hp)
		player_hp_changed.emit(player_hp, player_max_hp)

	# ユーフォリアゾーンによるAP補正
	if _is_hedonist():
		if player_euphoria <= 9:
			ap = maxi(0, ap - 2)
			_damage_player(2)
		elif player_euphoria <= 32:
			ap = maxi(0, ap - 1)
		elif player_euphoria >= 75 and player_euphoria < 100:
			ap += 1

	_apply_relic_triggers(ItemData.TriggerTiming.ON_TURN_START)
	_tick_player_statuses()
	if player_hp <= 0:
		state = CombatState.DEFEAT
		combat_lost.emit()
		return

	# 獣の自動攻撃（調教師）
	if _is_beast_master():
		_beast_auto_attack()

	ap_changed.emit(ap)
	_update_all_intents()

	var draw_count := DeckManager.HAND_SIZE
	if _is_hedonist() and player_euphoria >= 75 and player_euphoria < 100:
		draw_count += 1
	if _is_hedonist() and player_euphoria <= 9:
		draw_count = maxi(1, draw_count - 1)
	if _has_companion(CompanionData.CompanionType.TRAITOR):
		draw_count += 1
	DeckManager.draw_cards(draw_count)
	_maybe_add_love_slave_card()
	turn_started.emit(turn_number)

func get_effective_ap_cost(card: CardData) -> int:
	var reduction := ap_cost_reduction
	if int(player_buffs.get("ultimate", 0)) > 0:
		reduction += 1
	if _climax_active:
		return 0
	if reduction > 0:
		return maxi(0, card.ap_cost - reduction)
	return card.ap_cost

func preview_damage(card: CardData, idx: int) -> int:
	if idx < 0 or idx >= enemies.size():
		return 0
	var base := card.get_effective_damage()
	if card.id == &"er01":
		if card.upgraded:
			base = int(player_heat / 2.0)
		else:
			base = int(player_heat / 3.0)
	elif card.id == &"er06" and player_heat >= HEAT_MAX / 2:
		base += 5
	elif card.id == &"co08":
		base = int(player_aura / 2.0)
		if card.upgraded:
			base = int(float(player_aura) * 0.75)
	elif card.id == &"co10" and player_aura >= 80:
		base *= 3
	elif card.id == &"bm07" and not player_beasts.is_empty():
		var bonus: int = 7 if card.upgraded else 5
		base += bonus
	elif card.id == &"st_we02":
		if DeckManager.master_deck.size() <= 15:
			var bonus: int = 3 if card.upgraded else 2
			base += bonus
	if base <= 0:
		return 0
	var per_hit := _apply_player_attack_mods(base, card.tags, false)
	if _climax_active:
		per_hit *= 2
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
	if card.id == LOVE_SLAVE_CARD_ID:
		if _love_slave_used_this_combat:
			return false
		if not _has_love_slave_target():
			return false
	if _climax_active:
		return true
	var cost := get_effective_ap_cost(card)
	if cost > ap and int(player_buffs.get("overcharge", 0)) <= 0:
		return false
	if card.fuel_cost > 0 and ResourceManager.fuel < card.fuel_cost:
		return false
	return true

func can_target_card(card: CardData, target_idx: int) -> bool:
	if target_idx < 0 or target_idx >= enemies.size():
		return false
	if card.id == LOVE_SLAVE_CARD_ID:
		return _is_love_slave_target(target_idx)
	return bool(enemies[target_idx]["alive"])

func has_playable_card() -> bool:
	for card: CardData in DeckManager.hand:
		if can_play_card(card):
			return true
	return false

func play_card(card: CardData, target_idx: int = -1) -> void:
	if not can_play_card(card):
		return
	if card.id == LOVE_SLAVE_CARD_ID and not _is_love_slave_target(target_idx):
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

	# クライマックス終了処理
	if _climax_active:
		_climax_active = false
		player_euphoria = 0
		euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)
		var all_dead := true
		for enemy: Dictionary in enemies:
			if enemy["alive"]:
				all_dead = false
				break
		if not all_dead:
			_overdose_pending = true

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
	# --- ヒート消費系の特殊カード ---
	if card.id == &"er01":
		if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
			var divisor: float = 2.0 if card.upgraded else 3.0
			var rampage := _apply_player_attack_mods(int(player_heat / divisor))
			if _climax_active:
				rampage *= 2
			_damage_enemy(target_idx, rampage, card.tags)
		return
	if card.id == &"er08":
		if player_heat > 0:
			player_block += player_heat
			player_block_changed.emit(player_block)
			_add_heat(-player_heat)
		if card.upgraded:
			DeckManager.draw_cards(3)
		return

	# --- 覇者 闘気開放 ---
	if card.id == &"co08":
		if player_aura >= 50:
			var aura_dmg: int = 0
			if card.upgraded:
				aura_dmg = int(float(player_aura) * 0.75)
			else:
				aura_dmg = int(player_aura / 2.0)
			var hit := _apply_player_attack_mods(aura_dmg, card.tags)
			if _climax_active:
				hit *= 2
			for i in enemies.size():
				if enemies[i]["alive"]:
					_damage_enemy(i, hit, card.tags)
			_add_aura(-player_aura)
		return

	# --- 覇者 百裂拳 ---
	if card.id == &"co07":
		if player_aura >= AURA_MAX:
			var per_hit := card.get_effective_damage()
			var hit := _apply_player_attack_mods(per_hit, card.tags)
			if _climax_active:
				hit *= 2
			if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				for h in card.hit_count:
					if enemies[target_idx]["alive"]:
						_damage_enemy(target_idx, hit, card.tags)
			_add_aura(-player_aura)
		return

	# --- 愛の奴隷（享楽者）---
	if card.id == LOVE_SLAVE_CARD_ID:
		if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
			var charm_stacks: int = int(enemies[target_idx]["status"].get("charm", 0))
			if charm_stacks >= LOVE_SLAVE_CHARM_THRESHOLD:
				_love_slave_used_this_combat = true
				_recruit_love_slave()
				enemies[target_idx]["alive"] = false
				enemies[target_idx]["hp"] = 0
				enemy_hp_changed.emit(target_idx, 0, enemies[target_idx]["max_hp"])
				enemy_defeated.emit(target_idx)
		return

	# --- ロミオとジュリエット（享楽者最強技）---
	if card.id == &"eu_new1":
		if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
			var hit := _apply_player_attack_mods(card.get_effective_damage(), card.tags)
			if _climax_active:
				hit *= 2
			for h in card.hit_count:
				if enemies[target_idx]["alive"]:
					_damage_enemy(target_idx, hit, card.tags)
			# 追加の近接15ダメージ
			if enemies[target_idx]["alive"]:
				var melee_hit := _apply_player_attack_mods(15, [CardData.Tag.MELEE])
				if _climax_active:
					melee_hit *= 2
				_damage_enemy(target_idx, melee_hit, [CardData.Tag.MELEE])
		if card.status_effect == &"euphoria":
			_add_euphoria(card.status_stacks)
		return

	# --- 調教師 獣カード ---
	if card.id == &"bm02":
		_beast_auto_attack()
		if card.upgraded:
			player_block += card.get_effective_block()
			player_block_changed.emit(player_block)
		return
	if card.id == &"bm03":
		_heal_beasts(8 if card.upgraded else 5)
		return
	if card.id == &"bm04":
		_buff_beasts_attack(4 if card.upgraded else 3)
		return
	if card.id == &"bm06":
		_beast_auto_attack()
		_beast_auto_attack()
		return
	if card.id == &"bm09":
		_summon_random_beast()
		return

	var dmg := card.get_effective_damage()
	var blk := card.get_effective_block()

	# バーサーカースラッシュ: ヒート50%以上で+5
	if card.id == &"er06" and player_heat >= HEAT_MAX / 2:
		dmg += 5

	# 覇者 昇龍拳: ダメージ分のブロック付与
	if card.id == &"co05":
		var bonus_blk := dmg
		blk += bonus_blk

	# 覇者 不動の構え: 闘気50%以上で+4ブロック
	if card.id == &"co09" and player_aura >= AURA_MAX / 2:
		blk += 4

	# 覇者 一撃必殺: 闘気80%以上で3倍ダメージ
	if card.id == &"co10" and player_aura >= 80:
		dmg *= 3

	# 放浪者 サバイバルナイフ: デッキ15枚以下で+2(+3)
	if card.id == &"st_we02" and DeckManager.master_deck.size() <= 15:
		dmg += 3 if card.upgraded else 2

	# 放浪者 共鳴の鞭: 場に獣がいれば+5(+7)
	if card.id == &"bm07" and not player_beasts.is_empty():
		dmg += 7 if card.upgraded else 5

	# 放浪者 ワンマンアーミー: 同行者なしで全攻撃+4(+6)
	if card.id == &"wa09" and _is_lone_wolf():
		var bonus: int = 6 if card.upgraded else 4
		player_buffs["strength_turn"] = bonus
		player_status["strength"] = int(player_status.get("strength", 0)) + bonus
		player_status_changed.emit(player_status)

	if blk > 0:
		player_block += blk
		player_block_changed.emit(player_block)

	if card.self_damage > 0:
		_damage_player(card.self_damage)

	if card.draw_count > 0:
		DeckManager.draw_cards(card.draw_count)

	# 放浪者 孤狼の勘: 同行者なしで追加ドロー
	if card.id == &"wa02" and _is_lone_wolf():
		DeckManager.draw_cards(1)

	# 放浪者 バレットタイム: デッキ15枚以下で追加ドロー
	if card.id == &"wa04" and DeckManager.master_deck.size() <= 15:
		DeckManager.draw_cards(1)
		if card.upgraded:
			DeckManager.draw_cards(1)

	if card.bonus_ap > 0:
		ap += card.bonus_ap
		ap_changed.emit(ap)

	var killed_with_card := false
	if dmg > 0:
		var hit_dmg := _apply_player_attack_mods(dmg, card.tags)
		if _climax_active:
			hit_dmg *= 2
		if card.is_aoe:
			for i in enemies.size():
				if enemies[i]["alive"]:
					_damage_enemy(i, hit_dmg * card.hit_count, card.tags)
					if enemies[i]["hp"] <= 0:
						killed_with_card = true
		else:
			if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				for h in card.hit_count:
					if enemies[target_idx]["alive"]:
						_damage_enemy(target_idx, hit_dmg, card.tags)
				if enemies[target_idx]["hp"] <= 0:
					killed_with_card = true

	# 敵デバフ
	if card.status_effect != &"" and card.status_stacks != 0:
		if _is_player_effect(card.status_effect):
			_apply_player_effect(card.status_effect, card.status_stacks)
		elif card.status_effect == &"charm":
			# 魅了は享楽者固有デバフ（status dictに直接入れる）
			if card.is_aoe:
				for i in enemies.size():
					if enemies[i]["alive"]:
						_add_enemy_status(i, &"charm", card.status_stacks)
			elif target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				_add_enemy_status(target_idx, &"charm", card.status_stacks)
			# 魅了カードもユーフォリアゲージを増やす（eu01, eu03, eu07, eu08のゲージ+分）
			if _is_hedonist():
				var eu_gain: int = 5
				if card.id == &"eu07":
					eu_gain = 10
				elif card.id == &"eu08":
					eu_gain = 15
				_add_euphoria(eu_gain)
			_maybe_add_love_slave_card()
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

	# ヒート（激情）資源ゲイン
	if card.status_effect == &"heat":
		_add_heat(card.status_stacks)

	# オーラ（闘気）資源ゲイン
	if card.status_effect == &"aura":
		_add_aura(card.status_stacks)

	# ユーフォリア資源ゲイン
	if card.status_effect == &"euphoria" and _is_hedonist():
		_add_euphoria(card.status_stacks)

	# 怒りの咆哮: 全敵の次攻撃力-2(-3)
	if card.id == &"er10":
		var atk_down_val: int = 3 if card.upgraded else 2
		for i in enemies.size():
			if enemies[i]["alive"]:
				_add_enemy_status(i, &"atk_down", atk_down_val)

	# 血の記憶: このカードで敵を撃破したらヒート-10
	if card.id == &"er07" and killed_with_card:
		_add_heat(-10)

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
			var defeated_data: EnemyData = enemies[i]["data"]
			QuestManager.on_enemy_defeated(defeated_data)
			enemy_defeated.emit(i)
		if enemies[i]["alive"]:
			all_dead = false
	if all_dead:
		_clear_climax_after_victory()
		state = CombatState.VICTORY
		combat_won.emit(_generate_rewards())

func _clear_climax_after_victory() -> void:
	if not _climax_active:
		return
	_climax_active = false
	_overdose_pending = false
	player_euphoria = 0
	euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)

func _execute_enemy_turns() -> void:
	for i in enemies.size():
		if not enemies[i]["alive"]:
			continue
		if _apply_dot_to_enemy(i):
			continue
		var status: Dictionary = enemies[i]["status"]

		var weak_active := int(status.get("weak", 0)) > 0
		var intent: Dictionary = enemies[i]["intent"]
		enemies[i]["block"] = 0
		enemy_block_changed.emit(i, 0)
		var atk_down: int = int(status.get("atk_down", 0))
		var fighter_reduce: int = 1 if _has_companion(CompanionData.CompanionType.FIGHTER) else 0
		match intent.get("type", ""):
			"attack":
				var dmg: int = maxi(0, _apply_weak(intent.get("value", 0), weak_active) - atk_down - fighter_reduce)
				var hits: int = intent.get("hits", 1)
				for h in hits:
					_damage_player(dmg, true)
				status["atk_down"] = 0
			"defend":
				var blk: int = intent.get("value", 0)
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
			"attack_defend":
				var dmg: int = maxi(0, _apply_weak(intent.get("attack", 0), weak_active) - atk_down - fighter_reduce)
				var blk: int = intent.get("block", 0)
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
				_damage_player(dmg, true)
				status["atk_down"] = 0
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
	var fuel_min := 6 + act * 2
	var fuel_max := 11 + act * 3
	if is_elite:
		fuel_min += 6
		fuel_max += 8
	rewards.append({"type": "fuel", "amount": randi_range(fuel_min, fuel_max)})
	if has_machine:
		rewards.append({"type": "scrap", "amount": randi_range(3, 6)})
	var card_slots := 2 if is_elite else 1
	for i in card_slots:
		rewards.append({"type": "card"})
	if is_elite and randf() < 0.5:
		var relics := ItemDatabase.get_items_by_type(ItemData.ItemType.RELIC)
		if not relics.is_empty():
			relics.shuffle()
			rewards.append({"type": "relic", "item_id": relics[0].id})
	elif randf() < 0.25:
		var consumables := ItemDatabase.get_items_by_type(ItemData.ItemType.CONSUMABLE)
		if not consumables.is_empty():
			consumables.shuffle()
			rewards.append({"type": "consumable", "item_id": consumables[0].id})
	return rewards

# ===== ステータス効果システム =====

func _new_status_dict() -> Dictionary:
	return {"weak": 0, "vulnerable": 0, "burn": 0, "bleed": 0, "strength": 0, "atk_down": 0, "charm": 0}

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
		&"atk_down":
			return &"atk_down"
	return &""

func _apply_player_attack_mods(base: int, tags: Array[CardData.Tag] = [], consume: bool = true) -> int:
	var dmg := base + int(player_status.get("strength", 0))
	if CardData.Tag.BIKE in tags:
		dmg += ResourceManager.get_stat_bonus("bike_attack_bonus")
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

func _maybe_add_love_slave_card() -> void:
	if not _is_hedonist():
		return
	if _love_slave_used_this_combat:
		return
	if DeckManager.has_card_id_in_hand(LOVE_SLAVE_CARD_ID):
		return
	if not _has_love_slave_target():
		return
	DeckManager.add_temporary_card_to_hand(LOVE_SLAVE_CARD_ID)

func _recruit_love_slave() -> void:
	var companion: CompanionData = CompanionDatabase.get_companion(&"love_slave")
	if companion == null:
		return
	GameManager.recruit_companion(companion)

func _has_love_slave_target() -> bool:
	for i: int in range(enemies.size()):
		if _is_love_slave_target(i):
			return true
	return false

func _is_love_slave_target(idx: int) -> bool:
	if idx < 0 or idx >= enemies.size():
		return false
	if not bool(enemies[idx]["alive"]):
		return false
	var data: EnemyData = enemies[idx]["data"]
	if data.is_boss:
		return false
	if data.category == EnemyData.Category.MACHINE:
		return false
	var status: Dictionary = enemies[idx]["status"]
	return int(status.get("charm", 0)) >= LOVE_SLAVE_CHARM_THRESHOLD

func _decay_debuffs(status: Dictionary) -> void:
	status["weak"] = maxi(0, int(status.get("weak", 0)) - 1)
	status["vulnerable"] = maxi(0, int(status.get("vulnerable", 0)) - 1)
	status["burn"] = maxi(0, int(status.get("burn", 0)) - 1)
	status["bleed"] = maxi(0, int(status.get("bleed", 0)) - 1)

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
			var defeated_data: EnemyData = enemy["data"]
			QuestManager.on_enemy_defeated(defeated_data)
			enemy_defeated.emit(idx)
			return true
	return false

func _tick_player_statuses() -> void:
	var dot: int = int(player_status.get("burn", 0)) + int(player_status.get("bleed", 0))
	if dot > 0:
		player_hp = maxi(0, player_hp - dot)
		player_hp_changed.emit(player_hp, player_max_hp)
	# ワンマンアーミーの一時筋力をリセット
	var str_turn: int = int(player_buffs.get("strength_turn", 0))
	if str_turn > 0:
		player_status["strength"] = maxi(0, int(player_status.get("strength", 0)) - str_turn)
		player_buffs["strength_turn"] = 0
	_decay_debuffs(player_status)
	player_status_changed.emit(player_status)

# ===== ヒート（激情）=====
func _add_heat(amount: int) -> void:
	player_heat = clampi(player_heat + amount, 0, HEAT_MAX)
	heat_changed.emit(player_heat, HEAT_MAX)

# ===== オーラ（闘気）=====
func _add_aura(amount: int) -> void:
	player_aura = clampi(player_aura + amount, 0, AURA_MAX)
	aura_changed.emit(player_aura, AURA_MAX)

# ===== エクスタシー =====
func _add_euphoria(amount: int) -> void:
	player_euphoria = clampi(player_euphoria + amount, 0, EUPHORIA_MAX)
	euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)
	if player_euphoria >= EUPHORIA_MAX and not _climax_active:
		_activate_climax()

func _activate_climax() -> void:
	_climax_active = true
	DeckManager.discard_hand()
	DeckManager.draw_cards(7)
	_maybe_add_love_slave_card()
	climax_activated.emit()

# ===== 獣システム =====
func _beast_auto_attack() -> void:
	for beast: Dictionary in player_beasts:
		if not beast.get("alive", false):
			continue
		var atk: int = beast.get("attack", 3)
		for i in enemies.size():
			if enemies[i]["alive"]:
				_damage_enemy(i, atk)
				break
	beast_changed.emit()

func add_beast(beast_name: String, hp: int, atk: int) -> void:
	if player_beasts.size() >= BEAST_MAX:
		return
	player_beasts.append({"name": beast_name, "hp": hp, "max_hp": hp, "attack": atk, "alive": true})
	beast_changed.emit()

func _heal_beasts(amount: int) -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		var max_hp: int = int(beast.get("max_hp", 0))
		beast["hp"] = mini(max_hp, int(beast.get("hp", 0)) + amount)
	beast_changed.emit()

func _buff_beasts_attack(amount: int) -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		beast["attack"] = int(beast.get("attack", 0)) + amount
	beast_changed.emit()

func _summon_random_beast() -> void:
	var candidates: Array[Dictionary] = [
		{"name": "野犬", "hp": 8, "attack": 3},
		{"name": "砂狐", "hp": 6, "attack": 4},
		{"name": "荒野の鷹", "hp": 5, "attack": 5},
	]
	var pick: Dictionary = candidates[randi() % candidates.size()]
	add_beast(String(pick.get("name", "獣")), int(pick.get("hp", 6)), int(pick.get("attack", 3)))

func damage_beast(idx: int, amount: int) -> void:
	if idx < 0 or idx >= player_beasts.size():
		return
	var beast := player_beasts[idx]
	if not beast.get("alive", false):
		return
	beast["hp"] = maxi(0, beast["hp"] - amount)
	if beast["hp"] <= 0:
		beast["alive"] = false
	beast_changed.emit()

func _tick_player_buffs() -> void:
	var changed := false
	for key: String in ["melee_power", "overcharge", "ultimate"]:
		var val: int = int(player_buffs.get(key, 0))
		if val > 0:
			player_buffs[key] = val - 1
			changed = true
	if changed:
		player_buffs_changed.emit(player_buffs)

# ===== キャラ判定ヘルパー =====
func _is_cultist() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"acceleration"

func _is_wanderer() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"lone_wolf"

func _is_conqueror() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"aura"

func _is_beast_master() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"beast"

func _is_hedonist() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"euphoria"

func _is_lone_wolf() -> bool:
	if not _is_wanderer():
		return false
	return GameManager.current_companion == null

func _has_companion(comp_type: CompanionData.CompanionType) -> bool:
	if GameManager.current_companion == null:
		return false
	return GameManager.current_companion.companion_type == comp_type

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

func _apply_relic_triggers(timing: ItemData.TriggerTiming) -> void:
	for relic: ItemData in ItemDatabase.get_relics():
		if relic.trigger != timing:
			continue
		if relic.hp_change != 0:
			player_hp = clampi(player_hp + relic.hp_change, 0, player_max_hp)
			player_hp_changed.emit(player_hp, player_max_hp)
		if relic.block_change > 0:
			player_block += relic.block_change
			player_block_changed.emit(player_block)
		if relic.draw_change > 0:
			DeckManager.draw_cards(relic.draw_change)

# ===== 汚染カードのドロー時効果 =====
func apply_contamination_on_draw(card: CardData) -> void:
	match card.id:
		&"con01":
			ap = maxi(0, ap - 1)
			ap_changed.emit(ap)
		&"con02":
			ap = maxi(0, ap - 1)
			ap_changed.emit(ap)
			_damage_player(2)
		&"con03":
			ap = maxi(0, ap - 1)
			ap_changed.emit(ap)
			var debuffs: Array[StringName] = [&"weak", &"vulnerable"]
			var chosen := debuffs[randi() % debuffs.size()]
			player_status[chosen] = int(player_status.get(chosen, 0)) + 1
			player_status_changed.emit(player_status)
		&"con04":
			ap = maxi(0, ap - 1)
			ap_changed.emit(ap)
			for i in enemies.size():
				if enemies[i]["alive"]:
					enemies[i]["block"] += 2
					enemy_block_changed.emit(i, enemies[i]["block"])
