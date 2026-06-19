extends Control

func _ready() -> void:
	$DistanceLabel.text = "走行距離: %dkm" % GameManager.distance_km
	$KarmaLabel.text = "最終カルマ: %d (%s)" % [KarmaManager.karma, KarmaManager.get_band_display()]
	$TotalDistanceLabel.text = "累積走行距離: %dkm" % MetaProgression.total_distance_km
	GameManager.end_run(&"defeat")
	$ReturnButton.pressed.connect(_on_return)

func _on_return() -> void:
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
