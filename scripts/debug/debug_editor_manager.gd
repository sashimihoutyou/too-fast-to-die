extends Node

var _overlay: CanvasLayer
var _is_open: bool = false
const OVERLAY_SCENE_PATH: String = "res://scenes/debug/debug_editor_overlay.tscn"


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F12:
			toggle_editor()
			get_viewport().set_input_as_handled()


func toggle_editor() -> void:
	if not OS.is_debug_build():
		return

	if _is_open:
		request_close()
	else:
		_open_editor()


func request_close() -> void:
	if _overlay != null and _overlay.has_method("request_close"):
		_overlay.request_close()
	else:
		force_close()


func _open_editor() -> void:
	if _overlay == null:
		var scene: PackedScene = load(OVERLAY_SCENE_PATH)
		if scene == null:
			push_error("DebugEditorManager: Failed to load overlay scene")
			return
		_overlay = scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_overlay)
	else:
		_overlay.visible = true

	get_tree().paused = true
	_is_open = true


func force_close() -> void:
	if _overlay != null:
		_overlay.visible = false
	get_tree().paused = false
	_is_open = false


func is_editor_open() -> bool:
	return _is_open
