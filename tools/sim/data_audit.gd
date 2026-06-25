extends RefCounted

# --script モードではAutoloadグローバルが解決されないため、
# 呼び出し側から参照を注入する。
var CardDatabase
var EnemyDatabase
var GameManager

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

func _init(card_db, enemy_db, game_mgr) -> void:
	CardDatabase = card_db
	EnemyDatabase = enemy_db
	GameManager = game_mgr

func run_all() -> void:
	errors.clear()
	warnings.clear()
	_audit_starter_decks()
	_audit_card_status_effects()
	_audit_upgrade_noop()
	_audit_enemy_coverage()

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
	]
	var known_enemy: Array[StringName] = [
		&"weaken", &"weak", &"vulnerable", &"vuln",
		&"burn", &"bleed", &"strength", &"atk_down", &"charm",
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
		"res://resources/cards/contamination",
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
