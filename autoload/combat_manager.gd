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
signal investigation_changed(value: int, max_value: int)
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

# 覇者NPCカード用資源「闘気（オーラ）」
const AURA_MAX: int = 100
var player_aura: int = 0

# アータル固有資源「速度（ギア）」
const GEAR_MIN: int = 1
const GEAR_MAX: int = 6
const FULL_THROTTLE_TURNS: int = 2
var player_gear: int = GEAR_MIN
var _free_bike_fuel_turns: int = 0
var _engine_brake_used_this_turn: bool = false
var _regular_draw_done: bool = false
var _skip_regular_draw_this_turn: bool = false

# ウェズリー固有資源「調査ゲージ」
const INVESTIGATION_MAX: int = 5
var player_investigation: int = INVESTIGATION_MAX

# 享楽者固有資源「エクスタシー」
const EUPHORIA_MAX: int = 100
var player_euphoria: int = 0
var _climax_active: bool = false
var _overdose_pending: bool = false
var _overdose_resolved_this_combat: bool = false
var _love_slave_used_this_combat: bool = false
const LOVE_SLAVE_CARD_ID := &"eu11"
const LOVE_SLAVE_CHARM_THRESHOLD := 3

# ミーシャ固有「相棒スロット」
var player_beasts: Array[Dictionary] = []
const BEAST_BASE_MAX := 1
const BEAST_ABSOLUTE_MAX := 3
var _tiger_down_next_combat: bool = false

var enemies: Array[Dictionary] = []
var player_buffs: Dictionary = {}
var _quickdraw_added_this_turn: Dictionary = {}

func _new_buffs_dict() -> Dictionary:
	return {"melee_power": 0, "ranged_double": 0, "overcharge": 0, "ultimate": 0, "partner_defense": 0, "companion_guard": 0, "herd_fatigue": 0}

func reset_player_for_new_run() -> void:
	player_max_hp = GameManager.current_character.max_hp
	player_hp = player_max_hp
	player_status = _new_status_dict()
	player_heat = 0
	player_aura = 0
	player_gear = GEAR_MIN
	player_investigation = INVESTIGATION_MAX
	player_euphoria = 50 if _is_hedonist() else 0
	player_beasts.clear()
	_tiger_down_next_combat = false
	player_buffs = _new_buffs_dict()
	_quickdraw_added_this_turn.clear()
	_free_bike_fuel_turns = 0
	_engine_brake_used_this_turn = false
	_regular_draw_done = false
	_skip_regular_draw_this_turn = false
	_climax_active = false
	_overdose_pending = false
	_overdose_resolved_this_combat = false
	_love_slave_used_this_combat = false
	_quickdraw_added_this_turn.clear()

func start_combat(enemy_list: Array[EnemyData], boss_hp_scale: float = 1.0) -> void:
	state = CombatState.INIT
	turn_number = 0
	player_max_hp = GameManager.current_character.max_hp
	player_hp = mini(player_hp, player_max_hp)
	player_block = 0
	player_status = _new_status_dict()
	player_buffs = _new_buffs_dict()
	player_gear = GEAR_MIN
	player_investigation = INVESTIGATION_MAX
	_free_bike_fuel_turns = 0
	_engine_brake_used_this_turn = false
	_regular_draw_done = false
	_skip_regular_draw_this_turn = false
	_climax_active = false
	_overdose_pending = false
	_overdose_resolved_this_combat = false
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
	if _is_wanderer():
		investigation_changed.emit(player_investigation, INVESTIGATION_MAX)
	player_buffs_changed.emit(player_buffs)
	acceleration_changed.emit(player_gear, GEAR_MAX)
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
			"beast_card_granted": false,
		})
	if _is_beast_master():
		player_beasts.clear()
		_add_tiger_at_combat_start()
	_apply_relic_triggers(ItemData.TriggerTiming.ON_COMBAT_START)
	DeckManager.start_combat()
	begin_turn()

func begin_turn() -> void:
	turn_number += 1
	state = CombatState.PLAYER_TURN
	_quickdraw_added_this_turn.clear()
	_apply_herd_fatigue_start_of_turn()
	_advance_beast_survival_turns()
	ap = max_ap
	ap_cost_reduction = 0
	player_block = 0
	_engine_brake_used_this_turn = false
	_regular_draw_done = false
	_skip_regular_draw_this_turn = false
	player_block_changed.emit(player_block)

	if _is_cultist():
		_tick_gear_start_of_turn()

	if _is_wanderer():
		_tick_investigation_start_of_turn()

	# オーバードーズ（享楽者：クライマックス翌ターン）
	if _overdose_pending:
		_overdose_pending = false
		ap = 0
		player_hp = maxi(1, ceili(float(player_hp) / 2.0))
		player_max_hp = maxi(1, player_max_hp - 3)
		player_hp = mini(player_hp, player_max_hp)
		_overdose_resolved_this_combat = true
		player_hp_changed.emit(player_hp, player_max_hp)

	if _is_hedonist() and not _climax_active:
		_tick_euphoria_start_of_turn()

	# エクスタシーゾーンによるAP補正
	if _is_hedonist():
		if player_euphoria <= 9:
			ap = maxi(0, ap - 1)
			_damage_player(1)
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
	if _is_hedonist() and player_euphoria <= 9:
		draw_count = maxi(1, draw_count - 1)
	if _has_companion(CompanionData.CompanionType.TRAITOR):
		draw_count += 1
	if _is_cultist() and _is_full_throttle_active():
		draw_count += 2
	elif _is_cultist() and player_gear >= 4:
		draw_count += 1
	if _is_hedonist() and player_euphoria >= 60 and player_euphoria < 100:
		draw_count += 1
	if not _skip_regular_draw_this_turn:
		DeckManager.draw_cards(draw_count)
	_regular_draw_done = true
	_maybe_add_love_slave_card()
	turn_started.emit(turn_number)

func get_effective_ap_cost(card: CardData) -> int:
	var reduction := ap_cost_reduction
	if int(player_buffs.get("ultimate", 0)) > 0:
		reduction += 1
	if _is_cultist() and player_gear >= 5 and CardData.Tag.BIKE in card.tags:
		reduction += 1
	if _climax_active:
		return 0
	if reduction > 0:
		return maxi(0, card.ap_cost - reduction)
	return card.ap_cost

