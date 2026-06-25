extends RefCounted

# --script モードではAutoloadグローバルが解決されないため、
# 呼び出し側から参照を注入する。
var CombatManager
var DeckManager

var log_entries: Array[Dictionary] = []
var _rng: RandomNumberGenerator

func _init(combat_mgr, deck_mgr, rng: RandomNumberGenerator = null) -> void:
	CombatManager = combat_mgr
	DeckManager = deck_mgr
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()

func fight(enemy_list: Array[EnemyData], boss_hp_scale: float = 1.0) -> Dictionary:
	log_entries.clear()
	CombatManager.start_combat(enemy_list, boss_hp_scale)

	var max_turns := 100
	while CombatManager.state == CombatManager.CombatState.PLAYER_TURN and max_turns > 0:
		max_turns -= 1
		_play_turn()
		if CombatManager.state == CombatManager.CombatState.PLAYER_TURN:
			CombatManager.end_player_turn()

	var result: Dictionary = {
		"won": CombatManager.state == CombatManager.CombatState.VICTORY,
		"turns": CombatManager.turn_number,
		"player_hp": CombatManager.player_hp,
		"player_max_hp": CombatManager.player_max_hp,
		"log": log_entries.duplicate(true),
	}
	return result

func _play_turn() -> void:
	var played_count: int = 0

	# バフフェーズ: 手札にバフカードと対応する攻撃カードがあればバフを先に使う
	var buff_cards := _get_buff_cards()
	for buff_card: CardData in buff_cards:
		if not CombatManager.can_play_card(buff_card):
			continue
		if _has_matching_attack(buff_card):
			CombatManager.play_card(buff_card, _pick_target(buff_card))
			_log_play(buff_card, -1)
			played_count += 1

	# 攻撃/防御フェーズ
	var safety_limit := 30
	while safety_limit > 0:
		safety_limit -= 1
		var card := _pick_best_card()
		if card == null:
			break
		var target := _pick_target(card)
		CombatManager.play_card(card, target)
		_log_play(card, target)
		played_count += 1

	_log_turn_summary(played_count)

func _pick_best_card() -> CardData:
	var playable: Array[CardData] = []
	for card: CardData in DeckManager.hand:
		if CombatManager.can_play_card(card):
			playable.append(card)
	if playable.is_empty():
		return null

	# 全敵が次ターンに与えるダメージ合計を見積もる
	var incoming_damage := _estimate_incoming_damage()
	var effective_hp: int = CombatManager.player_hp + CombatManager.player_block

	# HPが危険水準ならブロックカードを優先
	if incoming_damage > 0 and float(effective_hp) / float(CombatManager.player_max_hp) < 0.4:
		var best_block: CardData = null
		var best_block_val: int = 0
		for card: CardData in playable:
			var blk := card.get_effective_block()
			if blk > best_block_val:
				best_block = card
				best_block_val = blk
		if best_block != null:
			return best_block

	# 倒せる敵がいるならそのカードを優先
	var best_kill: CardData = null
	var best_kill_target: int = -1
	for card: CardData in playable:
		if card.get_effective_damage() <= 0 and not card.is_aoe:
			continue
		for i in CombatManager.enemies.size():
			if not CombatManager.enemies[i]["alive"]:
				continue
			var dmg: int = CombatManager.preview_damage(card, i)
			var ehp: int = CombatManager.enemies[i]["hp"] + int(CombatManager.enemies[i]["block"])
			if dmg >= ehp:
				if best_kill == null or ehp < (CombatManager.enemies[best_kill_target]["hp"] + int(CombatManager.enemies[best_kill_target]["block"])):
					best_kill = card
					best_kill_target = i
	if best_kill != null:
		return best_kill

	# 最大ダメージを出せるカード
	var best_dmg_card: CardData = null
	var best_dmg_val: int = 0
	for card: CardData in playable:
		var max_dmg: int = 0
		for i in CombatManager.enemies.size():
			if CombatManager.enemies[i]["alive"]:
				var d: int = CombatManager.preview_damage(card, i)
				if d > max_dmg:
					max_dmg = d
		if max_dmg > best_dmg_val:
			best_dmg_card = card
			best_dmg_val = max_dmg
	if best_dmg_card != null:
		return best_dmg_card

	# ブロックカード
	for card: CardData in playable:
		if card.get_effective_block() > 0:
			return card

	# ドローカード
	for card: CardData in playable:
		if card.draw_count > 0:
			return card

	# AP補充カード
	for card: CardData in playable:
		if card.bonus_ap > 0:
			return card

	# 残りの何でも
	return playable[0]

