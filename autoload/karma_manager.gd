extends Node

signal karma_changed(new_value: int, band: StringName)

var karma: int = 0

func reset() -> void:
	karma = 0
	karma_changed.emit(karma, get_band())

func add_karma(amount: int) -> void:
	karma = clampi(karma + amount, -100, 100)
	karma_changed.emit(karma, get_band())

func get_band() -> StringName:
	if karma >= 60:
		return &"saint"
	elif karma >= 20:
		return &"good"
	elif karma >= -19:
		return &"neutral"
	elif karma >= -59:
		return &"villain"
	else:
		return &"evil"

func get_band_display() -> String:
	match get_band():
		&"saint": return "聖人"
		&"good": return "善人"
		&"neutral": return "中立"
		&"villain": return "悪党"
		&"evil": return "外道"
	return "中立"