func get_effective_fuel_cost(card: CardData) -> int:
	if _is_cultist() and _free_bike_fuel_turns > 0 and CardData.Tag.BIKE in card.tags:
		return 0
	return card.fuel_cost

func preview_damage(card: CardData, idx: int) -> int:
	if idx < 0 or idx >= enemies.size():
		return 0
	var base := card.get_effective_damage()
	if is_heat_card_transformed(card):
		base = card.get_effective_block()
	if card.id == &"er01":
		if player_heat < 70:
			return 0
		var remaining_heat := maxi(0, player_heat - 60)
		base = 25 + int(float(remaining_heat) * 0.5)
	elif card.id == &"er06" and player_heat >= HEAT_MAX / 2:
		base += 5
	elif card.id == &"co08":
		base = int(player_aura / 2.0)
		if card.upgraded:
			base = int(float(player_aura) * 0.75)
	elif card.id == &"co10" and player_aura >= 80:
		base *= 3
	elif card.id == &"bm07" and not player_beasts.is_empty():
		base = _get_total_beast_attack()
	elif card.id == &"st_we02":
		if DeckManager.master_deck.size() <= 15:
			var bonus: int = 3 if card.upgraded else 2
			base += bonus
	if base <= 0:
		return 0
	var preview_tags: Array[CardData.Tag] = []
	preview_tags.assign(card.tags)
	if is_heat_card_transformed(card):
		preview_tags.clear()
		preview_tags.append(CardData.Tag.MELEE)
		preview_tags.append(CardData.Tag.CHARACTER)
	var per_hit := _apply_player_attack_mods(base, preview_tags, false)
	if _climax_active:
		per_hit *= 2
	if is_weak_against(idx, preview_tags):
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
	if card.id == &"er01" and player_heat < 70:
		return false
	if card.id == &"wa06" and not _has_missing_link_target():
		return false
	if card.status_effect == &"investigate" and player_investigation <= 0:
		return false
	if _is_beast_card_id(card.id) and not _can_set_beast_from_card(card.id):
		return false
	if _requires_alive_beast(card.id) and _alive_beast_count() <= 0:
		return false
	if card.id == &"bm03" and not _has_wounded_beast():
		return false
	if card.id == &"bm05" and not _has_animal_card_to_whistle():
		return false
	if card.id == &"bm06" and not _can_use_herd_roar():
		return false
	if card.id == &"wa05" and not _has_exhaustable_hand_card(card.id):
		return false
	if card.id == &"wa08" and player_investigation <= 0:
		return false
	if card.id == &"wa08" and DeckManager.discard_pile.is_empty():
		return false
	if _climax_active:
		return true
	var cost := get_effective_ap_cost(card)
	if cost > ap and int(player_buffs.get("overcharge", 0)) <= 0:
		return false
	var fuel_cost := get_effective_fuel_cost(card)
	if fuel_cost > 0 and ResourceManager.fuel < fuel_cost:
		return false
	return true

