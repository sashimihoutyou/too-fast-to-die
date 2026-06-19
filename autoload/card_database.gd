extends Node

var _cards: Dictionary = {}

func _ready() -> void:
	_register_starter_cards()
	_register_shared_cards()
	_register_cultist_cards()
	_register_contamination_cards()

func get_card(id: StringName) -> CardData:
	return _cards.get(id, null)

func get_reward_pool(act: int, character_id: StringName) -> Array[CardData]:
	var pool: Array[CardData] = []
	for card: CardData in _cards.values():
		if card.is_starter or card.is_unplayable:
			continue
		if card.restriction != CardData.CharacterRestriction.NONE:
			var char_restriction := _character_id_to_restriction(character_id)
			if card.restriction != char_restriction:
				continue
		var char_restriction := _character_id_to_restriction(character_id)
		if char_restriction in card.excluded_characters:
			continue
		pool.append(card)
	return pool

func _character_id_to_restriction(id: StringName) -> CardData.CharacterRestriction:
	match id:
		&"cultist": return CardData.CharacterRestriction.CULTIST
		&"ex_raider": return CardData.CharacterRestriction.EX_RAIDER
		&"wanderer": return CardData.CharacterRestriction.WANDERER
		&"beast_master": return CardData.CharacterRestriction.BEAST_MASTER
		&"conqueror": return CardData.CharacterRestriction.CONQUEROR
	return CardData.CharacterRestriction.NONE

