class_name DeckListPopup
extends ColorRect

signal card_selected(card: CardData)
signal closed

const MODAL_OVERLAY_NAME := "ModalOverlay"

func setup(
	title_text: String,
	cards: Array[CardData],
	selectable: bool = false,
	close_text: String = "閉じる",
	preview_callable: Callable = Callable()
) -> void:
	name = MODAL_OVERLAY_NAME
	color = Color(0.0, 0.0, 0.0, 0.7)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 500)
	panel.offset_left = -350
	panel.offset_top = -250
	panel.offset_right = 350
	panel.offset_bottom = 250
	add_child(panel)

	var title := Label.new()
	title.text = title_text
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 10
	title.offset_bottom = 35
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 45
	scroll.offset_bottom = -50
	scroll.offset_left = 10
	scroll.offset_right = -10
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(vbox)

	for card: CardData in cards:
		var label_text: String = _get_card_text(card, preview_callable)
		if selectable:
			var btn := Button.new()
			btn.text = label_text
			btn.custom_minimum_size = Vector2(640, 40)
			btn.add_theme_font_size_override("font_size", 15)
			btn.pressed.connect(_select_card.bind(card))
			vbox.add_child(btn)
		else:
			var label := Label.new()
			label.text = label_text
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.add_theme_font_size_override("font_size", 14)
			if card.upgraded:
				label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			vbox.add_child(label)

	var close_btn := Button.new()
	close_btn.text = close_text
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.custom_minimum_size = Vector2(120, 35)
	close_btn.offset_left = -60
	close_btn.offset_top = -45
	close_btn.offset_right = 60
	close_btn.offset_bottom = -10
	close_btn.pressed.connect(_close)
	panel.add_child(close_btn)

func _get_card_text(card: CardData, preview_callable: Callable) -> String:
	if preview_callable.is_valid():
		return String(preview_callable.call(card))
	var parts: Array[String] = []
	parts.append(card.get_display_name())
	parts.append("AP:%d" % card.ap_cost)
	if card.get_effective_damage() > 0:
		parts.append("DMG:%d" % card.get_effective_damage())
	if card.get_effective_block() > 0:
		parts.append("BLK:%d" % card.get_effective_block())
	parts.append(card.description)
	return " | ".join(parts)

func _select_card(card: CardData) -> void:
	card_selected.emit(card)
	queue_free()

func _close() -> void:
	closed.emit()
	queue_free()