func can_target_card(card: CardData, target_idx: int) -> bool:
	if target_idx < 0 or target_idx >= enemies.size():
		return false
	if card.id == LOVE_SLAVE_CARD_ID:
		return _is_love_slave_target(target_idx)
	if card.id == &"wa06":
		return _is_missing_link_target(target_idx)
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
	var fuel_cost := get_effective_fuel_cost(card)
	if fuel_cost > 0:
		ResourceManager.consume_fuel(fuel_cost)
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

	if _is_cultist() and not _is_full_throttle_active() and player_gear >= 3:
		player_block += 2
		player_block_changed.emit(player_block)

	if _is_hedonist() and player_euphoria >= 60 and player_euphoria <= 74:
		DeckManager.exhaust_random_card_from_hand()

	DeckManager.discard_hand()
	_tick_player_buffs()
	state = CombatState.ENEMY_TURN
	_execute_enemy_turns()
	_clear_partner_turn_state()
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
		if target_idx >= 0 and target_idx < enemies.size() and bool(enemies[target_idx]["alive"]):
			_add_heat(-60)
			var remaining_heat: int = player_heat
			var rampage: int = _apply_player_attack_mods(25 + int(float(remaining_heat) * 0.5), card.tags)
			if _climax_active:
				rampage *= 2
			_damage_enemy(target_idx, rampage, card.tags)
			if int(enemies[target_idx]["hp"]) <= 0 and player_heat >= 10:
				var follow_damage: int = int(float(rampage) * 0.5)
				for i: int in range(enemies.size()):
					if i != target_idx and bool(enemies[i]["alive"]):
						_add_heat(-10)
						_damage_enemy(i, follow_damage, card.tags)
						break
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
		if target_idx >= 0 and target_idx < enemies.size() and bool(enemies[target_idx]["alive"]):
			var charm_stacks: int = int(enemies[target_idx]["status"].get("charm", 0))
			if charm_stacks >= LOVE_SLAVE_CHARM_THRESHOLD:
				_love_slave_used_this_combat = true
				_recruit_love_slave()
				enemies[target_idx]["alive"] = false
				enemies[target_idx]["hp"] = 0
				enemy_hp_changed.emit(target_idx, 0, enemies[target_idx]["max_hp"])
				enemy_defeated.emit(target_idx)
		return

	# --- ウェズリー Q.E.D. ---
	if card.id == &"wa06":
		if target_idx >= 0 and _is_missing_link_target(target_idx):
			var qed_damage: int = _apply_player_attack_mods(card.get_effective_damage(), card.tags)
			if _climax_active:
				qed_damage *= 2
			_damage_enemy(target_idx, qed_damage, card.tags)
			_add_enemy_status(target_idx, &"stun", 1)
			_add_enemy_status(target_idx, &"guard_break", 2)
		return

	# --- ミーシャ 爆竹 ---
	if card.id == &"st_bm01":
		if randf() < 0.5:
			for i: int in range(enemies.size()):
				if bool(enemies[i]["alive"]):
					_add_enemy_status(i, &"stun", 1)
		return

	# --- ミーシャ 動物カード ---
	if _is_beast_card_id(card.id):
		_set_beast_from_card(card.id)
		return

	# --- ミーシャ 屈服の鞭 ---
	if card.id == &"bm01":
		if target_idx >= 0 and target_idx < enemies.size() and bool(enemies[target_idx]["alive"]):
			var target_data: EnemyData = enemies[target_idx]["data"]
			var whip_damage: int = _apply_player_attack_mods(card.get_effective_damage(), card.tags)
			if _climax_active:
				whip_damage *= 2
			_damage_enemy_ignore_block(target_idx, whip_damage, card.tags)
			if int(enemies[target_idx]["hp"]) <= 0 and target_data.category == EnemyData.Category.BEAST:
				_grant_beast_card_from_enemy(target_data)
				enemies[target_idx]["beast_card_granted"] = true
		return

	# --- ロミオとジュリエット（享楽者最強技）---
	if card.id == &"eu_new1":
		if target_idx >= 0 and target_idx < enemies.size() and bool(enemies[target_idx]["alive"]):
			var hit := _apply_player_attack_mods(card.get_effective_damage(), card.tags)
			if _climax_active:
				hit *= 2
			for h in card.hit_count:
				if bool(enemies[target_idx]["alive"]):
					_damage_enemy(target_idx, hit, card.tags)
			# 追加の近接15ダメージ
			if bool(enemies[target_idx]["alive"]):
				var melee_hit := _apply_player_attack_mods(15, [CardData.Tag.MELEE])
				if _climax_active:
					melee_hit *= 2
				_damage_enemy(target_idx, melee_hit, [CardData.Tag.MELEE])
		if card.status_effect == &"euphoria":
			_add_euphoria(card.status_stacks)
		return

	# --- 同行者カード ---
	if card.id == &"cc_refugee_prayer":
		if GameManager.has_companion_type(CompanionData.CompanionType.REFUGEE):
			player_buffs["companion_guard"] = maxi(int(player_buffs.get("companion_guard", 0)), 8)
			player_buffs_changed.emit(player_buffs)
		return
	if card.id == &"cc_technician_patch":
		ResourceManager.repair_bike(3)
		return

	# --- ミーシャ 相棒カード ---
	if card.id == &"bm02":
		_partner_attack_instruction()
		return
	if card.id == &"bm11":
		player_buffs["partner_defense"] = 1
		for beast: Dictionary in player_beasts:
			if bool(beast.get("alive", false)):
				beast["guard_bonus"] = int(beast.get("guard", 0))
		player_buffs_changed.emit(player_buffs)
		beast_changed.emit()
		return
	if card.id == &"bm05":
		_whistle_animal_card()
		return
	if card.id == &"bm06":
		_activate_herd_roar()
		return
	if card.id == &"bm03":
		_heal_most_wounded_beast(11 if card.upgraded else 8)
		return
	if card.id == &"bm04":
		_beasts_attack_once()
		return
	if card.id == &"bm07":
		if target_idx >= 0 and target_idx < enemies.size() and bool(enemies[target_idx]["alive"]):
			var fang_damage: int = _apply_player_attack_mods(_get_total_beast_attack(), card.tags)
			if _climax_active:
				fang_damage *= 2
			_damage_enemy(target_idx, fang_damage, card.tags)
		return
	if card.id == &"bm08":
		var shelter_block: int = card.get_effective_block()
		player_block += shelter_block
		player_block_changed.emit(player_block)
		_add_beast_guard_bonus(shelter_block)
		return
	if card.id == &"bm09":
		_summon_random_beast()
		return
	if card.id == &"bm10":
		_add_beast_guard_bonus(8 if not card.upgraded else 12)
		return

	# --- ウェズリー 手札/捨札操作 ---
	if card.id == &"wa05":
		_apply_recycler(card, target_idx)
		return
	if card.id == &"wa08":
		_add_investigation(-1)
		DeckManager.move_random_discard_card_to_hand()
		return

	var dmg := card.get_effective_damage()
	var blk := card.get_effective_block()
	var attack_tags: Array[CardData.Tag] = []
	attack_tags.assign(card.tags)
	if is_heat_card_transformed(card):
		dmg = blk
		blk = 0
		attack_tags.clear()
		attack_tags.append(CardData.Tag.MELEE)
		attack_tags.append(CardData.Tag.CHARACTER)

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
		var hit_dmg := _apply_player_attack_mods(dmg, attack_tags)
		if _climax_active:
			hit_dmg *= 2
		if card.is_aoe:
			for i in enemies.size():
				if enemies[i]["alive"]:
					_damage_enemy(i, hit_dmg * card.hit_count, attack_tags)
					if enemies[i]["hp"] <= 0:
						killed_with_card = true
		else:
			if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				for h in card.hit_count:
					if enemies[target_idx]["alive"]:
						_damage_enemy(target_idx, hit_dmg, attack_tags)
				if enemies[target_idx]["hp"] <= 0:
					killed_with_card = true

	# 敵デバフ
	if card.status_effect != &"" and card.status_stacks != 0:
		if _is_player_effect(card.status_effect):
			_apply_player_effect(card.status_effect, card.status_stacks)
		elif card.status_effect == &"charm":
			_apply_enemy_card_status(card, target_idx, &"charm", card.status_stacks)
			_maybe_add_love_slave_card()
		elif card.status_effect == &"investigate":
			if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["alive"]:
				_add_enemy_status(target_idx, &"investigation", card.status_stacks)
				_add_investigation(-1)
		else:
			var mapped := _map_status(card.status_effect)
			if mapped != &"":
				_apply_enemy_card_status(card, target_idx, mapped, card.status_stacks)

	if card.secondary_status_effect != &"" and card.secondary_status_stacks != 0:
		var secondary_mapped := _map_status(card.secondary_status_effect)
		if secondary_mapped != &"":
			_apply_enemy_card_status(card, target_idx, secondary_mapped, card.secondary_status_stacks)

	if card.euphoria_gain != 0 and _is_hedonist():
		_add_euphoria(card.euphoria_gain)

	if _is_cultist() and _gear_enabled() and GameManager.get_faith_band() == &"zealot" and CardData.Tag.BIKE in card.tags:
		_add_gear(1)

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

	if card.id == &"wa01" or card.id == &"wa07":
		_maybe_add_quickdraw_followup(card.id)
	if card.id == &"wa03":
		DeckManager.move_random_discard_card_to_draw_top()
	if card.id == &"wa10":
		DeckManager.duplicate_card_to_discard(card)

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

