extends RefCounted

# --script モードではAutoloadグローバルが解決されないため、
# 呼び出し側から参照を注入する。
var CardDatabase
var EnemyDatabase
var GameManager
var ItemDatabase

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

func _init(card_db, enemy_db, game_mgr, item_db = null) -> void:
	CardDatabase = card_db
	EnemyDatabase = enemy_db
	GameManager = game_mgr
	ItemDatabase = item_db

func run_all() -> void:
	errors.clear()
	warnings.clear()
	_audit_starter_decks()
	_audit_card_status_effects()
	_audit_upgrade_noop()
	_audit_enemy_coverage()
	_audit_quest_references()
	_audit_event_references()

func _audit_starter_decks() -> void:
	var characters := _load_all_characters()
	for ch: CharacterData in characters:
		for card_id: StringName in ch.starter_deck_ids:
			var card: CardData = CardDatabase.get_card(card_id)
			if card == null:
				_error("starter_deck", ch.id,
					"初期デッキのカードID '%s' がCardDatabaseに存在しない" % card_id)

func _audit_card_status_effects() -> void:
	var known_player: Array[StringName] = [
		&"heat", &"aura", &"euphoria", &"strength",
		&"overcharge", &"melee_power", &"ranged_double",
	]
	var known_enemy: Array[StringName] = [
		&"weaken", &"weak", &"vulnerable", &"vuln",
		&"burn", &"bleed", &"strength", &"atk_down", &"charm",
		&"investigate",
	]
	var all_known: Array[StringName] = []
	all_known.append_array(known_player)
	all_known.append_array(known_enemy)
	for card: CardData in _all_cards():
		if card.status_effect == &"":
			continue
		if card.status_effect not in all_known:
			_error("status_effect", card.id,
				"status_effect '%s' は CombatManager の対応済み効果に含まれない" % card.status_effect)

func _audit_upgrade_noop() -> void:
	for card: CardData in _all_cards():
		if card.is_starter or card.is_unplayable:
			continue
		var has_upgrade := false
		if card.upgraded_damage > 0 and card.upgraded_damage != card.base_damage:
			has_upgrade = true
		if card.upgraded_block > 0 and card.upgraded_block != card.base_block:
			has_upgrade = true
		if not card.upgrade_description.is_empty():
			has_upgrade = true
		if not has_upgrade and card.base_damage > 0:
			_warning("upgrade_noop", card.id,
				"ダメージカードだが強化値が未設定（upgraded_damage=%d, base_damage=%d）" % [card.upgraded_damage, card.base_damage])

func _audit_enemy_coverage() -> void:
	var max_act: int = GameManager.MAX_ACT
	for act in range(1, max_act + 1):
		var normals: Array[EnemyData] = EnemyDatabase.get_enemies_for_act(act)
		if normals.is_empty():
			_error("enemy_coverage", "act%d" % act,
				"Act%d に通常敵が存在しない" % act)
		var boss: EnemyData = EnemyDatabase.get_boss_for_act(act)
		if boss == null:
			_error("enemy_coverage", "act%d" % act,
				"Act%d にボスが存在しない" % act)

func _audit_quest_references() -> void:
	var events: Array[EventData] = _load_all_events()
	var event_ids: Dictionary = {}
	for event: EventData in events:
		event_ids[event.id] = true
	for quest: QuestData in _load_all_quests():
		if quest.payload_event != &"" and not event_ids.has(quest.payload_event):
			_error("quest_reference", quest.id,
				"payload_event '%s' がEventDatabaseに存在しない" % quest.payload_event)
		if quest.boss_target != &"" and EnemyDatabase.get_enemy(quest.boss_target) == null:
			_error("quest_reference", quest.id,
				"boss_target '%s' がEnemyDatabaseに存在しない" % quest.boss_target)
		if quest.boss_add_enemy != &"" and EnemyDatabase.get_enemy(quest.boss_add_enemy) == null:
			_error("quest_reference", quest.id,
				"boss_add_enemy '%s' がEnemyDatabaseに存在しない" % quest.boss_add_enemy)
		if quest.objective_match != &"" and quest.objective_count > 0 and not _has_matching_enemy(quest):
			_error("quest_reference", quest.id,
				"objective_match '%s' に一致する非ボス敵が required_act 以降に存在しない" % quest.objective_match)
		if quest.boss_mods.is_empty():
			continue
		var has_adds: bool = false
		for key: Variant in quest.boss_mods.keys():
			var mod: Dictionary = quest.boss_mods[key]
			if int(mod.get("adds", 0)) > 0:
				has_adds = true
		if has_adds and quest.boss_add_enemy == &"":
			_warning("quest_reference", quest.id,
				"boss_mods に adds があるが boss_add_enemy が空")