func _pick_target(card: CardData) -> int:
	if card.is_aoe:
		return 0
	if card.get_effective_damage() <= 0 and not card.requires_target:
		return -1

	# 倒せる敵を優先
	var killable_idx: int = -1
	var killable_hp: int = 999999
	for i in CombatManager.enemies.size():
		if not CombatManager.enemies[i]["alive"]:
			continue
		var dmg: int = CombatManager.preview_damage(card, i)
		var ehp: int = CombatManager.enemies[i]["hp"] + int(CombatManager.enemies[i]["block"])
		if dmg >= ehp and ehp < killable_hp:
			killable_idx = i
			killable_hp = ehp
	if killable_idx >= 0:
		return killable_idx

	# preview_damageが最大の敵
	var best_idx: int = 0
	var best_dmg: int = 0
	for i in CombatManager.enemies.size():
		if not CombatManager.enemies[i]["alive"]:
			continue
		var d: int = CombatManager.preview_damage(card, i)
		if d > best_dmg:
			best_dmg = d
			best_idx = i
	return best_idx

func _get_buff_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in DeckManager.hand:
		if not CombatManager.can_play_card(card):
			continue
		if card.get_effective_damage() <= 0 and card.get_effective_block() <= 0:
			if _is_buff_card(card):
				result.append(card)
	return result

func _is_buff_card(card: CardData) -> bool:
	if card.status_effect == &"heat" or card.status_effect == &"aura" or card.status_effect == &"euphoria":
		return true
	if card.bonus_ap > 0 and card.get_effective_damage() <= 0:
		return true
	if card.ap_cost_reduction > 0:
		return true
	if card.id == &"er02" or card.id == &"er09" or card.id == &"co02" or card.id == &"co04":
		return true
	return false

func _has_matching_attack(buff_card: CardData) -> bool:
	for card: CardData in DeckManager.hand:
		if card == buff_card:
			continue
		if card.get_effective_damage() > 0 and CombatManager.can_play_card(card):
			if CardData.Tag.MELEE in buff_card.tags:
				if CardData.Tag.MELEE in card.tags:
					return true
			elif CardData.Tag.RANGED in buff_card.tags:
				if CardData.Tag.RANGED in card.tags:
					return true
			else:
				return true
	return false

func _estimate_incoming_damage() -> int:
	var total: int = 0
	for enemy: Dictionary in CombatManager.enemies:
		if not enemy["alive"]:
			continue
		var intent: Dictionary = enemy["intent"]
		var intent_type: String = intent.get("type", "")
		match intent_type:
			"attack":
				var dmg: int = int(intent.get("value", 0))
				var hits: int = int(intent.get("hits", 1))
				total += dmg * hits
			"attack_defend":
				total += int(intent.get("attack", 0))
	return total

func _log_play(card: CardData, target: int) -> void:
	log_entries.append({
		"turn": CombatManager.turn_number,
		"action": "play",
		"card_id": card.id,
		"card_name": card.display_name,
		"target": target,
		"ap_after": CombatManager.ap,
	})

func _log_turn_summary(cards_played: int) -> void:
	var alive_enemies: int = 0
	var total_enemy_hp: int = 0
	for enemy: Dictionary in CombatManager.enemies:
		if enemy["alive"]:
			alive_enemies += 1
			total_enemy_hp += int(enemy["hp"])
	log_entries.append({
		"turn": CombatManager.turn_number,
		"action": "turn_end",
		"cards_played": cards_played,
		"player_hp": CombatManager.player_hp,
		"player_block": CombatManager.player_block,
		"alive_enemies": alive_enemies,
		"total_enemy_hp": total_enemy_hp,
	})
