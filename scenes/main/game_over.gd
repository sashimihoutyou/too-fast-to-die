extends Control

func _ready() -> void:
	var result: StringName = GameManager.pending_result
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
	$ReturnButton.pressed.connect(_on_return)

func _on_return() -> void:
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