func _damage_enemy_ignore_block(idx: int, amount: int, source_tags: Array[CardData.Tag] = []) -> void:
	if idx < 0 or idx >= enemies.size():
		return
	var enemy: Dictionary = enemies[idx]
	if not bool(enemy["alive"]):
		return
	var remaining: int = amount
	if is_weak_against(idx, source_tags):
		remaining = int(remaining * 1.5)
	var enemy_status: Dictionary = enemy["status"]
	if int(enemy_status.get("vulnerable", 0)) > 0:
		remaining = int(remaining * 1.5)
	if remaining > 0:
		enemy["hp"] = maxi(0, int(enemy["hp"]) - remaining)
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
		if from_enemy and _is_beast_master():
			remaining = _redirect_damage_to_partners(remaining)
		if from_enemy and remaining > 0:
			var companion_guard: int = int(player_buffs.get("companion_guard", 0))
			if companion_guard > 0 and GameManager.has_any_companion():
				var redirected: int = mini(remaining, companion_guard)
				remaining -= redirected
				player_buffs["companion_guard"] = companion_guard - redirected
				player_buffs_changed.emit(player_buffs)
				GameManager.damage_current_companion(redirected)
		player_hp = maxi(0, player_hp - remaining)
		player_hp_changed.emit(player_hp, player_max_hp)
	if from_enemy and blocked > 0 and _is_heat_character():
		_add_heat(-int(float(blocked) * 0.3))
	if from_enemy and remaining > 0 and _is_heat_character():
		_add_heat(maxi(1, int(ceil(float(remaining) * 0.5))))

func _check_enemies_alive() -> void:
	var all_dead := true
	for i in enemies.size():
		var enemy_hp: int = int(enemies[i]["hp"])
		var enemy_alive: bool = bool(enemies[i]["alive"])
		if enemy_hp <= 0 and enemy_alive:
			enemies[i]["alive"] = false
			var defeated_data: EnemyData = enemies[i]["data"]
			QuestManager.on_enemy_defeated(defeated_data)
			if _is_beast_master() and defeated_data.category == EnemyData.Category.BEAST and not bool(enemies[i].get("beast_card_granted", false)):
				if randf() < 0.3:
					_grant_beast_card_from_enemy(defeated_data)
					enemies[i]["beast_card_granted"] = true
			if _is_heat_character():
				_add_heat(10)
			enemy_defeated.emit(i)
		if bool(enemies[i]["alive"]):
			all_dead = false
	if all_dead:
		if _overdose_resolved_this_combat and _is_hedonist():
			player_euphoria = 10
			euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)
		_clear_climax_after_victory()
		state = CombatState.VICTORY
		combat_won.emit(_generate_rewards())

func _clear_climax_after_victory() -> void:
	if not _climax_active:
		return
	_climax_active = false
	_overdose_pending = false
	player_euphoria = 40
	euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)

func _execute_enemy_turns() -> void:
	for i in enemies.size():
		if not bool(enemies[i]["alive"]):
			continue
		if _apply_dot_to_enemy(i):
			continue
		var status: Dictionary = enemies[i]["status"]
		if int(status.get("stun", 0)) > 0:
			status["stun"] = maxi(0, int(status.get("stun", 0)) - 1)
			_decay_debuffs(status)
			enemy_status_changed.emit(i, status)
			enemies[i]["turn_counter"] += 1
			continue

		var weak_active := int(status.get("weak", 0)) > 0
		var intent: Dictionary = enemies[i]["intent"]
		enemies[i]["block"] = 0
		enemy_block_changed.emit(i, 0)
		var atk_down: int = int(status.get("atk_down", 0))
		var charm_stacks: int = int(status.get("charm", 0))
		if charm_stacks >= 2:
			atk_down += 5
		elif charm_stacks >= 1:
			atk_down += 3
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
				if int(status.get("guard_break", 0)) > 0:
					blk = 0
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
			"attack_defend":
				var dmg: int = maxi(0, _apply_weak(intent.get("attack", 0), weak_active) - atk_down - fighter_reduce)
				var blk: int = intent.get("block", 0)
				if int(status.get("guard_break", 0)) > 0:
					blk = 0
				enemies[i]["block"] = blk
				enemy_block_changed.emit(i, enemies[i]["block"])
				_damage_player(dmg, true)
				status["atk_down"] = 0
		_decay_debuffs(status)
		enemy_status_changed.emit(i, status)
		enemies[i]["turn_counter"] += 1

func _update_all_intents() -> void:
	for i in enemies.size():
		if not bool(enemies[i]["alive"]):
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
	var atk := 4 + act * 2
	var blk := 3 + act * 2
	if data.is_elite:
		atk = int(atk * 1.4)
		blk = int(blk * 1.4)
	var alive_count: int = _alive_enemy_count()
	if alive_count >= 3:
		atk = maxi(1, int(float(atk) * 0.65))
	elif alive_count >= 2:
		atk = maxi(1, int(float(atk) * 0.8))

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

func _alive_enemy_count() -> int:
	var count: int = 0
	for enemy: Dictionary in enemies:
		if bool(enemy.get("alive", false)):
			count += 1
	return count

func _get_boss_intent(data: EnemyData, tc: int, hp_pct: float) -> Dictionary:
	var act := clampi(data.act, 1, GameManager.MAX_ACT)
	var atk := 6 + act * 2
	if hp_pct <= 0.5:
		if tc % 3 == 2:
			return {"type": "attack", "value": maxi(1, int(atk * 0.75)), "hits": 2, "label": "猛襲（二連）"}
		else:
			return {"type": "attack", "value": int(atk * 1.25), "label": "激昂の一撃"}
	else:
		if tc % 4 == 3:
			return {"type": "attack", "value": int(atk * 1.4), "label": "渾身の一撃"}
		elif tc % 4 == 1:
			return {"type": "defend", "value": 6 + act * 2, "label": "防御態勢"}
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
	return {"weak": 0, "vulnerable": 0, "burn": 0, "bleed": 0, "strength": 0, "atk_down": 0, "charm": 0, "investigation": 0, "stun": 0, "guard_break": 0}

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
		if _is_cultist():
			dmg += _gear_bike_damage_bonus()
	if _is_heat_character():
		if player_heat >= 90:
			dmg += 5
		elif player_heat >= 50:
			dmg += 2
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

