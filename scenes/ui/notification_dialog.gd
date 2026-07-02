class_name NotificationDialog
extends ColorRect

signal closed

const MODAL_OVERLAY_NAME := "ModalOverlay"

func setup(message: String, close_text: String = "閉じる") -> void:
	name = MODAL_OVERLAY_NAME
	color = Color(0.0, 0.0, 0.0, 0.45)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400, 200)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -200
	panel.offset_top = -100
	panel.offset_right = 200
	panel.offset_bottom = 100
	add_child(panel)

	var label := Label.new()
	label.text = message
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)

	var close_btn := Button.new()
	close_btn.text = close_text
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.offset_left = -50
	close_btn.offset_top = -50
	close_btn.offset_right = 50
	close_btn.offset_bottom = -10
	close_btn.pressed.connect(_close)
	panel.add_child(close_btn)

func _close() -> void:
	closed.emit()
	queue_free()