func _make_card(data: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = data.get("id", &"")
	card.display_name = data.get("name", "")
	card.description = data.get("desc", "")
	card.ap_cost = data.get("ap", 1)
	card.fuel_cost = data.get("fuel", 0)
	card.halves_ap_this_turn = data.get("halve_ap", false)
	card.tags.assign(data.get("tags", []))
	card.rarity = data.get("rarity", CardData.Rarity.COMMON)
	card.restriction = data.get("restriction", CardData.CharacterRestriction.NONE)
	card.excluded_characters.assign(data.get("excluded", []))
	card.is_starter = data.get("starter", false)
	card.is_exhaustible = data.get("exhaust", false)
	card.is_unplayable = data.get("unplayable", false)
	card.base_damage = data.get("damage", 0)
	card.base_block = data.get("block", 0)
	card.hit_count = data.get("hits", 1)
	card.is_aoe = data.get("aoe", false)
	card.self_damage = data.get("self_damage", 0)
	card.draw_count = data.get("draw", 0)
	card.bonus_ap = data.get("bonus_ap", 0)
	card.upgraded_damage = data.get("up_damage", 0)
	card.upgraded_block = data.get("up_block", 0)
	_cards[card.id] = card
	return card

func _register_starter_cards() -> void:
	_make_card({"id": &"defend", "name": "ディフェンド", "desc": "5ブロック", "ap": 1, "tags": [CardData.Tag.DEFENSE], "block": 5, "up_block": 8, "starter": true})

func _register_shared_cards() -> void:
	_make_card({"id": &"m01", "name": "ナイフスラッシュ", "desc": "6ダメージ", "ap": 2, "tags": [CardData.Tag.MELEE], "damage": 6, "up_damage": 9})
	_make_card({"id": &"m02", "name": "ヘビーブロー", "desc": "12ダメージ", "ap": 3, "tags": [CardData.Tag.MELEE], "damage": 12, "up_damage": 18})
	_make_card({"id": &"m03", "name": "チェーン切り", "desc": "4ダメージ×2", "ap": 2, "tags": [CardData.Tag.MELEE], "rarity": CardData.Rarity.UNCOMMON, "damage": 4, "hits": 2, "up_damage": 6})
	_make_card({"id": &"m07", "name": "カウンターナイフ", "desc": "4ブロック+4ダメージ", "ap": 2, "tags": [CardData.Tag.MELEE], "rarity": CardData.Rarity.UNCOMMON, "damage": 4, "block": 4, "up_damage": 6, "up_block": 6})
	_make_card({"id": &"r01", "name": "ピストルショット", "desc": "6ダメージ", "ap": 2, "tags": [CardData.Tag.RANGED], "damage": 6, "up_damage": 9, "excluded": [CardData.CharacterRestriction.CONQUEROR]})
	_make_card({"id": &"r02", "name": "ショットガンブラスト", "desc": "全体4ダメージ", "ap": 3, "tags": [CardData.Tag.RANGED], "damage": 4, "aoe": true, "up_damage": 6, "excluded": [CardData.CharacterRestriction.CONQUEROR]})
	_make_card({"id": &"r03", "name": "ヘッドショット", "desc": "14ダメージ", "ap": 3, "tags": [CardData.Tag.RANGED], "rarity": CardData.Rarity.UNCOMMON, "damage": 14, "up_damage": 21, "excluded": [CardData.CharacterRestriction.CONQUEROR]})
	_make_card({"id": &"r08", "name": "威嚇射撃", "desc": "3ダメージ+萎縮2", "ap": 1, "tags": [CardData.Tag.RANGED], "damage": 3, "up_damage": 5, "excluded": [CardData.CharacterRestriction.CONQUEROR]})
	_make_card({"id": &"b01", "name": "ラム", "desc": "10ダメージ", "ap": 2, "fuel": 1, "tags": [CardData.Tag.BIKE], "damage": 10, "up_damage": 15, "excluded": [CardData.CharacterRestriction.CONQUEROR]})
	_make_card({"id": &"b02", "name": "サイドスワイプ", "desc": "6ダメージ+遅延", "ap": 2, "fuel": 1, "tags": [CardData.Tag.BIKE], "damage": 6, "up_damage": 9, "excluded": [CardData.CharacterRestriction.CONQUEROR]})
	_make_card({"id": &"d01", "name": "ガード", "desc": "5ブロック", "ap": 2, "tags": [CardData.Tag.DEFENSE], "block": 5, "up_block": 8})
	_make_card({"id": &"d02", "name": "ブレース", "desc": "12ブロック", "ap": 3, "tags": [CardData.Tag.DEFENSE], "block": 12, "up_block": 18})
	_make_card({"id": &"d03", "name": "回避ロール", "desc": "4ブロック+1ドロー", "ap": 2, "tags": [CardData.Tag.DEFENSE], "rarity": CardData.Rarity.UNCOMMON, "block": 4, "draw": 1, "up_block": 7})
	_make_card({"id": &"d08", "name": "応急処置", "desc": "HP6回復", "ap": 2, "tags": [CardData.Tag.DEFENSE], "rarity": CardData.Rarity.UNCOMMON})
	_make_card({"id": &"s01", "name": "アドレナリン", "desc": "2枚ドロー", "ap": 2, "tags": [CardData.Tag.SKILL], "rarity": CardData.Rarity.UNCOMMON, "draw": 2})
	_make_card({"id": &"s02", "name": "威圧", "desc": "萎縮2付与", "ap": 1, "tags": [CardData.Tag.SKILL], "damage": 0})

func _register_cultist_cards() -> void:
	_make_card({"id": &"st_at01", "name": "部族の槍", "desc": "6ダメージ", "ap": 1, "tags": [CardData.Tag.MELEE], "damage": 6, "up_damage": 9, "starter": true, "restriction": CardData.CharacterRestriction.CULTIST})
	_make_card({"id": &"st_at02", "name": "ボルトアクションライフル", "desc": "7ダメージ", "ap": 1, "tags": [CardData.Tag.RANGED], "damage": 7, "up_damage": 10, "starter": true, "restriction": CardData.CharacterRestriction.CULTIST})
	_make_card({"id": &"cu01", "name": "フルスロットル", "desc": "このターンの行動コストが半額（端数切上）。自分に5ダメ+毒1", "ap": 0, "fuel": 3, "tags": [CardData.Tag.CHARACTER], "self_damage": 5, "starter": true, "restriction": CardData.CharacterRestriction.CULTIST, "halve_ap": true})
	_make_card({"id": &"cu02", "name": "加速の祈り", "desc": "3ブロック+1ドロー", "ap": 1, "tags": [CardData.Tag.CHARACTER], "block": 3, "draw": 1, "up_block": 5, "starter": true, "restriction": CardData.CharacterRestriction.CULTIST})
	_make_card({"id": &"cu03", "name": "聖なる炎", "desc": "10ダメージ", "ap": 2, "fuel": 1, "tags": [CardData.Tag.CHARACTER], "damage": 10, "up_damage": 15, "restriction": CardData.CharacterRestriction.CULTIST})
	_make_card({"id": &"cu06", "name": "聖なる疾走", "desc": "8ダメージ。敵撃破時燃料+2", "ap": 2, "fuel": 1, "tags": [CardData.Tag.CHARACTER], "damage": 8, "up_damage": 12, "restriction": CardData.CharacterRestriction.CULTIST})
	_make_card({"id": &"cu08", "name": "殉教", "desc": "自分に10ダメ。25ダメージ", "ap": 4, "tags": [CardData.Tag.CHARACTER], "rarity": CardData.Rarity.RARE, "damage": 25, "self_damage": 10, "up_damage": 38, "restriction": CardData.CharacterRestriction.CULTIST})
	_make_card({"id": &"cu10", "name": "アクセル全開", "desc": "+2AP。自分に3ダメ", "ap": 1, "fuel": 1, "tags": [CardData.Tag.CHARACTER], "self_damage": 3, "bonus_ap": 2, "restriction": CardData.CharacterRestriction.CULTIST})

func _register_contamination_cards() -> void:
	_make_card({"id": &"con01", "name": "放射線被曝", "desc": "ドロー時AP-1。使用不可", "ap": 0, "tags": [], "unplayable": true})