func _apply_enemy_card_status(card: CardData, target_idx: int, status: StringName, stacks: int) -> void:
	if card.is_aoe:
		for i: int in range(enemies.size()):
			if bool(enemies[i]["alive"]):
				_add_enemy_status(i, status, stacks)
	elif target_idx >= 0 and target_idx < enemies.size() and bool(enemies[target_idx]["alive"]):
		_add_enemy_status(target_idx, status, stacks)

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
	status["guard_break"] = maxi(0, int(status.get("guard_break", 0)) - 1)

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

func is_heat_card_transformed(card: CardData) -> bool:
	if not _is_heat_character():
		return false
	if player_heat < 50:
		return false
	if CardData.Tag.DEFENSE not in card.tags:
		return false
	if card.get_effective_block() <= 0:
		return false
	if player_heat >= 90:
		return true
	var best_card: CardData = null
	var best_block: int = -1
	for hand_card: CardData in DeckManager.hand:
		if CardData.Tag.DEFENSE not in hand_card.tags:
			continue
		var block_value: int = hand_card.get_effective_block()
		if block_value > best_block:
			best_block = block_value
			best_card = hand_card
	return card == best_card

# ===== オーラ（闘気）=====
func _add_aura(amount: int) -> void:
	player_aura = clampi(player_aura + amount, 0, AURA_MAX)
	aura_changed.emit(player_aura, AURA_MAX)

# ===== 速度（ギア）=====
func _gear_enabled() -> bool:
	return _is_cultist() and GameManager.get_faith_band() != &"apostate"

func _gear_cap() -> int:
	if GameManager.get_faith_band() == &"doubting":
		return 5
	return GEAR_MAX

func _is_full_throttle_active() -> bool:
	return int(player_buffs.get("ultimate", 0)) > 0

func _tick_gear_start_of_turn() -> void:
	if not _gear_enabled():
		player_gear = GEAR_MIN
		acceleration_changed.emit(player_gear, GEAR_MAX)
		return
	if _is_full_throttle_active():
		return
	_add_gear(1)

func _add_gear(amount: int) -> void:
	if amount == 0:
		return
	if not _gear_enabled():
		return
	var cap: int = _gear_cap()
	player_gear = clampi(player_gear + amount, GEAR_MIN, cap)
	acceleration_changed.emit(player_gear, GEAR_MAX)
	if player_gear >= GEAR_MAX:
		_activate_ultimate()

func _gear_bike_damage_bonus() -> int:
	if _is_full_throttle_active():
		return 0
	match player_gear:
		2:
			return 1
		3:
			return 2
		4:
			return 3
		5:
			return 4
	return 0

func can_engine_brake() -> bool:
	if state != CombatState.PLAYER_TURN:
		return false
	if not _gear_enabled():
		return false
	if _is_full_throttle_active():
		return false
	if _engine_brake_used_this_turn:
		return false
	return player_gear > GEAR_MIN

func engine_brake() -> bool:
	if not can_engine_brake():
		return false
	_engine_brake_used_this_turn = true
	player_gear = maxi(GEAR_MIN, player_gear - 1)
	player_block += 3
	acceleration_changed.emit(player_gear, GEAR_MAX)
	player_block_changed.emit(player_block)
	return true

func _activate_ultimate() -> void:
	player_buffs["ultimate"] = FULL_THROTTLE_TURNS
	player_gear = GEAR_MAX
	_free_bike_fuel_turns = 1
	acceleration_changed.emit(player_gear, GEAR_MAX)
	player_buffs_changed.emit(player_buffs)
	DeckManager.discard_hand()
	DeckManager.draw_cards(DeckManager.HAND_SIZE + 2)
	if not _regular_draw_done:
		_skip_regular_draw_this_turn = true
	ultimate_activated.emit()

# ===== 調査ゲージ =====
func _tick_investigation_start_of_turn() -> void:
	if not GameManager.has_human_companion():
		return
	_add_investigation(-1)
	if player_investigation <= 0:
		_clear_random_investigated_enemy()
		player_investigation = 3
		investigation_changed.emit(player_investigation, INVESTIGATION_MAX)

func _add_investigation(amount: int) -> void:
	player_investigation = clampi(player_investigation + amount, 0, INVESTIGATION_MAX)
	investigation_changed.emit(player_investigation, INVESTIGATION_MAX)

func _clear_random_investigated_enemy() -> void:
	var candidates: Array[int] = []
	for i: int in range(enemies.size()):
		var status: Dictionary = enemies[i]["status"]
		if int(status.get("investigation", 0)) > 0:
			candidates.append(i)
	if candidates.is_empty():
		return
	var idx: int = candidates[randi() % candidates.size()]
	var status: Dictionary = enemies[idx]["status"]
	status["investigation"] = 0
	enemy_status_changed.emit(idx, status)

func _has_missing_link_target() -> bool:
	for i: int in range(enemies.size()):
		if _is_missing_link_target(i):
			return true
	return false

func _is_missing_link_target(idx: int) -> bool:
	if idx < 0 or idx >= enemies.size():
		return false
	if not bool(enemies[idx]["alive"]):
		return false
	var total: int = 0
	for enemy: Dictionary in enemies:
		var status: Dictionary = enemy["status"]
		total += int(status.get("investigation", 0))
	var target_status: Dictionary = enemies[idx]["status"]
	return int(target_status.get("investigation", 0)) >= 3 or total >= 5

func _maybe_add_quickdraw_followup(card_id: StringName) -> void:
	if bool(_quickdraw_added_this_turn.get(card_id, false)):
		return
	_quickdraw_added_this_turn[card_id] = true
	DeckManager.add_temporary_card_to_hand(card_id)

func _has_exhaustable_hand_card(excluding_card_id: StringName) -> bool:
	for card: CardData in DeckManager.hand:
		if card.id != excluding_card_id:
			return true
	return false

