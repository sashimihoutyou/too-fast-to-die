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

const HAND_SIZE := 5

func build_starter_deck(character: CharacterData) -> void:
	master_deck.clear()
	for card_id in character.starter_deck_ids:
		var card := CardDatabase.get_card(card_id)
		if card:
			master_deck.append(card.duplicate_card())
	_reset_piles()

func _reset_piles() -> void:
	draw_pile = master_deck.duplicate()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
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
			var card := draw_pile.pop_back()
			hand.append(card)
			drawn.append(card)
	cards_drawn.emit(drawn)
	return drawn

func discard_hand() -> void:
	for card in hand:
		discard_pile.append(card)
		card_discarded.emit(card)
	hand.clear()

func play_card(card: CardData) -> void:
	hand.erase(card)
	if card.is_exhaustible:
		exhaust_pile.append(card)
		card_exhausted.emit(card)
	else:
		discard_pile.append(card)
		card_discarded.emit(card)

func add_card_to_deck(card: CardData) -> void:
	var copy := card.duplicate_card()
	master_deck.append(copy)

func remove_card_from_deck(card: CardData) -> void:
	master_deck.erase(card)

func get_deck_count() -> int:
	return draw_pile.size()

func get_discard_count() -> int:
	return discard_pile.size()