func _audit_event_references() -> void:
	var quest_ids: Dictionary = {}
	for quest: QuestData in _load_all_quests():
		quest_ids[quest.id] = true
	var companion_ids: Dictionary = _load_companion_ids()
	var item_ids: Dictionary = _load_item_ids()
	for event: EventData in _load_all_events():
		for choice: EventChoiceData in event.choices:
			if choice.starts_quest != &"" and not quest_ids.has(choice.starts_quest):
				_error("event_reference", event.id,
					"選択肢 '%s' の starts_quest '%s' が存在しない" % [choice.label, choice.starts_quest])
			if choice.quest_outcome != &"" and choice.starts_quest == &"":
				_warning("event_reference", event.id,
					"選択肢 '%s' は quest_outcome を持つが starts_quest が空" % choice.label)
			for enemy_id: StringName in choice.combat_enemy_ids:
				if EnemyDatabase.get_enemy(enemy_id) == null:
					_error("event_reference", event.id,
						"選択肢 '%s' の combat_enemy_ids '%s' が存在しない" % [choice.label, enemy_id])
			for card_id: StringName in choice.deck_card_ids:
				if CardDatabase.get_card(card_id) == null:
					_error("event_reference", event.id,
						"選択肢 '%s' の deck_card_ids '%s' が存在しない" % [choice.label, card_id])
			if choice.companion_id != &"" and not companion_ids.has(choice.companion_id):
				_error("event_reference", event.id,
					"選択肢 '%s' の companion_id '%s' が存在しない" % [choice.label, choice.companion_id])
			if choice.item_reward_id != &"" and not item_ids.has(choice.item_reward_id):
				_error("event_reference", event.id,
					"選択肢 '%s' の item_reward_id '%s' が存在しない" % [choice.label, choice.item_reward_id])

func get_report_text() -> String:
	var lines: Array[String] = ["=== データ監査結果 ==="]
	lines.append("エラー: %d 件 / 警告: %d 件" % [errors.size(), warnings.size()])
	for e: Dictionary in errors:
		lines.append("[ERROR] [%s] %s: %s" % [e["category"], e["source"], e["message"]])
	for w: Dictionary in warnings:
		lines.append("[WARN]  [%s] %s: %s" % [w["category"], w["source"], w["message"]])
	return "\n".join(lines)

func _error(category: String, source: StringName, message: String) -> void:
	errors.append({"category": category, "source": source, "message": message})

func _warning(category: String, source: StringName, message: String) -> void:
	warnings.append({"category": category, "source": source, "message": message})

func _load_all_characters() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	var dir := DirAccess.open("res://resources/characters")
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var ch: CharacterData = load("res://resources/characters/" + fname)
			if ch != null:
				result.append(ch)
		fname = dir.get_next()
	return result

func _all_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var dirs: Array[String] = [
		"res://resources/cards/starter", "res://resources/cards/shared",
		"res://resources/cards/cultist", "res://resources/cards/ex_raider",
		"res://resources/cards/wanderer", "res://resources/cards/beast_master",
		"res://resources/cards/conqueror", "res://resources/cards/hedonist",
		"res://resources/cards/companions", "res://resources/cards/contamination",
	]
	for path: String in dirs:
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var card: CardData = load(path.path_join(fname))
				if card != null:
					result.append(card)
			fname = dir.get_next()
	return result

func _load_all_events() -> Array[EventData]:
	var result: Array[EventData] = []
	var dirs: Array[String] = [
		"res://resources/events/settlement",
		"res://resources/events/faction",
		"res://resources/events/character",
		"res://resources/events/travel",
	]
	for path: String in dirs:
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var event: EventData = load(path.path_join(fname))
				if event != null:
					result.append(event)
			fname = dir.get_next()
	return result

func _load_all_quests() -> Array[QuestData]:
	var result: Array[QuestData] = []
	var dir := DirAccess.open("res://resources/quests")
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var quest: QuestData = load("res://resources/quests/".path_join(fname))
			if quest != null:
				result.append(quest)
		fname = dir.get_next()
	return result

func _load_companion_ids() -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open("res://resources/companions")
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var companion: CompanionData = load("res://resources/companions/".path_join(fname))
			if companion != null:
				result[companion.id] = true
		fname = dir.get_next()
	return result

func _load_item_ids() -> Dictionary:
	var result: Dictionary = {}
	if ItemDatabase != null:
		var loaded_items: Array[ItemData] = ItemDatabase.get_all_items()
		for item: ItemData in loaded_items:
			result[item.id] = true
		if not result.is_empty():
			return result
	var dirs: Array[String] = ["res://resources/items/consumable", "res://resources/items/relic"]
	for path: String in dirs:
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var item: ItemData = load(path.path_join(fname))
				if item != null:
					result[item.id] = true
			fname = dir.get_next()
	return result

func _has_matching_enemy(quest: QuestData) -> bool:
	var start_act: int = maxi(1, quest.required_act)
	var max_act: int = GameManager.MAX_ACT
	for act in range(start_act, max_act + 1):
		var normals: Array[EnemyData] = EnemyDatabase.get_enemies_for_act(act)
		for enemy: EnemyData in normals:
			if String(enemy.id).contains(String(quest.objective_match)):
				return true
		var elites: Array[EnemyData] = EnemyDatabase.get_elites_for_act(act)
		for enemy: EnemyData in elites:
			if String(enemy.id).contains(String(quest.objective_match)):
				return true
	return false