func _apply_recycler(card: CardData, target_idx: int) -> void:
	if target_idx < 0 or target_idx >= enemies.size():
		return
	if not bool(enemies[target_idx]["alive"]):
		return
	var excluded: Array[StringName] = [card.id]
	var exhausted: CardData = DeckManager.exhaust_random_card_from_hand_excluding(excluded)
	if exhausted == null:
		return
	var exhaust_count: int = DeckManager.exhaust_pile.size()
	var recycle_damage: int = _apply_player_attack_mods(exhaust_count * 8, card.tags)
	if _climax_active:
		recycle_damage *= 2
	_damage_enemy(target_idx, recycle_damage, card.tags)

# ===== エクスタシー =====
func _add_euphoria(amount: int) -> void:
	if amount > 0 and player_euphoria >= 95 and player_euphoria < EUPHORIA_MAX:
		player_euphoria = EUPHORIA_MAX
		euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)
		if not _climax_active:
			_activate_climax()
		return
	player_euphoria = clampi(player_euphoria + amount, 0, EUPHORIA_MAX)
	euphoria_changed.emit(player_euphoria, EUPHORIA_MAX)
	if player_euphoria >= EUPHORIA_MAX and not _climax_active:
		_activate_climax()

func _tick_euphoria_start_of_turn() -> void:
	_add_euphoria(-8)
	var charm_gain: int = 0
	for enemy: Dictionary in enemies:
		if not bool(enemy.get("alive", false)):
			continue
		var status: Dictionary = enemy["status"]
		if int(status.get("charm", 0)) > 0:
			charm_gain += 3
	if charm_gain > 0:
		_add_euphoria(charm_gain)

func _activate_climax() -> void:
	_climax_active = true
	DeckManager.discard_hand()
	DeckManager.draw_cards(7)
	_maybe_add_love_slave_card()
	climax_activated.emit()

# ===== 獣システム =====
func _beast_auto_attack() -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		var atk: int = _get_effective_beast_attack(beast)
		var target_idx: int = _pick_beast_target(beast)
		if target_idx >= 0:
			_damage_enemy(target_idx, atk)
	beast_changed.emit()

func add_beast(beast_name: String, hp: int, atk: int, guard: int = 0) -> void:
	if _alive_beast_count() >= get_beast_max_slots():
		return
	player_beasts.append({
		"name": beast_name,
		"hp": hp,
		"max_hp": hp,
		"attack": atk,
		"guard": guard,
		"guard_bonus": 0,
		"temp_attack_bonus": 0,
		"alive": true,
		"source_card_id": &"",
		"random_target": false,
		"tank_share": 0,
		"turns_alive": 0,
	})
	beast_changed.emit()

func get_beast_max_slots() -> int:
	var slots: int = BEAST_BASE_MAX
	if ItemDatabase.has_relic(&"broken_collar"):
		slots += 1
	if ItemDatabase.has_relic(&"pack_proof"):
		slots += 1
	return mini(slots, BEAST_ABSOLUTE_MAX)

func _partner_attack_instruction() -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		var atk: int = _get_effective_beast_attack(beast) * 2
		beast["guard_bonus"] = -int(beast.get("guard", 0))
		var target_idx: int = _pick_beast_target(beast)
		if target_idx >= 0:
			_damage_enemy(target_idx, atk)
	beast_changed.emit()

func _heal_beasts(amount: int) -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		var max_hp: int = int(beast.get("max_hp", 0))
		beast["hp"] = mini(max_hp, int(beast.get("hp", 0)) + amount)
	beast_changed.emit()

func _heal_most_wounded_beast(amount: int) -> void:
	var target_idx: int = -1
	var worst_missing_hp: int = 0
	for i: int in range(player_beasts.size()):
		var beast: Dictionary = player_beasts[i]
		if not bool(beast.get("alive", false)):
			continue
		var max_hp: int = int(beast.get("max_hp", 0))
		var hp: int = int(beast.get("hp", 0))
		var missing_hp: int = max_hp - hp
		if missing_hp > worst_missing_hp:
			worst_missing_hp = missing_hp
			target_idx = i
	if target_idx < 0:
		return
	var target: Dictionary = player_beasts[target_idx]
	var target_max_hp: int = int(target.get("max_hp", 0))
	target["hp"] = mini(target_max_hp, int(target.get("hp", 0)) + amount)
	beast_changed.emit()

func _has_wounded_beast() -> bool:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		if int(beast.get("hp", 0)) < int(beast.get("max_hp", 0)):
			return true
	return false

func _buff_beasts_attack_this_turn(amount: int) -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		beast["temp_attack_bonus"] = int(beast.get("temp_attack_bonus", 0)) + amount
	beast_changed.emit()

func _summon_random_beast() -> void:
	var candidates: Array[StringName] = [&"bm_devilf", &"bm_grizzly", &"bm_eagle", &"bm_armadillo"]
	candidates.shuffle()
	for card_id: StringName in candidates:
		if _set_beast_from_card(card_id):
			return

func damage_beast(idx: int, amount: int) -> void:
	if idx < 0 or idx >= player_beasts.size():
		return
	var beast := player_beasts[idx]
	if not bool(beast.get("alive", false)):
		return
	beast["hp"] = maxi(0, int(beast.get("hp", 0)) - amount)
	if int(beast.get("hp", 0)) <= 0:
		beast["alive"] = false
		if beast.get("source_card_id", &"") == &"bm_tiger":
			_tiger_down_next_combat = true
	beast_changed.emit()

func recover_tiger_after_rest() -> void:
	_tiger_down_next_combat = false

func _redirect_damage_to_partners(amount: int) -> int:
	var alive_indices: Array[int] = []
	for i: int in range(player_beasts.size()):
		var beast: Dictionary = player_beasts[i]
		if bool(beast.get("alive", false)):
			alive_indices.append(i)
	if alive_indices.is_empty():
		return amount
	if int(player_buffs.get("partner_defense", 0)) > 0:
		var each_damage: int = int(ceil(float(amount) / float(alive_indices.size())))
		for idx: int in alive_indices:
			_damage_partner_with_guard(idx, each_damage)
		return 0
	for idx: int in alive_indices:
		var tank_beast: Dictionary = player_beasts[idx]
		var tank_share: int = int(tank_beast.get("tank_share", 0))
		if tank_share > 0:
			var tank_damage: int = int(ceil(float(amount) * float(tank_share) / 100.0))
			_damage_partner_with_guard(idx, tank_damage)
			return maxi(0, amount - tank_damage)
	var share_count: int = alive_indices.size() + 1
	var player_share: int = int(ceil(float(amount) / float(share_count)))
	var beast_share: int = int(floor(float(amount) / float(share_count)))
	for idx: int in alive_indices:
		_damage_partner_with_guard(idx, beast_share)
	return player_share

