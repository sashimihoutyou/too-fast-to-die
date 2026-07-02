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
	$PortraitImage.visible = false

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
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_character_selected.bind(character))
		$CharacterList.add_child(btn)

func _on_character_selected(character: CharacterData) -> void:
	selected_id = character.id
	var portrait: Texture2D = _load_character_portrait(character)
	$PortraitImage.texture = portrait
	$PortraitImage.visible = portrait != null

	var system_name: String = _system_display_name(character.unique_system)
	var desc: String = "%s\nHP: %d\n固有システム: %s\n%s" % [
		character.display_name,
		character.max_hp,
		system_name,
		_system_summary(character.unique_system),
	]
	if character.deck_limit > 0:
		desc += "\nデッキ上限: %d枚" % character.deck_limit
	desc += "\n%s" % _starter_deck_summary(character)
	if not character.unlock_condition.is_empty():
		desc += "\n解放条件: %s" % character.unlock_condition
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
	GameManager.go_to_state(GameManager.GameState.MAP)

func _on_back() -> void:
	GameManager.go_to_state(GameManager.GameState.TITLE)

func _system_display_name(system: StringName) -> String:
	match system:
		&"gear": return "速度（ギア）"
		&"heat": return "ヒート（激情）"
		&"investigation": return "調査ゲージ"
		&"partner": return "相棒"
		&"aura": return "闘気（オーラ）"
		&"euphoria": return "エクスタシー"
	return "なし"

func _system_summary(system: StringName) -> String:
	match system:
		&"gear":
			return "バイクカードでギアを上げ、最大加速から一気に押し切る。"
		&"heat":
			return "被弾とブロックでヒートを溜め、カード性能を荒々しく変質させる。"
		&"investigation":
			return "敵を調査し、意図や弱点を暴いてから確実に仕留める。"
		&"partner":
			return "相棒の獣と役割を分け、攻撃と防御を並行して回す。"
		&"aura":
			return "闘気を蓄え、条件を満たしたカードで大きな一撃を狙う。"
		&"euphoria":
			return "エクスタシーの帯域を管理し、快楽と危険の境目で火力を出す。"
	return "標準的なカード運用で荒野を抜ける。"

func _starter_deck_summary(character: CharacterData) -> String:
	var attack_count: int = 0
	var block_count: int = 0
	var utility_count: int = 0
	var names: Array[String] = []
	for card_id: StringName in character.starter_deck_ids:
		var card: CardData = CardDatabase.get_card(card_id)
		if card == null:
			continue
		if card.get_effective_damage() > 0:
			attack_count += 1
		elif card.get_effective_block() > 0:
			block_count += 1
		else:
			utility_count += 1
		if names.size() < 5:
			names.append(card.get_display_name())
	var parts: Array[String] = [
		"初期デッキ: %d枚" % character.starter_deck_ids.size(),
		"攻撃%d" % attack_count,
		"防御%d" % block_count,
		"補助%d" % utility_count,
	]
	var summary: String = " / ".join(parts)
	if not names.is_empty():
		summary += "\n主なカード: %s" % "、".join(names)
	return summary

func _load_character_portrait(character: CharacterData) -> Texture2D:
	if character.portrait != null:
		return character.portrait
	var path: String = "res://assets/characters/portraits/%s/normal.png" % String(character.id)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	match character.id:
		&"cultist":
			return load("res://assets/characters/atarpa.png") as Texture2D
		&"ex_raider":
			return load("res://assets/characters/vespa.png") as Texture2D
	return null
