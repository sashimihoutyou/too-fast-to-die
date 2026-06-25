extends Control

var current_event: EventData

func _ready() -> void:
	current_event = _pick_event()
	if current_event == null:
		_show_fallback()
		return
	GameManager.event_flags[current_event.id] = true
	$TitleLabel.text = current_event.title
	$BodyLabel.text = current_event.body_text
	_build_choices()

# カルマ・区間・キャラ条件で利用可能なイベントをDBから抽選する。未遭遇を優先。
func _pick_event() -> EventData:
	# サブストーリーの遅延ペイロードがあれば最優先で強制発火する。
	var forced_id := QuestManager.get_pending_payload(GameManager.current_act)
	if forced_id != &"":
		var forced := EventManager.get_event(forced_id)
		if forced != null:
			return forced
	var available := EventManager.get_available_events(
		GameManager.current_character.id, KarmaManager.karma, GameManager.current_act)
	if available.is_empty():
		return null
	var unseen: Array[EventData] = []
	for ev: EventData in available:
		if not GameManager.event_flags.get(ev.id, false):
			unseen.append(ev)
	var pool: Array[EventData] = unseen if not unseen.is_empty() else available
	return pool[randi() % pool.size()]

func _build_choices() -> void:
	for child in $ChoiceContainer.get_children():
		child.queue_free()
	for i in current_event.choices.size():
		var choice: EventChoiceData = current_event.choices[i]
		var btn := Button.new()
		btn.text = choice.label
		btn.custom_minimum_size = Vector2(520, 45)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_choice.bind(i))
		if not _check_requirement(choice.requirement):
			btn.disabled = true
			btn.text += " (条件不足)"
		if choice.heat_max >= 0 and CombatManager.player_heat > choice.heat_max:
			btn.disabled = true
			if CombatManager.player_heat >= 90:
				btn.visible = false
			else:
				btn.text += " (激情が高すぎる)"
		$ChoiceContainer.add_child(btn)

func _check_requirement(req: String) -> bool:
	if req == "":
		return true
	if req.begins_with("medicine>="):
		return ResourceManager.medicine >= int(req.split(">=")[1])
	if req.begins_with("fuel>="):
		return ResourceManager.fuel >= int(req.split(">=")[1])
	if req.begins_with("scrap>="):
		return ResourceManager.scrap >= int(req.split(">=")[1])
	if req.begins_with("hp>="):
		return CombatManager.player_hp >= int(req.split(">=")[1])
	if req.begins_with("karma>="):
		return KarmaManager.karma >= int(req.split(">=")[1])
	if req.begins_with("character=="):
		return GameManager.current_character.id == StringName(req.split("==")[1])
	if req.begins_with("flag=="):
		return bool(GameManager.event_flags.get(StringName(req.split("==")[1]), false))
	if req.begins_with("flag!="):
		return not bool(GameManager.event_flags.get(StringName(req.split("!=")[1]), false))
	if req.begins_with("companion=="):
		if GameManager.current_companion == null:
			return false
		return GameManager.current_companion.id == StringName(req.split("==")[1])
	if req == "no_companion":
		return GameManager.current_companion == null
	if req.begins_with("faith>="):
		return GameManager.faith >= int(req.split(">=")[1])
	if req.begins_with("faith<="):
		return GameManager.faith <= int(req.split("<=")[1])
	return false

func _on_choice(idx: int) -> void:
	var choice: EventChoiceData = current_event.choices[idx]
	_apply_choice(choice)
	QuestManager.notify_event_resolved(current_event.id)
	if choice.triggers_combat:
		_start_event_combat(choice.combat_enemy_ids)
		return
	for child in $ChoiceContainer.get_children():
		child.queue_free()
	$BodyLabel.text = choice.result_text
	var continue_btn := Button.new()
	continue_btn.text = "続ける"
	continue_btn.custom_minimum_size = Vector2(200, 45)
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.pressed.connect(_return_to_map)
	$ChoiceContainer.add_child(continue_btn)

func _apply_choice(choice: EventChoiceData) -> void:
	if choice.fuel_change > 0:
		ResourceManager.add_fuel(choice.fuel_change)
	elif choice.fuel_change < 0:
		ResourceManager.consume_fuel(-choice.fuel_change)
	if choice.scrap_change > 0:
		ResourceManager.add_scrap(choice.scrap_change)
	elif choice.scrap_change < 0:
		ResourceManager.consume_scrap(-choice.scrap_change)
	if choice.medicine_change > 0:
		ResourceManager.add_medicine(choice.medicine_change)
	elif choice.medicine_change < 0:
		ResourceManager.use_medicine()
	if choice.karma_change != 0:
		KarmaManager.add_karma(choice.karma_change)
	if choice.hp_change != 0:
		CombatManager.player_hp = clampi(
			CombatManager.player_hp + choice.hp_change, 0, CombatManager.player_max_hp)
	if choice.sets_flag != &"":
		GameManager.event_flags[choice.sets_flag] = true
	if choice.starts_quest != &"":
		QuestManager.record_outcome(choice.starts_quest, choice.quest_outcome)
	if choice.faith_change != 0:
		GameManager.add_faith(choice.faith_change)
	if choice.companion_id != &"":
		var comp: CompanionData = CompanionDatabase.get_companion(choice.companion_id)
		if comp != null:
			GameManager.recruit_companion(comp)

func _start_event_combat(enemy_ids: Array[StringName] = []) -> void:
	var enemies: Array[EnemyData] = []
	for eid: StringName in enemy_ids:
		var ed := EnemyDatabase.get_enemy(eid)
		if ed != null:
			enemies.append(ed)
	if enemies.is_empty():
		var pool := EnemyDatabase.get_enemies_for_act(GameManager.current_act)
		if pool.is_empty():
			pool = EnemyDatabase.get_enemies_for_act(1)
		if not pool.is_empty():
			pool.shuffle()
			enemies.append(pool[0])
	if enemies.is_empty():
		_return_to_map()
		return
	CombatManager.start_combat(enemies)
	get_tree().change_scene_to_file("res://scenes/combat/combat_screen.tscn")

func _show_fallback() -> void:
	$TitleLabel.text = "静かな道のり"
	$BodyLabel.text = "特に何も起こらなかった。あなたは先を急いだ。"
	for child in $ChoiceContainer.get_children():
		child.queue_free()
	var btn := Button.new()
	btn.text = "続ける"
	btn.custom_minimum_size = Vector2(200, 45)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_return_to_map)
	$ChoiceContainer.add_child(btn)

func _return_to_map() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
