extends Control

func _ready() -> void:
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue)
	$VBoxContainer/ContinueButton.visible = SaveManager.has_save()
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)
	if OS.is_debug_build():
		$VBoxContainer/DebugEditorButton.visible = true
		$VBoxContainer/DebugEditorButton.pressed.connect(_on_debug_editor)

func _on_continue() -> void:
	if SaveManager.load_run():
		get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")

func _on_new_game() -> void:
	SaveManager.delete_save()
	get_tree().change_scene_to_file("res://scenes/main/character_select.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _on_debug_editor() -> void:
	DebugEditorManager.toggle_editor()
