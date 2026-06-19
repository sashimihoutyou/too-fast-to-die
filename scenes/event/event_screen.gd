extends Control

const EVENTS := [
	{
		"title": "行き倒れの旅人",
		"body": "道端で旅人が倒れている。かすかに息がある。",
		"choices": [
			{"label": "医薬品で助ける", "req": "medicine>=1", "result": "医薬品を使い、旅人を助けた。東の噂を教えてくれた。", "medicine": -1, "karma": 3},
			{"label": "見て見ぬふりをする", "req": "", "result": "背を向けた。", "karma": 0},
			{"label": "身ぐるみ剥ぐ", "req": "", "result": "わずかな燃料を手に入れた。", "fuel": 2, "karma": -5},
		],
	},
	{
		"title": "乾いた村",
		"body": "集落の浄水装置が故障し、住民が脱水症状を起こしている。",
		"choices": [
			{"label": "スクラップ3を使って修理する", "req": "scrap>=3", "result": "浄水装置が再び動き始めた。感謝の印に燃料をくれた。", "scrap": -3, "karma": 5, "fuel": 4},
			{"label": "見捨てて立ち去る", "req": "", "result": "背後で子供の泣き声がした。振り返らなかった。", "karma": 0},
			{"label": "水の在処を教える代わりに物資を要求する", "req": "", "result": "取引は成立した。彼らの目に光は戻らなかった。", "fuel": 3, "karma": -3},
		],
	},
	{
		"title": "武装した連中",
		"body": "数人の武装した男たちが旅人を囲んでいる。助けに入るか。",
		"choices": [
			{"label": "助ける（戦闘発生）", "req": "", "result": "戦闘を切り抜けた。旅人から感謝された。", "karma": 5, "fuel": 3},
			{"label": "見捨てる", "req": "", "result": "叫び声が聞こえたが、足を止めなかった。", "karma": -2},
		],
	},
	{
		"title": "廃車の中に",
		"body": "道路脇の廃車に何かが光っている。",
		"choices": [
			{"label": "調べる", "req": "", "result": "使えるパーツが見つかった。", "scrap": 3},
			{"label": "罠かもしれない、通り過ぎる", "req": "", "result": "用心に越したことはない。"},
		],
	},
	{
		"title": "ダストランナーとの出会い",
		"body": "独立商人が休憩している。少し話をしないかと誘ってくる。",
		"choices": [
			{"label": "話を聞く", "req": "", "result": "東の噂と道中の情報を教えてくれた。", "karma": 1},
			{"label": "燃料を分け合う", "req": "fuel>=3", "result": "分け合った結果、お互い得をした。", "fuel": -1, "karma": 3},
			{"label": "無視する", "req": "", "result": "一人の旅は続く。"},
		],
	},
]

var current_event: Dictionary

func _ready() -> void:
	current_event = EVENTS[randi() % EVENTS.size()]
	$TitleLabel.text = current_event["title"]
	$BodyLabel.text = current_event["body"]
	_build_choices()

func _build_choices() -> void:
	for child in $ChoiceContainer.get_children():
		child.queue_free()
	var choices: Array = current_event["choices"]
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = choice["label"]
		btn.custom_minimum_size = Vector2(500, 45)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_choice.bind(i))
		var req: String = choice.get("req", "")
		if not _check_requirement(req):
			btn.disabled = true
			btn.text += " (条件不足)"
		$ChoiceContainer.add_child(btn)

func _check_requirement(req: String) -> bool:
	if req == "":
		return true
	if req.begins_with("medicine>="):
		var val := int(req.split(">=")[1])
		return ResourceManager.medicine >= val
	if req.begins_with("fuel>="):
		var val := int(req.split(">=")[1])
		return ResourceManager.fuel >= val
	if req.begins_with("scrap>="):
		var val := int(req.split(">=")[1])
		return ResourceManager.scrap >= val
	return true

func _on_choice(idx: int) -> void:
	var choices: Array = current_event["choices"]
	var choice: Dictionary = choices[idx]
	if choice.has("fuel"):
		var amount: int = choice["fuel"]
		if amount > 0:
			ResourceManager.add_fuel(amount)
		elif amount < 0:
			ResourceManager.consume_fuel(-amount)
	if choice.has("karma"):
		KarmaManager.add_karma(choice["karma"])
	if choice.has("scrap"):
		var amount: int = choice["scrap"]
		if amount > 0:
			ResourceManager.add_scrap(amount)
		elif amount < 0:
			ResourceManager.consume_scrap(-amount)
	if choice.has("medicine"):
		var amount: int = choice["medicine"]
		if amount > 0:
			ResourceManager.add_medicine(amount)
		elif amount < 0:
			ResourceManager.use_medicine()

	for child in $ChoiceContainer.get_children():
		child.queue_free()

	$BodyLabel.text = choice.get("result", "")

	var continue_btn := Button.new()
	continue_btn.text = "続ける"
	continue_btn.custom_minimum_size = Vector2(200, 45)
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.pressed.connect(_return_to_map)
	$ChoiceContainer.add_child(continue_btn)

func _return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