func _damage_partner_with_guard(idx: int, amount: int) -> void:
	if idx < 0 or idx >= player_beasts.size():
		return
	var beast: Dictionary = player_beasts[idx]
	var guard: int = maxi(0, int(beast.get("guard", 0)) + int(beast.get("guard_bonus", 0)))
	var final_damage: int = maxi(0, amount - guard)
	beast["hp"] = maxi(0, int(beast.get("hp", 0)) - final_damage)
	if int(beast.get("hp", 0)) <= 0:
		beast["alive"] = false
		if beast.get("source_card_id", &"") == &"bm_tiger":
			_tiger_down_next_combat = true
	beast_changed.emit()

func _add_tiger_at_combat_start() -> void:
	var tiger_hp: int = 10 if _tiger_down_next_combat else 20
	_tiger_down_next_combat = false
	_set_beast_from_stats(&"bm_tiger", "虎", tiger_hp, 20, 5, 2, false, 0)

func _set_beast_from_card(card_id: StringName) -> bool:
	var stats: Dictionary = _beast_stats_for_card(card_id)
	if stats.is_empty():
		return false
	var set_ok: bool = _set_beast_from_stats(
		card_id,
		String(stats.get("name", "獣")),
		int(stats.get("hp", 1)),
		int(stats.get("max_hp", stats.get("hp", 1))),
		int(stats.get("attack", 0)),
		int(stats.get("guard", 0)),
		bool(stats.get("random_target", false)),
		int(stats.get("tank_share", 0))
	)
	if set_ok and bool(stats.get("quick_attack", false)):
		_beast_source_attack_once(card_id)
	return set_ok

func _set_beast_from_stats(card_id: StringName, beast_name: String, hp: int, max_hp: int, atk: int, guard: int, random_target: bool, tank_share: int) -> bool:
	_remove_dead_beast_source(card_id)
	if _has_beast_source(card_id):
		return false
	if _alive_beast_count() >= get_beast_max_slots():
		return false
	player_beasts.append({
		"name": beast_name,
		"hp": hp,
		"max_hp": max_hp,
		"attack": atk,
		"guard": guard,
		"guard_bonus": 0,
		"temp_attack_bonus": 0,
		"alive": true,
		"source_card_id": card_id,
		"random_target": random_target,
		"tank_share": tank_share,
		"turns_alive": 0,
	})
	beast_changed.emit()
	return true

func _is_beast_card_id(card_id: StringName) -> bool:
	return card_id in _animal_card_ids()

func _animal_card_ids() -> Array[StringName]:
	return [&"bm_tiger", &"bm_devilf", &"bm_grizzly", &"bm_eagle", &"bm_armadillo"]

func _beast_stats_for_card(card_id: StringName) -> Dictionary:
	match card_id:
		&"bm_tiger":
			return {"name": "虎", "hp": 20, "max_hp": 20, "attack": 5, "guard": 2}
		&"bm_devilf":
			return {"name": "デビルフ", "hp": 8, "max_hp": 8, "attack": 8, "guard": 0, "quick_attack": true}
		&"bm_grizzly":
			return {"name": "変異グリズリー", "hp": 30, "max_hp": 30, "attack": 4, "guard": 5}
		&"bm_eagle":
			return {"name": "汚染イーグル", "hp": 6, "max_hp": 6, "attack": 3, "guard": 0, "random_target": true}
		&"bm_armadillo":
			return {"name": "アーマージロ", "hp": 25, "max_hp": 25, "attack": 0, "guard": 8, "tank_share": 75}
	return {}

func _can_set_beast_from_card(card_id: StringName) -> bool:
	if not _is_beast_card_id(card_id):
		return false
	_remove_dead_beast_source(card_id)
	if _has_beast_source(card_id):
		return false
	return _alive_beast_count() < get_beast_max_slots()

func _alive_beast_count() -> int:
	var count: int = 0
	for beast: Dictionary in player_beasts:
		if bool(beast.get("alive", false)):
			count += 1
	return count

func _has_beast_source(card_id: StringName) -> bool:
	for beast: Dictionary in player_beasts:
		if bool(beast.get("alive", false)) and beast.get("source_card_id", &"") == card_id:
			return true
	return false

func _remove_dead_beast_source(card_id: StringName) -> void:
	for i: int in range(player_beasts.size() - 1, -1, -1):
		var beast: Dictionary = player_beasts[i]
		if not bool(beast.get("alive", false)) and beast.get("source_card_id", &"") == card_id:
			player_beasts.remove_at(i)

func _get_effective_beast_attack(beast: Dictionary) -> int:
	return maxi(0, int(beast.get("attack", 0)) + int(beast.get("temp_attack_bonus", 0)))

func _get_total_beast_attack() -> int:
	var total: int = 0
	for beast: Dictionary in player_beasts:
		if bool(beast.get("alive", false)):
			total += _get_effective_beast_attack(beast)
	return total

func _beasts_attack_once() -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		var target_idx: int = _pick_beast_target(beast)
		if target_idx >= 0:
			_damage_enemy(target_idx, _get_effective_beast_attack(beast))
	beast_changed.emit()

func _beast_source_attack_once(card_id: StringName) -> void:
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		if beast.get("source_card_id", &"") != card_id:
			continue
		var target_idx: int = _pick_beast_target(beast)
		if target_idx >= 0:
			_damage_enemy(target_idx, _get_effective_beast_attack(beast))
		return

func _requires_alive_beast(card_id: StringName) -> bool:
	return (
		card_id == &"bm02"
		or card_id == &"bm03"
		or card_id == &"bm04"
		or card_id == &"bm07"
		or card_id == &"bm10"
		or card_id == &"bm11"
	)

