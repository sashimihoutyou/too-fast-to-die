extends Node

signal cards_drawn(cards: Array[CardData])
signal card_discarded(card: CardData)
signal card_exhausted(card: CardData)
signal deck_shuffled()

var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var exhaust_pile: Array[CardData] = []
var master_deck: Array[CardData] = []
var _temporary_instance_ids: Dictionary = {}

const HAND_SIZE := 5

func build_starter_deck(character: CharacterData) -> void:
	master_deck.clear()
	for card_id: StringName in character.starter_deck_ids:
		var card := CardDatabase.get_card(card_id)
		if card:
			master_deck.append(card.duplicate_card())
	_reset_piles()

func _reset_piles() -> void:
	draw_pile = master_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	_temporary_instance_ids.clear()
	shuffle_draw_pile()

func start_combat() -> void:
	_reset_piles()

func shuffle_draw_pile() -> void:
	draw_pile.shuffle()
	deck_shuffled.emit()

func draw_cards(count: int = HAND_SIZE) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			shuffle_draw_pile()
		if not draw_pile.is_empty():
			var card: CardData = draw_pile.pop_back()
			hand.append(card)
			drawn.append(card)
			if card.is_unplayable:
				CombatManager.apply_contamination_on_draw(card)
	cards_drawn.emit(drawn)
	return drawn

func discard_hand() -> void:
	for card: CardData in hand:
		if is_temporary_card(card):
			_temporary_instance_ids.erase(card.instance_id)
			card_exhausted.emit(card)
		else:
			discard_pile.append(card)
			card_discarded.emit(card)
	hand.clear()

func play_card(card: CardData) -> void:
	if not hand.has(card):
		return
	hand.erase(card)
	if is_temporary_card(card):
		_temporary_instance_ids.erase(card.instance_id)
		card_exhausted.emit(card)
		return
	if card.is_exhaustible:
		exhaust_pile.append(card)
		card_exhausted.emit(card)
	else:
		discard_pile.append(card)
		card_discarded.emit(card)

func add_temporary_card_to_hand(card_id: StringName) -> bool:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return false
	var copy: CardData = card.duplicate_card()
	hand.append(copy)
	_temporary_instance_ids[copy.instance_id] = true
	var drawn: Array[CardData] = []
	drawn.append(copy)
	cards_drawn.emit(drawn)
	return true

func is_temporary_card(card: CardData) -> bool:
	return card != null and _temporary_instance_ids.has(card.instance_id)

func has_card_id_in_hand(card_id: StringName) -> bool:
	for card: CardData in hand:
		if card.id == card_id:
			return true
	return false

func add_card_to_deck(card: CardData) -> void:
	var copy := card.duplicate_card()
	master_deck.append(copy)

func add_card_id_to_deck(card_id: StringName) -> bool:
	var card: CardData = CardDatabase.get_card(card_id)
	if card == null:
		return false
	add_card_to_deck(card)
	return true

func remove_card_from_deck(card: CardData) -> void:
	master_deck.erase(card)

func remove_cards_by_ids(card_ids: Array[StringName]) -> void:
	for card_id: StringName in card_ids:
		_remove_card_by_id_from_array(master_deck, card_id)
		_remove_card_by_id_from_array(draw_pile, card_id)
		_remove_card_by_id_from_array(hand, card_id)
		_remove_card_by_id_from_array(discard_pile, card_id)
		_remove_card_by_id_from_array(exhaust_pile, card_id)

func _remove_card_by_id_from_array(cards: Array[CardData], card_id: StringName) -> void:
	for i: int in range(cards.size() - 1, -1, -1):
		var card: CardData = cards[i]
		if card.id == card_id:
			cards.remove_at(i)
			return

func get_deck_count() -> int:
	return draw_pile.size()

func get_discard_count() -> int:
	return discard_pile.size()
