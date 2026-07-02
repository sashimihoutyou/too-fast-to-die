extends Control

var _retry_character: CharacterData = null

func _ready() -> void:
	var result: StringName = GameManager.pending_result
	_retry_character = GameManager.current_character
	if result == &"victory":
		$TitleLabel.text = "オアシスに到達した"
		$TitleLabel.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	else:
		$TitleLabel.text = "エンストした"
		$TitleLabel.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	$DistanceLabel.text = "走行距離: %dkm" % GameManager.distance_km
	$KarmaLabel.text = "最終カルマ: %d (%s)" % [KarmaManager.karma, KarmaManager.get_band_display()]
	if result == &"victory":
		var epilogues: Array[String] = GameManager.get_companion_ending_epilogues()
		$CompanionEpilogueLabel.text = "\n\n".join(epilogues)
	GameManager.end_run(result)
	$TotalDistanceLabel.text = "累積走行距離: %dkm" % MetaProgression.total_distance_km
	$RetryButton.visible = _retry_character != null
	$RetryButton.pressed.connect(_on_retry)
	$ReturnButton.pressed.connect(_on_return)

func _on_retry() -> void:
	if _retry_character == null:
		return
	GameManager.start_run(_retry_character)
	GameManager.go_to_state(GameManager.GameState.MAP)

func _on_return() -> void:
	GameManager.go_to_state(GameManager.GameState.TITLE)
