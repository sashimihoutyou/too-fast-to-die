extends Control

const CHARACTER_DIR := "res://resources/characters/"

var _characters: Array[CharacterData] = []
var selected_id: StringName = &""

func _ready() -> void:
	_load_characters()
	_build_character_list()
	$StartButton.pressed.connect(_on_start)
	$BackButton.pressed.connect(_on_back)
	$StartButton.disabled = true

func _load_characters() -> void:
	var dir := DirAccess.open(CHARACTER_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := CHARACTER_DIR.path_join(file_name)
			var character: CharacterData = load(full_path)
			if character != null and character.id != &"" and character.is_playable:
				_characters.append(character)
		file_name = dir.get_next()

func _build_character_list() -> void:
	for character: CharacterData in _characters:
		if not MetaProgression.is_unlocked(character.id):
			var locked_btn := Button.new()
			locked_btn.text = "??? — %s" % character.unlock_condition
			locked_btn.custom_minimum_size = Vector2(400, 60)
			locked_btn.add_theme_font_size_override("font_size", 20)
			locked_btn.disabled = true
			$CharacterList.add_child(locked_btn)
			continue
		var btn := Button.new()
		btn.text = character.display_name
		btn.custom_minimum_size = Vector2(400, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_character_selected.bind(character))
		$CharacterList.add_child(btn)

func _on_character_selected(character: CharacterData) -> void:
	selected_id = character.id
	var system_name := _system_display_name(character.unique_system)
	var desc := "%s\nHP: %d\n固有システム: %s" % [character.display_name, character.max_hp, system_name]
	if character.deck_limit > 0:
		desc += "\nデッキ上限: %d枚" % character.deck_limit
	$DescriptionLabel.text = desc
	$StartButton.disabled = false

func _on_start() -> void:
	if selected_id == &"":
		return
	var character: CharacterData = null
	for c: CharacterData in _characters:
		if c.id == selected_id:
			character = c
			break
	if character == null:
		return
	GameManager.start_run(character)
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")

func _system_display_name(system: StringName) -> String:
	match system:
		&"gear": return "速度（ギア）"
		&"heat": return "ヒート（激情）"
		&"investigation": return "調査ゲージ"
		&"partner": return "相棒"
		&"aura": return "闘気（オーラ）"
		&"euphoria": return "エクスタシー"
	return "なし"