func _pick_beast_target(beast: Dictionary) -> int:
	var alive_indices: Array[int] = []
	for i: int in range(enemies.size()):
		if bool(enemies[i]["alive"]):
			alive_indices.append(i)
	if alive_indices.is_empty():
		return -1
	if bool(beast.get("random_target", false)):
		return alive_indices[randi() % alive_indices.size()]
	return alive_indices[0]

func _add_beast_guard_bonus(amount: int) -> void:
	for beast: Dictionary in player_beasts:
		if bool(beast.get("alive", false)):
			beast["guard_bonus"] = int(beast.get("guard_bonus", 0)) + amount
	beast_changed.emit()

func _has_animal_card_to_whistle() -> bool:
	var animal_ids: Array[StringName] = _animal_card_ids()
	for card: CardData in DeckManager.discard_pile:
		if card.id in animal_ids:
			return true
	for card: CardData in DeckManager.draw_pile:
		if card.id in animal_ids:
			return true
	return false

func _whistle_animal_card() -> void:
	var animal_ids: Array[StringName] = _animal_card_ids()
	if DeckManager.move_random_card_id_from_discard_to_hand(animal_ids):
		return
	DeckManager.move_random_card_id_from_draw_to_hand(animal_ids)

func _grant_beast_card_from_enemy(enemy_data: EnemyData) -> void:
	var card_id: StringName = &"bm_devilf"
	match enemy_data.category:
		EnemyData.Category.BEAST:
			var enemy_id: String = String(enemy_data.id)
			if enemy_id.contains("grizzly"):
				card_id = &"bm_grizzly"
			elif enemy_id.contains("eagle"):
				card_id = &"bm_eagle"
			elif enemy_id.contains("armadillo"):
				card_id = &"bm_armadillo"
			else:
				card_id = &"bm_devilf"
		_:
			return
	var _added: bool = DeckManager.add_card_id_to_discard(card_id)

func _can_use_herd_roar() -> bool:
	if not _has_mature_beast():
		return false
	for card: CardData in DeckManager.hand:
		if card.id in _animal_card_ids():
			return true
	for card: CardData in DeckManager.draw_pile:
		if card.id in _animal_card_ids():
			return true
	for card: CardData in DeckManager.discard_pile:
		if card.id in _animal_card_ids():
			return true
	return false

func _activate_herd_roar() -> void:
	var animal_ids: Array[StringName] = _animal_card_ids()
	var _moved: Array[CardData] = DeckManager.move_all_card_ids_from_draw_and_discard_to_hand(animal_ids)
	var attack_bonus: int = 0
	var guard_bonus: int = 0
	for card: CardData in DeckManager.hand:
		var stats: Dictionary = _beast_stats_for_card(card.id)
		if stats.is_empty():
			continue
		attack_bonus += int(stats.get("attack", 0))
		guard_bonus += int(stats.get("guard", 0))
	if guard_bonus > 0:
		player_block += guard_bonus
		player_block_changed.emit(player_block)
	for beast: Dictionary in player_beasts:
		if not bool(beast.get("alive", false)):
			continue
		beast["temp_attack_bonus"] = int(beast.get("temp_attack_bonus", 0)) + attack_bonus
		var target_idx: int = _pick_beast_target(beast)
		if target_idx >= 0:
			_damage_enemy(target_idx, _get_effective_beast_attack(beast))
	player_buffs["herd_fatigue"] = 1
	player_buffs_changed.emit(player_buffs)
	beast_changed.emit()

func _has_mature_beast() -> bool:
	for beast: Dictionary in player_beasts:
		if bool(beast.get("alive", false)) and int(beast.get("turns_alive", 0)) >= 3:
			return true
	return false

func _advance_beast_survival_turns() -> void:
	if not _is_beast_master():
		return
	for beast: Dictionary in player_beasts:
		if bool(beast.get("alive", false)):
			beast["turns_alive"] = int(beast.get("turns_alive", 0)) + 1
	beast_changed.emit()

func _apply_herd_fatigue_start_of_turn() -> void:
	if int(player_buffs.get("herd_fatigue", 0)) <= 0:
		return
	player_buffs["herd_fatigue"] = 0
	player_beasts.clear()
	player_buffs_changed.emit(player_buffs)
	beast_changed.emit()

func _tick_player_buffs() -> void:
	var changed := false
	var ultimate_before: int = int(player_buffs.get("ultimate", 0))
	for key: String in ["melee_power", "overcharge", "ultimate"]:
		var val: int = int(player_buffs.get(key, 0))
		if val > 0:
			player_buffs[key] = val - 1
			changed = true
	if _free_bike_fuel_turns > 0:
		_free_bike_fuel_turns -= 1
	if ultimate_before > 0 and int(player_buffs.get("ultimate", 0)) <= 0:
		player_gear = GEAR_MIN
		acceleration_changed.emit(player_gear, GEAR_MAX)
	if changed:
		player_buffs_changed.emit(player_buffs)

func _clear_partner_turn_state() -> void:
	var buffs_changed := false
	var beasts_changed := false
	if int(player_buffs.get("partner_defense", 0)) > 0:
		player_buffs["partner_defense"] = 0
		buffs_changed = true
	if int(player_buffs.get("companion_guard", 0)) > 0:
		player_buffs["companion_guard"] = 0
		buffs_changed = true
	for beast: Dictionary in player_beasts:
		if int(beast.get("guard_bonus", 0)) != 0:
			beast["guard_bonus"] = 0
			beasts_changed = true
		if int(beast.get("temp_attack_bonus", 0)) != 0:
			beast["temp_attack_bonus"] = 0
			beasts_changed = true
	if buffs_changed:
		player_buffs_changed.emit(player_buffs)
	if beasts_changed:
		beast_changed.emit()

# ===== キャラ判定ヘルパー =====
func _is_cultist() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"gear"

func _is_wanderer() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"investigation"

func _is_conqueror() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"aura"

func _is_beast_master() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"partner"

func _is_heat_character() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"heat"

func _is_hedonist() -> bool:
	if GameManager.current_character == null:
		return false
	return GameManager.current_character.unique_system == &"euphoria"

func _is_lone_wolf() -> bool:
	if not _is_wanderer():
		return false
	return not GameManager.has_human_companion()

func _has_companion(comp_type: CompanionData.CompanionType) -> bool:
	return GameManager.has_companion_type(comp_type)

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
