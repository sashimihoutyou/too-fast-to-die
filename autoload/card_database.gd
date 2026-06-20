extends Node

var _cards: Dictionary = {}

func _ready() -> void:
	_load_cards_from_directory("res://resources/cards/starter")
	_load_cards_from_directory("res://resources/cards/shared")
	_load_cards_from_directory("res://resources/cards/cultist")
	_load_cards_from_directory("res://resources/cards/ex_raider")
	_load_cards_from_directory("res://resources/cards/wanderer")
	_load_cards_from_directory("res://resources/cards/beast_master")
	_load_cards_from_directory("res://resources/cards/conqueror")
	_load_cards_from_directory("res://resources/cards/contamination")

func get_card(id: StringName) -> CardData:
	return _cards.get(id, null)

func get_reward_pool(act: int, character_id: StringName) -> Array[CardData]:
	var pool: Array[CardData] = []
	var char_restriction := _character_id_to_restriction(character_id)
	for card: CardData in _cards.values():
		if card.is_starter or card.is_unplayable:
			continue
		if card.restriction != CardData.CharacterRestriction.NONE:
			if card.restriction != char_restriction:
				continue
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

func _load_cards_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := path.path_join(file_name)
			var card: CardData = load(full_path)
			if card != null and card.id != &"":
				_cards[card.id] = card
		file_name = dir.get_next()
