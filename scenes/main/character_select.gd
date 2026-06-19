extends Control

const CHARACTER_DATA := {
	&"cultist": {
		"name": "カルティスト — アタルパ",
		"desc": "V8カルト教徒。高速・高威力・高燃費。\n燃料を攻めに使う特化型。\nHP: 65",
		"hp": 65,
		"deck": [&"st_at01", &"st_at01", &"st_at01", &"st_at02", &"st_at02", &"defend", &"defend", &"defend", &"cu01", &"cu02"],
		"system": &"none",
	},
}

var selected_id: StringName = &""

func _ready() -> void:
	_build_character_list()
	$StartButton.pressed.connect(_on_start)
	$BackButton.pressed.connect(_on_back)
	$StartButton.disabled = true

func _build_character_list() -> void:
	for id in CHARACTER_DATA:
		if not MetaProgression.is_unlocked(id):
			continue
		var data: Dictionary = CHARACTER_DATA[id]
		var btn := Button.new()
		btn.text = data["name"]
		btn.custom_minimum_size = Vector2(400, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_character_selected.bind(id))
		$CharacterList.add_child(btn)

func _on_character_selected(id: StringName) -> void:
	selected_id = id
	var data: Dictionary = CHARACTER_DATA[id]
	$DescriptionLabel.text = data["desc"]
	$StartButton.disabled = false

func _on_start() -> void:
	if selected_id == &"":
		return
	var data: Dictionary = CHARACTER_DATA[selected_id]
	var character := CharacterData.new()
	character.id = selected_id
	character.display_name = data["name"]
	character.max_hp = data["hp"]
	character.starter_deck_ids.assign(data["deck"])
	character.unique_system = data["system"]
	GameManager.start_run(character)
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
