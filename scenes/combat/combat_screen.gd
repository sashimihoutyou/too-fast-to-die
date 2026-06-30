extends Control

var card_buttons: Array[Button] = []
var enemy_panels: Array[PanelContainer] = []
var target_buttons: Array[Button] = []
var hp_labels: Array[Label] = []
var hp_bars: Array[ProgressBar] = []
var block_labels: Array[Label] = []
var weakness_labels: Array[Label] = []
var intent_labels: Array[Label] = []
var status_labels: Array[Label] = []
var item_buttons: Array[Button] = []
var selected_card: CardData = null
var awaiting_reward: bool = false
var _last_player_hp: int = 0
var _heat_label: Label = null
var _aura_label: Label = null
var _investigation_label: Label = null
var _euphoria_label: Label = null
var _beast_label: Label = null
var _engine_brake_button: Button = null
var _tooltip_panel: PanelContainer = null
var _tooltip_title_label: Label = null
var _tooltip_body_label: Label = null
var _tooltip_delay_timer: Timer = null
var _tooltip_pending_title: String = ""
var _tooltip_pending_body: String = ""
var _tooltip_pending_source: Control = null
var _portrait_default_texture: Texture2D = null

func _ready() -> void:
	_last_player_hp = CombatManager.player_hp
	_setup_tooltip_overlay()
	_setup_player_portrait_hud()
	_setup_signals()
	_build_enemy_display()
	_show_target_buttons(false)
	_setup_heat_meter()
	_setup_aura_meter()
	_setup_investigation_meter()
	_setup_euphoria_meter()
	_setup_beast_display()
	_setup_engine_brake_button()
	_update_player_hud()
	_update_hand()
	_update_controls()
	_update_consumable_buttons()

func _setup_tooltip_overlay() -> void:
	_tooltip_delay_timer = Timer.new()
	_tooltip_delay_timer.one_shot = true
	_tooltip_delay_timer.wait_time = 0.18
	_tooltip_delay_timer.timeout.connect(_show_pending_tooltip)
	add_child(_tooltip_delay_timer)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.custom_minimum_size = Vector2(330, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.04, 0.96)
	style.border_color = Color(0.85, 0.68, 0.35, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	_tooltip_title_label = Label.new()
	_tooltip_title_label.add_theme_font_size_override("font_size", 16)
	_tooltip_title_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	_tooltip_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_tooltip_title_label)

	_tooltip_body_label = Label.new()
	_tooltip_body_label.add_theme_font_size_override("font_size", 13)
	_tooltip_body_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	_tooltip_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tooltip_body_label.custom_minimum_size = Vector2(310, 0)
	box.add_child(_tooltip_body_label)

	margin.add_child(box)
	_tooltip_panel.add_child(margin)
	add_child(_tooltip_panel)

func _setup_player_portrait_hud() -> void:
	$PlayerHUD.mouse_entered.connect(_on_player_hud_hover.bind(true))
	$PlayerHUD.mouse_exited.connect(_on_player_hud_hover.bind(false))
	$PlayerHUD.mouse_default_cursor_shape = Control.CURSOR_HELP
	var character: CharacterData = GameManager.current_character
	if character == null:
		return
	$PlayerHUD/PortraitFallbackLabel.text = character.display_name
	var portrait: Texture2D = character.portrait
	if portrait == null:
		portrait = _load_fallback_portrait(character.id)
	_portrait_default_texture = portrait
	$PlayerHUD/PortraitImage.texture = portrait
	$PlayerHUD/PortraitFallbackLabel.visible = portrait == null
	_update_portrait_state()

func _load_fallback_portrait(character_id: StringName) -> Texture2D:
	var path: String = _portrait_path(character_id, "normal")
	if not ResourceLoader.exists(path):
		path = _legacy_portrait_path(character_id)
		if path == "" or not ResourceLoader.exists(path):
			return null
	return load(path) as Texture2D

func _load_portrait_variant(character_id: StringName, state_key: String) -> Texture2D:
	var path: String = _portrait_path(character_id, state_key)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _portrait_path(character_id: StringName, state_key: String) -> String:
	return "res://assets/characters/portraits/%s/%s.png" % [String(character_id), state_key]

func _legacy_portrait_path(character_id: StringName) -> String:
	match character_id:
		&"cultist":
			return "res://assets/characters/atarpa.png"
		&"ex_raider":
			return "res://assets/characters/vespa.png"
	return ""

func _request_tooltip(title: String, body: String, source: Control) -> void:
	if source == null or title == "":
		return
	_tooltip_pending_title = title
	_tooltip_pending_body = body
	_tooltip_pending_source = source
	if _tooltip_delay_timer != null:
		_tooltip_delay_timer.start()

func _hide_tooltip(source: Control = null) -> void:
	if source != null and _tooltip_pending_source != source:
		return
	if _tooltip_delay_timer != null:
		_tooltip_delay_timer.stop()
	_tooltip_pending_source = null
	if _tooltip_panel != null:
		_tooltip_panel.visible = false

func _show_pending_tooltip() -> void:
	if _tooltip_panel == null or _tooltip_pending_source == null:
		return
	if not is_instance_valid(_tooltip_pending_source):
		_hide_tooltip()
		return
	_tooltip_title_label.text = _tooltip_pending_title
	_tooltip_body_label.text = _tooltip_pending_body
	_tooltip_panel.visible = true
	_position_tooltip(_tooltip_pending_source)

func _position_tooltip(source: Control) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var source_rect: Rect2 = source.get_global_rect()
	var panel_size := Vector2(340.0, maxf(120.0, _tooltip_panel.size.y))
	var pos := Vector2(source_rect.position.x + source_rect.size.x + 12.0, source_rect.position.y)
	if pos.x + panel_size.x > viewport_size.x - 8.0:
		pos.x = source_rect.position.x - panel_size.x - 12.0
	if pos.x < 8.0:
		pos.x = 8.0
	if pos.y + panel_size.y > viewport_size.y - 8.0:
		pos.y = viewport_size.y - panel_size.y - 8.0
	if pos.y < 8.0:
		pos.y = 8.0
	_tooltip_panel.position = pos

func _on_player_hud_hover(hovering: bool) -> void:
	if hovering:
		_request_tooltip(_get_player_tooltip_title(), _get_player_tooltip_body(), $PlayerHUD)
	else:
		_hide_tooltip($PlayerHUD)

func _get_player_tooltip_title() -> String:
	if GameManager.current_character == null:
		return "プレイヤー"
	return GameManager.current_character.display_name

func _get_player_tooltip_body() -> String:
	var lines: Array[String] = []
	lines.append("HP: %d/%d" % [CombatManager.player_hp, CombatManager.player_max_hp])
	lines.append("AP: %d/%d" % [CombatManager.ap, CombatManager.max_ap])
	lines.append("ブロック: %d" % CombatManager.player_block)
	lines.append("%s: %d/%d" % [GameManager.get_travel_resource_name(), ResourceManager.fuel, ResourceManager.tank_capacity])
	var gauge_text := _get_unique_system_line()
	if gauge_text != "":
		lines.append(gauge_text)
	lines.append("")
	lines.append("状態異常")
	lines.append_array(_status_detail_lines(CombatManager.player_status))
	lines.append("")
	lines.append("一時効果")
	lines.append_array(_buff_detail_lines(CombatManager.player_buffs))
	return "\n".join(lines)

func _get_unique_system_line() -> String:
	if GameManager.current_character == null:
		return ""
	match GameManager.current_character.unique_system:
		&"gear":
			return "ギア: %d/%d" % [CombatManager.player_gear, CombatManager.GEAR_MAX]
		&"heat":
			return "ヒート: %d/%d" % [CombatManager.player_heat, CombatManager.HEAT_MAX]
		&"investigation":
			return "調査: %d/%d" % [CombatManager.player_investigation, CombatManager.INVESTIGATION_MAX]
		&"aura":
			return "闘気: %d/%d" % [CombatManager.player_aura, CombatManager.AURA_MAX]
		&"euphoria":
			return "エクスタシー: %d/%d" % [CombatManager.player_euphoria, CombatManager.EUPHORIA_MAX]
		&"partner":
			return "相棒: %s" % _beast_summary()
	return ""

func _beast_summary() -> String:
	if CombatManager.player_beasts.is_empty():
		return "なし"
	var parts: Array[String] = []
	for beast: Dictionary in CombatManager.player_beasts:
		var alive: bool = bool(beast.get("alive", false))
		if alive:
			var beast_name: String = String(beast.get("name", "獣"))
			var hp: int = int(beast.get("hp", 0))
			var max_hp: int = int(beast.get("max_hp", 0))
			var attack: int = int(beast.get("attack", 0))
			var guard: int = int(beast.get("guard", 0)) + int(beast.get("guard_bonus", 0))
			var turns_alive: int = int(beast.get("turns_alive", 0))
			parts.append("%s HP%d/%d 攻%d 軽%d 生存%d" % [beast_name, hp, max_hp, attack, maxi(0, guard), turns_alive])
	return "、".join(parts) if not parts.is_empty() else "なし"

func _status_detail_lines(status: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for key: String in ["burn", "bleed", "weak", "vulnerable", "strength", "atk_down", "charm", "investigation", "stun", "guard_break"]:
		var value: int = int(status.get(key, 0))
		if value <= 0:
			continue
		lines.append("%s %d: %s" % [_status_display_name(key), value, _status_description(key)])
	if lines.is_empty():
		lines.append("なし")
	return lines

func _buff_detail_lines(buffs: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for key: String in ["ultimate", "overcharge", "melee_power", "ranged_double", "strength_turn", "partner_defense"]:
		var value: int = int(buffs.get(key, 0))
		if value <= 0:
			continue
		lines.append("%s %d: %s" % [_buff_display_name(key), value, _buff_description(key)])
	if lines.is_empty():
		lines.append("なし")
	return lines

func _status_display_name(status_id: String) -> String:
	match status_id:
		"burn": return "炎上"
		"bleed": return "出血"
		"weak": return "弱体"
		"vulnerable": return "脆弱"
		"strength": return "筋力"
		"atk_down": return "攻撃低下"
		"charm": return "魅了"
		"investigation": return "調査"
		"stun": return "スタン"
		"guard_break": return "ガードブレイク"
	return status_id

func _status_description(status_id: String) -> String:
	match status_id:
		"burn": return "ターン処理時に値ぶんのダメージ。毎ターン1減少。"
		"bleed": return "ターン処理時に値ぶんのダメージ。毎ターン1減少。"
		"weak": return "与える攻撃ダメージが25%低下。毎ターン1減少。"
		"vulnerable": return "受ける攻撃ダメージが50%増加。毎ターン1減少。"
		"strength": return "攻撃ダメージに値ぶん加算。"
		"atk_down": return "次の攻撃ダメージから値ぶん減少。敵の攻撃後に消える。"
		"charm": return "攻撃力を下げる。3以上で愛の奴隷の対象になる。"
		"investigation": return "3以上、または敵全体で5以上になるとQ.E.D.の対象になる。"
		"stun": return "次の行動を失う。"
		"guard_break": return "ブロックを得られない。"
	return "未登録の状態です。"

func _buff_display_name(buff_id: String) -> String:
	match buff_id:
		"ultimate": return "フルスロットル"
		"overcharge": return "過充電"
		"melee_power": return "近接強化"
		"ranged_double": return "射撃倍化"
		"strength_turn": return "一時筋力"
		"partner_defense": return "防御指示"
	return buff_id

func _buff_description(buff_id: String) -> String:
	match buff_id:
		"ultimate": return "カードAPコスト-1。発動ターンはバイクカードの燃料コスト0。"
		"overcharge": return "AP不足でもカードを使える。足りないAPはHPで支払う。"
		"melee_power": return "近接攻撃のダメージ+3。"
		"ranged_double": return "射撃攻撃のダメージを倍化し、使用ごとに1減少。"
		"strength_turn": return "このターンだけ筋力を上げる。次ターン開始時に戻る。"
		"partner_defense": return "このターンの被ダメージを相棒が引き受ける。"
	return "未登録の一時効果です。"

func _card_tooltip_body(card: CardData) -> String:
	var lines: Array[String] = []
	var effective_cost: int = CombatManager.get_effective_ap_cost(card)
	var cost_text := "AP: %d" % effective_cost
	if effective_cost != card.ap_cost:
		cost_text += " (元%d)" % card.ap_cost
	var fuel_cost: int = CombatManager.get_effective_fuel_cost(card)
	if fuel_cost > 0:
		cost_text += " / %s: %d" % [GameManager.get_travel_resource_name(), fuel_cost]
	lines.append(cost_text)
	if CombatManager.is_heat_card_transformed(card):
		lines.append("タグ: 近接・固有")
	elif not card.tags.is_empty():
		lines.append("タグ: %s" % _tags_to_text(card.tags))
	var stats: Array[String] = []
	var preview_damage: int = card.get_effective_block() if CombatManager.is_heat_card_transformed(card) else card.get_effective_damage()
	if selected_card == card:
		var target_idx: int = _get_sole_alive_enemy()
		if target_idx >= 0:
			preview_damage = CombatManager.preview_damage(card, target_idx)
	if preview_damage > 0:
		stats.append("ダメージ: %d × %d" % [preview_damage, card.hit_count])
	if card.get_effective_block() > 0:
		if not CombatManager.is_heat_card_transformed(card):
			stats.append("ブロック: %d" % card.get_effective_block())
	if card.draw_count > 0:
		stats.append("ドロー: %d" % card.draw_count)
	if card.bonus_ap > 0:
		stats.append("AP回復: %d" % card.bonus_ap)
	if not stats.is_empty():
		lines.append(" / ".join(stats))
	lines.append("")
	if CombatManager.is_heat_card_transformed(card):
		lines.append("元のブロック値をダメージに変える。ターン終了時に元へ戻る。")
	else:
		lines.append(card.description)
	var effect_lines: Array[String] = _card_effect_detail_lines(card)
	if not effect_lines.is_empty():
		lines.append("")
		lines.append("効果補足")
		lines.append_array(effect_lines)
	return "\n".join(lines)

func _card_effect_detail_lines(card: CardData) -> Array[String]:
	var lines: Array[String] = []
	if card.status_effect != &"" and card.status_stacks != 0:
		var effect_key := String(CombatManager._map_status(card.status_effect))
		if CombatManager._is_player_effect(card.status_effect):
			effect_key = String(card.status_effect)
			lines.append("%s %d: %s" % [_buff_display_name(effect_key), card.status_stacks, _buff_description(effect_key)])
		elif card.status_effect == &"charm":
			lines.append("%s %d: %s" % [_status_display_name("charm"), card.status_stacks, _status_description("charm")])
		elif card.status_effect == &"investigate":
			lines.append("%s %d: %s" % [_status_display_name("investigation"), card.status_stacks, _status_description("investigation")])
		elif effect_key != "":
			lines.append("%s %d: %s" % [_status_display_name(effect_key), card.status_stacks, _status_description(effect_key)])
	if card.ap_cost_reduction > 0:
		lines.append("AP軽減 %d: この戦闘中のカードコストを下げる効果。" % card.ap_cost_reduction)
	if card.self_damage > 0:
		lines.append("自傷 %d: 使用時に自分のHPを失う。" % card.self_damage)
	return lines

func _enemy_tooltip_title(idx: int) -> String:
	if idx < 0 or idx >= CombatManager.enemies.size():
		return "敵"
	var enemy: Dictionary = CombatManager.enemies[idx]
	var data: EnemyData = enemy["data"]
	return data.display_name

func _enemy_tooltip_body(idx: int) -> String:
	if idx < 0 or idx >= CombatManager.enemies.size():
		return ""
	var enemy: Dictionary = CombatManager.enemies[idx]
	var data: EnemyData = enemy["data"]
	var lines: Array[String] = []
	lines.append("HP: %d/%d" % [int(enemy.get("hp", 0)), int(enemy.get("max_hp", 0))])
	lines.append("ブロック: %d" % int(enemy.get("block", 0)))
	lines.append("種別: %s" % _enemy_category_name(data.category))
	if not data.weaknesses.is_empty():
		lines.append("弱点: %s" % _tags_to_text(data.weaknesses))
	var intent: Dictionary = enemy.get("intent", {})
	var intent_text := _format_intent_detail(intent)
	if intent_text != "":
		lines.append("次の行動: %s" % intent_text)
	lines.append("")
	lines.append("状態異常")
	var status: Dictionary = enemy.get("status", {})
	lines.append_array(_status_detail_lines(status))
	return "\n".join(lines)

func _enemy_category_name(category: EnemyData.Category) -> String:
	match category:
		EnemyData.Category.BEAST: return "獣"
		EnemyData.Category.HUMAN: return "人間"
		EnemyData.Category.MACHINE: return "機械"
	return "不明"

func _enemy_category_icon(category: EnemyData.Category) -> String:
	match category:
		EnemyData.Category.BEAST: return "BEAST"
		EnemyData.Category.HUMAN: return "HUMAN"
		EnemyData.Category.MACHINE: return "MACHINE"
	return "ENEMY"

func _format_intent_detail(intent: Dictionary) -> String:
	if intent.is_empty():
		return ""
	var intent_type: String = String(intent.get("type", ""))
	var label_text: String = String(intent.get("label", ""))
	match intent_type:
		"attack":
			var value: int = int(intent.get("value", 0))
			var hits: int = int(intent.get("hits", 1))
			return "%s %d×%d" % [label_text, value, hits] if hits > 1 else "%s %d" % [label_text, value]
		"defend":
			return "%s ブロック%d" % [label_text, int(intent.get("value", 0))]
		"attack_defend":
			return "%s 攻撃%d / ブロック%d" % [label_text, int(intent.get("attack", 0)), int(intent.get("block", 0))]
	return label_text

func _on_enemy_hover(idx: int, panel: Control, hovering: bool) -> void:
	if hovering:
		_request_tooltip(_enemy_tooltip_title(idx), _enemy_tooltip_body(idx), panel)
	else:
		_hide_tooltip(panel)

func _update_portrait_state() -> void:
	if not has_node("PlayerHUD/PortraitImage"):
		return
	var state_text := "通常"
	var state_key := "normal"
	var tint := Color(1.0, 1.0, 1.0, 1.0)
	var hp_rate := 1.0
	if CombatManager.player_max_hp > 0:
		hp_rate = float(CombatManager.player_hp) / float(CombatManager.player_max_hp)
	var has_dot: bool = int(CombatManager.player_status.get("burn", 0)) > 0 or int(CombatManager.player_status.get("bleed", 0)) > 0
	var has_debuff: bool = has_dot or int(CombatManager.player_status.get("weak", 0)) > 0 or int(CombatManager.player_status.get("vulnerable", 0)) > 0
	var ultimate_active: bool = int(CombatManager.player_buffs.get("ultimate", 0)) > 0
	if CombatManager.player_hp <= 0:
		state_text = "戦闘不能"
		state_key = "down"
		tint = Color(0.35, 0.35, 0.35, 1.0)
	elif ultimate_active:
		state_text = "アルティメット"
		state_key = "ultimate"
		tint = Color(0.55, 0.95, 1.0, 1.0)
	elif hp_rate <= 0.25:
		state_text = "瀕死"
		state_key = "low_hp"
		tint = Color(1.0, 0.45, 0.38, 1.0)
	elif has_debuff:
		state_text = "異常"
		state_key = "debuffed"
		tint = Color(0.8, 0.55, 0.95, 1.0)
	elif CombatManager.player_block > 0 or int(CombatManager.player_status.get("strength", 0)) > 0:
		state_text = "優勢"
		state_key = "buffed"
		tint = Color(0.75, 1.0, 0.72, 1.0)
	var variant: Texture2D = null
	if GameManager.current_character != null:
		variant = _load_portrait_variant(GameManager.current_character.id, state_key)
	$PlayerHUD/PortraitImage.texture = variant if variant != null else _portrait_default_texture
	$PlayerHUD/PortraitImage.modulate = tint
	$PlayerHUD/PortraitFallbackLabel.modulate = tint
	$PlayerHUD/PortraitStateLabel.text = state_text

# 元レイダー（ヒート＝激情システム）のときだけ、HUDにヒートメーターを生成する。
func _setup_heat_meter() -> void:
	if GameManager.current_character.unique_system != &"heat":
		return
	_heat_label = Label.new()
	_heat_label.offset_left = 235.0
	_heat_label.offset_top = 218.0
	_heat_label.offset_right = 340.0
	_heat_label.offset_bottom = 252.0
	_heat_label.add_theme_font_size_override("font_size", 12)
	_heat_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
	$PlayerHUD.add_child(_heat_label)
	_on_heat_changed(CombatManager.player_heat, CombatManager.HEAT_MAX)

func _setup_aura_meter() -> void:
	if GameManager.current_character.unique_system != &"aura":
		return
	_aura_label = Label.new()
	_aura_label.offset_left = 235.0
	_aura_label.offset_top = 218.0
	_aura_label.offset_right = 340.0
	_aura_label.offset_bottom = 252.0
	_aura_label.add_theme_font_size_override("font_size", 12)
	_aura_label.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
	$PlayerHUD.add_child(_aura_label)
	_on_aura_changed(CombatManager.player_aura, CombatManager.AURA_MAX)

func _setup_investigation_meter() -> void:
	if GameManager.current_character.unique_system != &"investigation":
		return
	_investigation_label = Label.new()
	_investigation_label.offset_left = 235.0
	_investigation_label.offset_top = 218.0
	_investigation_label.offset_right = 360.0
	_investigation_label.offset_bottom = 252.0
	_investigation_label.add_theme_font_size_override("font_size", 12)
	_investigation_label.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	$PlayerHUD.add_child(_investigation_label)
	_on_investigation_changed(CombatManager.player_investigation, CombatManager.INVESTIGATION_MAX)

func _setup_euphoria_meter() -> void:
	if GameManager.current_character.unique_system != &"euphoria":
		return
	_euphoria_label = Label.new()
	_euphoria_label.offset_left = 235.0
	_euphoria_label.offset_top = 218.0
	_euphoria_label.offset_right = 340.0
	_euphoria_label.offset_bottom = 252.0
	_euphoria_label.add_theme_font_size_override("font_size", 12)
	_euphoria_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.8))
	$PlayerHUD.add_child(_euphoria_label)
	_on_euphoria_changed(CombatManager.player_euphoria, CombatManager.EUPHORIA_MAX)

func _setup_beast_display() -> void:
	if GameManager.current_character.unique_system != &"partner":
		return
	_beast_label = Label.new()
	_beast_label.offset_left = 235.0
	_beast_label.offset_top = 218.0
	_beast_label.offset_right = 340.0
	_beast_label.offset_bottom = 252.0
	_beast_label.add_theme_font_size_override("font_size", 12)
	_beast_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.3))
	$PlayerHUD.add_child(_beast_label)
	_on_beast_changed()

func _on_heat_changed(value: int, max_value: int) -> void:
	if _heat_label != null:
		_heat_label.text = "ヒート %d/%d" % [value, max_value]
	_update_portrait_state()
	for btn: Button in [$Controls/EndTurnButton, $Controls/FleeButton, $Controls/RerollButton]:
		btn.focus_mode = Control.FOCUS_NONE
	$Controls/EndTurnButton.text = "ターン終了 (Space)"
	$Controls/EndTurnButton.tooltip_text = "数字キー=カード, Space/Enter=ターン終了, Esc/右クリック=選択解除"

func _on_aura_changed(value: int, max_value: int) -> void:
	if _aura_label != null:
		_aura_label.text = "闘気 %d/%d" % [value, max_value]
	_update_portrait_state()

func _on_investigation_changed(value: int, max_value: int) -> void:
	if _investigation_label != null:
		_investigation_label.text = "調査 %d/%d" % [value, max_value]
	_update_portrait_state()

func _on_euphoria_changed(value: int, max_value: int) -> void:
	if _euphoria_label != null:
		var zone := ""
		if value <= 9:
			zone = "枯渇"
		elif value <= 32:
			zone = "倦怠"
		elif value <= 59:
			zone = "平常"
		elif value <= 74:
			zone = "バズ"
		elif value < 100:
			zone = "高揚"
		else:
			zone = "絶頂"
		_euphoria_label.text = "%s %d/%d" % [zone, value, max_value]
	_update_portrait_state()

func _on_climax_activated() -> void:
	_flash_screen(Color(0.8, 0.2, 0.8, 0.4))
	var msg := Label.new()
	msg.text = "クライマックス！"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.add_theme_font_size_override("font_size", 32)
	msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.9))
	msg.offset_left = -200
	msg.offset_right = 200
	msg.offset_top = -30
	msg.offset_bottom = 30
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(msg, "modulate:a", 0.0, 0.5)
	tw.tween_callback(msg.queue_free)

func _on_beast_changed() -> void:
	if _beast_label == null:
		return
	if CombatManager.player_beasts.is_empty():
		_beast_label.text = "相棒: なし"
		_update_portrait_state()
		return
	var alive_count: int = 0
	var parts: Array[String] = []
	for beast: Dictionary in CombatManager.player_beasts:
		var alive: bool = beast.get("alive", false)
		if alive:
			alive_count += 1
			var name_str: String = String(beast.get("name", "獣"))
			var bhp: int = int(beast.get("hp", 0))
			var bmax: int = int(beast.get("max_hp", 0))
			var turns_alive: int = int(beast.get("turns_alive", 0))
			parts.append("%s(%d/%d:%dt)" % [name_str, bhp, bmax, turns_alive])
	_beast_label.text = "相棒 %d/%d  %s" % [alive_count, CombatManager.get_beast_max_slots(), " ".join(parts)]
	_update_portrait_state()

func _setup_signals() -> void:
	CombatManager.turn_started.connect(_on_turn_started)
	CombatManager.card_played.connect(_on_card_played)
	CombatManager.enemy_defeated.connect(_on_enemy_defeated)
	CombatManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	CombatManager.enemy_block_changed.connect(_on_enemy_block_changed)
	CombatManager.enemy_intent_updated.connect(_on_enemy_intent_updated)
	CombatManager.enemy_status_changed.connect(_on_enemy_status_changed)
	CombatManager.player_status_changed.connect(_on_player_status_changed)
	CombatManager.heat_changed.connect(_on_heat_changed)
	CombatManager.investigation_changed.connect(_on_investigation_changed)
	CombatManager.player_hp_changed.connect(_on_player_hp_changed)
	CombatManager.player_block_changed.connect(_on_player_block_changed)
	CombatManager.ap_changed.connect(_on_ap_changed)
	CombatManager.acceleration_changed.connect(_on_acceleration_changed)
	CombatManager.player_buffs_changed.connect(_on_player_buffs_changed)
	CombatManager.ultimate_activated.connect(_on_ultimate_activated)
	CombatManager.aura_changed.connect(_on_aura_changed)
	CombatManager.euphoria_changed.connect(_on_euphoria_changed)
	CombatManager.climax_activated.connect(_on_climax_activated)
	CombatManager.beast_changed.connect(_on_beast_changed)
	CombatManager.combat_won.connect(_on_combat_won)
	CombatManager.combat_lost.connect(_on_combat_lost)
	CombatManager.player_fled.connect(_on_player_fled)
	DeckManager.cards_drawn.connect(_on_cards_drawn)
	$Controls/EndTurnButton.pressed.connect(_on_end_turn)
	$Controls/FleeButton.pressed.connect(_on_flee)
	$Controls/RerollButton.pressed.connect(_on_reroll)

func _setup_engine_brake_button() -> void:
	if GameManager.current_character.unique_system != &"gear":
		return
	_engine_brake_button = Button.new()
	_engine_brake_button.text = "エンジンブレーキ"
	_engine_brake_button.custom_minimum_size = Vector2(170, 40)
	_engine_brake_button.tooltip_text = "ギア-1、ブロック+3。1ターン1回。"
	_engine_brake_button.focus_mode = Control.FOCUS_NONE
	_engine_brake_button.pressed.connect(_on_engine_brake)
	$Controls.add_child(_engine_brake_button)

func _build_enemy_display() -> void:
	for child in $EnemyArea.get_children():
		child.queue_free()
	enemy_panels.clear()
	target_buttons.clear()
	hp_labels.clear()
	hp_bars.clear()
	block_labels.clear()
	weakness_labels.clear()
	intent_labels.clear()
	status_labels.clear()

	for i in CombatManager.enemies.size():
		var enemy: Dictionary = CombatManager.enemies[i]
		var data: EnemyData = enemy["data"]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(220, 360)
		var style := StyleBoxFlat.new()
		match data.category:
			EnemyData.Category.BEAST:
				style.bg_color = Color(0.20, 0.10, 0.07, 0.82)
			EnemyData.Category.HUMAN:
				style.bg_color = Color(0.14, 0.10, 0.10, 0.82)
			EnemyData.Category.MACHINE:
				style.bg_color = Color(0.09, 0.10, 0.16, 0.82)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = data.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
		name_label.name = "NameLabel"
		vbox.add_child(name_label)

		var visual := _create_enemy_visual(data)
		vbox.add_child(visual)

		var hp_label := Label.new()
		hp_label.name = "HPLabel"
		hp_label.text = "HP: %d/%d" % [enemy["hp"], enemy["max_hp"]]
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.add_theme_font_size_override("font_size", 16)
		hp_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		vbox.add_child(hp_label)

		var hp_bar := ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.max_value = enemy["max_hp"]
		hp_bar.value = enemy["hp"]
		hp_bar.show_percentage = false
		hp_bar.custom_minimum_size = Vector2(0, 14)
		vbox.add_child(hp_bar)

		var weakness_label := Label.new()
		weakness_label.name = "WeaknessLabel"
		weakness_label.text = _format_weakness_label(i)
		weakness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weakness_label.add_theme_font_size_override("font_size", 12)
		weakness_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
		vbox.add_child(weakness_label)

		var block_label := Label.new()
		block_label.name = "BlockLabel"
		block_label.text = ""
		block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		block_label.add_theme_font_size_override("font_size", 15)
		block_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
		vbox.add_child(block_label)

		var intent_label := Label.new()
		intent_label.name = "IntentLabel"
		intent_label.text = ""
		intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intent_label.add_theme_font_size_override("font_size", 15)
		intent_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(intent_label)

		var status_label := Label.new()
		status_label.name = "StatusLabel"
		status_label.text = _format_status(enemy.get("status", {}))
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_label.add_theme_font_size_override("font_size", 14)
		status_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.85))
		vbox.add_child(status_label)

		var target_btn := Button.new()
		target_btn.text = "攻撃対象"
		target_btn.custom_minimum_size = Vector2(0, 34)
		target_btn.add_theme_font_size_override("font_size", 13)
		target_btn.focus_mode = Control.FOCUS_NONE
		target_btn.pressed.connect(_on_enemy_target.bind(i))
		target_btn.name = "TargetButton"
		vbox.add_child(target_btn)

		panel.add_child(vbox)
		panel.gui_input.connect(_on_enemy_panel_clicked.bind(i))
		panel.mouse_entered.connect(_on_enemy_hover.bind(i, panel, true))
		panel.mouse_exited.connect(_on_enemy_hover.bind(i, panel, false))
		panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		$EnemyArea.add_child(panel)
		enemy_panels.append(panel)
		target_buttons.append(target_btn)
		hp_labels.append(hp_label)
		hp_bars.append(hp_bar)
		block_labels.append(block_label)
		weakness_labels.append(weakness_label)
		intent_labels.append(intent_label)
		status_labels.append(status_label)

func _create_enemy_visual(data: EnemyData) -> Control:
	if data.art != null:
		var art_rect := TextureRect.new()
		art_rect.custom_minimum_size = Vector2(200, 190)
		art_rect.texture = data.art
		art_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return art_rect

	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(200, 190)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	match data.category:
		EnemyData.Category.BEAST:
			style.bg_color = Color(0.28, 0.13, 0.08, 0.78)
			style.border_color = Color(0.85, 0.42, 0.22, 0.75)
		EnemyData.Category.HUMAN:
			style.bg_color = Color(0.18, 0.13, 0.12, 0.78)
			style.border_color = Color(0.78, 0.58, 0.42, 0.75)
		EnemyData.Category.MACHINE:
			style.bg_color = Color(0.10, 0.13, 0.20, 0.78)
			style.border_color = Color(0.42, 0.65, 0.9, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	frame.add_theme_stylebox_override("panel", style)

	var icon := Label.new()
	icon.text = _enemy_category_icon(data.category)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 26)
	icon.add_theme_color_override("font_color", Color(0.95, 0.85, 0.65, 0.85))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	return frame

func _update_hand() -> void:
	for child in $HandArea.get_children():
		child.queue_free()
	card_buttons.clear()

	for card: CardData in DeckManager.hand:
		var btn := _create_card_button(card)
		$HandArea.add_child(btn)
		card_buttons.append(btn)

func _tag_name(tag: CardData.Tag) -> String:
	match tag:
		CardData.Tag.MELEE: return "近接"
		CardData.Tag.RANGED: return "射撃"
		CardData.Tag.BIKE: return "バイク"
		CardData.Tag.DEFENSE: return "防御"
		CardData.Tag.SKILL: return "スキル"
		CardData.Tag.CHARACTER: return "固有"
	return ""

func _tags_to_bracket_text(tags: Array[CardData.Tag]) -> String:
	var text := ""
	for tag in tags:
		text += "[%s]" % _tag_name(tag)
	return text

func _tags_to_text(tags: Array[CardData.Tag]) -> String:
	var names: Array[String] = []
	for tag in tags:
		names.append(_tag_name(tag))
	return "・".join(names)

func _create_card_button(card: CardData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 190)

	var can_play := CombatManager.can_play_card(card)
	var effective_cost := CombatManager.get_effective_ap_cost(card)
	var cost_text := "%dAP" % effective_cost
	if effective_cost != card.ap_cost:
		cost_text = "%dAP(-%d)" % [effective_cost, card.ap_cost - effective_cost]
	if card.fuel_cost > 0:
		var fuel_cost: int = CombatManager.get_effective_fuel_cost(card)
		if fuel_cost > 0:
			cost_text += "+%d燃" % fuel_cost

	var transformed: bool = CombatManager.is_heat_card_transformed(card)
	var tag_text: String = "[近接][固有]" if transformed else _tags_to_bracket_text(card.tags)
	var display_name: String = "怒りの一撃" if transformed else card.get_display_name()
	var description: String = "%dダメージ（元: %s）" % [card.get_effective_block(), card.get_display_name()] if transformed else card.description

	btn.text = "%s\n%s\n%s\n%s" % [cost_text, display_name, tag_text, description]
	btn.disabled = not can_play or card.is_unplayable
	btn.pressed.connect(_on_card_selected.bind(card))

	var style := StyleBoxFlat.new()
	if card.is_unplayable:
		style.bg_color = Color(0.3, 0.1, 0.3, 0.9)
	elif transformed:
		style.bg_color = Color(0.42, 0.12, 0.08, 0.9)
	elif can_play:
		match card.rarity:
			CardData.Rarity.COMMON: style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
			CardData.Rarity.UNCOMMON: style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
			CardData.Rarity.RARE: style.bg_color = Color(0.3, 0.25, 0.1, 0.9)
	else:
		style.bg_color = Color(0.15, 0.12, 0.1, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	match card.rarity:
		CardData.Rarity.COMMON: style.border_color = Color(0.4, 0.4, 0.4)
		CardData.Rarity.UNCOMMON: style.border_color = Color(0.3, 0.5, 0.8)
		CardData.Rarity.RARE: style.border_color = Color(0.8, 0.7, 0.2)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 13)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_entered.connect(_on_card_hover.bind(btn, card, true))
	btn.mouse_exited.connect(_on_card_hover.bind(btn, card, false))
	btn.gui_input.connect(_on_card_gui_input.bind(card))
	return btn

func _on_card_gui_input(event: InputEvent, card: CardData) -> void:
	if event is InputEventMouseButton:
		var me := event as InputEventMouseButton
		if me.pressed and me.button_index == MOUSE_BUTTON_RIGHT:
			_show_card_detail(card)

func _show_card_detail(card: CardData) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 350)
	panel.offset_left = -200
	panel.offset_top = -175
	panel.offset_right = 200
	panel.offset_bottom = 175

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_top = 10
	vbox.offset_right = -15
	vbox.offset_bottom = -50
	vbox.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	var rarity_text := ""
	match card.rarity:
		CardData.Rarity.UNCOMMON: rarity_text = " [アンコモン]"
		CardData.Rarity.RARE: rarity_text = " [レア]"
	name_label.text = card.get_display_name() + rarity_text
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(name_label)

	var tag_label := Label.new()
	tag_label.text = _tags_to_bracket_text(card.tags)
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 14)
	tag_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(tag_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var cost_label := Label.new()
	var cost_parts: Array[String] = ["AP: %d" % card.ap_cost]
	var detail_fuel_cost: int = CombatManager.get_effective_fuel_cost(card)
	if detail_fuel_cost > 0:
		cost_parts.append("%sコスト: %d" % [GameManager.get_travel_resource_name(), detail_fuel_cost])
	cost_label.text = " | ".join(cost_parts)
	cost_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cost_label)

	var stats_parts: Array[String] = []
	if card.get_effective_damage() > 0:
		stats_parts.append("ダメージ: %d" % card.get_effective_damage())
	if card.get_effective_block() > 0:
		stats_parts.append("ブロック: %d" % card.get_effective_block())
	if card.draw_count > 0:
		stats_parts.append("ドロー: %d" % card.draw_count)
	if not stats_parts.is_empty():
		var stats_label := Label.new()
		stats_label.text = " | ".join(stats_parts)
		stats_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(stats_label)

	var desc_label := Label.new()
	desc_label.text = card.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(desc_label)

	if card.flavor_text != "":
		var flavor := Label.new()
		flavor.text = card.flavor_text
		flavor.autowrap_mode = TextServer.AUTOWRAP_WORD
		flavor.add_theme_font_size_override("font_size", 13)
		flavor.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		vbox.add_child(flavor)

	panel.add_child(vbox)

	var close_btn := Button.new()
	close_btn.text = "閉じる"
	close_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.custom_minimum_size = Vector2(100, 35)
	close_btn.offset_left = -50
	close_btn.offset_top = -42
	close_btn.offset_right = 50
	close_btn.offset_bottom = -8
	close_btn.pressed.connect(overlay.queue_free)
	panel.add_child(close_btn)

	overlay.add_child(panel)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var me := event as InputEventMouseButton
			if me.pressed:
				overlay.queue_free()
	)

func _on_card_hover(btn: Button, card: CardData, hovering: bool) -> void:
	btn.pivot_offset = Vector2(btn.size.x / 2.0, btn.size.y)
	var tw := btn.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if hovering:
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.08)
		btn.z_index = 1
		_request_tooltip(card.get_display_name(), _card_tooltip_body(card), btn)
	else:
		tw.tween_property(btn, "scale", Vector2.ONE, 0.06)
		btn.z_index = 0
		_hide_tooltip(btn)

func _on_card_selected(card: CardData) -> void:
	if not CombatManager.can_play_card(card):
		return
	var needs_target := (card.base_damage > 0 or card.requires_target or _targets_enemy_status(card) or CombatManager.is_heat_card_transformed(card)) and not card.is_aoe
	if needs_target:
		var alive_idx := _get_sole_alive_enemy()
		if alive_idx >= 0:
			CombatManager.play_card(card, alive_idx)
			_after_card_play()
		else:
			selected_card = card
			_highlight_selected_card(card)
			_show_target_buttons(true)
	else:
		CombatManager.play_card(card, 0)
		_after_card_play()

func _get_sole_alive_enemy() -> int:
	var alive_count: int = 0
	var alive_idx: int = -1
	for i in CombatManager.enemies.size():
		if CombatManager.enemies[i]["alive"]:
			alive_count += 1
			alive_idx = i
			if alive_count > 1:
				return -1
	return alive_idx

func _on_enemy_panel_clicked(event: InputEvent, idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if selected_card == null:
		return
	if selected_card != null and CombatManager.can_target_card(selected_card, idx):
		_on_enemy_target(idx)

func _on_enemy_target(idx: int) -> void:
	if selected_card == null:
		return
	if not CombatManager.can_target_card(selected_card, idx):
		return
	CombatManager.play_card(selected_card, idx)
	selected_card = null
	_show_target_buttons(false)
	_after_card_play()

func _show_target_buttons(visible_flag: bool) -> void:
	for i in target_buttons.size():
		if i >= CombatManager.enemies.size():
			continue
		var alive: bool = CombatManager.enemies[i]["alive"]
		var can_target: bool = alive and (selected_card == null or CombatManager.can_target_card(selected_card, i))
		var show_it: bool = visible_flag and can_target
		target_buttons[i].visible = show_it
		if i < enemy_panels.size():
			if show_it:
				enemy_panels[i].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			else:
				enemy_panels[i].mouse_default_cursor_shape = Control.CURSOR_ARROW
		if show_it and selected_card != null:
			var preview: int = CombatManager.preview_damage(selected_card, i)
			if preview > 0:
				target_buttons[i].text = "攻撃 -%d" % preview
			elif _targets_enemy_status(selected_card):
				target_buttons[i].text = "効果付与"
			else:
				target_buttons[i].text = "対象"
		else:
			target_buttons[i].text = "攻撃対象"

func _cancel_targeting() -> void:
	if selected_card == null:
		return
	selected_card = null
	_show_target_buttons(false)
	_restore_hand_modulate()

func _highlight_selected_card(card: CardData) -> void:
	for i in card_buttons.size():
		if i < DeckManager.hand.size() and DeckManager.hand[i] == card:
			card_buttons[i].modulate = Color.WHITE
		else:
			card_buttons[i].modulate = Color(0.5, 0.5, 0.5, 0.85)

func _restore_hand_modulate() -> void:
	for btn: Button in card_buttons:
		btn.modulate = Color.WHITE

# キーボード/右クリック操作（数字=カード選択、Space/Enter=ターン終了、Esc/右クリック=選択解除）
func _unhandled_input(event: InputEvent) -> void:
	if awaiting_reward:
		return
	if CombatManager.state != CombatManager.CombatState.PLAYER_TURN:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_targeting()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var key := key_event.keycode
		if key == KEY_ESCAPE:
			_cancel_targeting()
		elif key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
			if selected_card == null:
				_on_end_turn()
		elif key >= KEY_1 and key <= KEY_9:
			_select_card_by_index(key - KEY_1)

func _select_card_by_index(idx: int) -> void:
	if selected_card != null:
		return
	if idx < 0 or idx >= DeckManager.hand.size():
		return
	var card: CardData = DeckManager.hand[idx]
	if CombatManager.can_play_card(card):
		_on_card_selected(card)

func _after_card_play() -> void:
	_update_hand()
	_update_player_hud()
	_update_controls()
	if CombatManager.state == CombatManager.CombatState.PLAYER_TURN and not CombatManager.has_playable_card():
		_auto_end_turn()

func _update_player_hud() -> void:
	$PlayerHUD/HPLabel.text = "HP: %d/%d" % [CombatManager.player_hp, CombatManager.player_max_hp]
	$PlayerHUD/HPBar.max_value = CombatManager.player_max_hp
	$PlayerHUD/HPBar.value = CombatManager.player_hp
	if CombatManager.ap < 0:
		$PlayerHUD/APLabel.text = "AP: %d/%d" % [CombatManager.ap, CombatManager.max_ap]
		$PlayerHUD/APLabel.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		$PlayerHUD/APLabel.text = "AP: %d/%d" % [CombatManager.ap, CombatManager.max_ap]
		$PlayerHUD/APLabel.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	$PlayerHUD/BlockLabel.text = "防御: %d" % CombatManager.player_block
	$PlayerHUD/FuelLabel.text = "%s %d/%d" % [GameManager.get_travel_resource_name(), ResourceManager.fuel, ResourceManager.tank_capacity]
	$PlayerHUD/DeckLabel.text = "山 %d / 捨 %d" % [DeckManager.get_deck_count(), DeckManager.get_discard_count()]
	$PlayerHUD/StatusLabel.text = _format_status(CombatManager.player_status)
	_update_gauge_display()
	_update_buff_display()
	_update_portrait_state()

func _update_controls() -> void:
	var in_turn := CombatManager.state == CombatManager.CombatState.PLAYER_TURN
	var is_boss := CombatManager.has_boss_enemy()
	$Controls/EndTurnButton.disabled = not in_turn
	$Controls/FleeButton.disabled = not in_turn or is_boss
	$Controls/RerollButton.disabled = not in_turn or ResourceManager.fuel < 1
	$Controls/FleeButton.text = "逃走不可（ボス）" if is_boss else "逃走 (1%s)" % GameManager.get_travel_resource_name()
	$Controls/RerollButton.text = "リロール (1%s)" % GameManager.get_travel_resource_name()
	if _engine_brake_button != null:
		_engine_brake_button.disabled = not CombatManager.can_engine_brake()

func _update_consumable_buttons() -> void:
	for child in $ItemArea.get_children():
		child.queue_free()
	item_buttons.clear()

	var consumables := ItemDatabase.get_consumables()
	if consumables.is_empty():
		return

	var in_turn := CombatManager.state == CombatManager.CombatState.PLAYER_TURN
	for entry: Dictionary in consumables:
		var item: ItemData = entry["item"]
		var count: int = entry["count"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 40)
		btn.text = "%s ×%d" % [item.display_name, count]
		btn.tooltip_text = item.description
		btn.disabled = not in_turn
		btn.add_theme_font_size_override("font_size", 13)
		btn.focus_mode = Control.FOCUS_NONE

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.2, 0.25, 0.9)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_color = Color(0.3, 0.6, 0.8)
		btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(_on_consumable_pressed.bind(item.id))
		$ItemArea.add_child(btn)
		item_buttons.append(btn)

func _on_consumable_pressed(item_id: StringName) -> void:
	if CombatManager.state != CombatManager.CombatState.PLAYER_TURN:
		return
	var item := ItemDatabase.get_item(item_id)
	if item == null:
		return
	if ItemDatabase.use_consumable(item_id):
		_update_consumable_buttons()
		_update_player_hud()

func _auto_end_turn() -> void:
	var msg := Label.new()
	msg.text = "使用できるカードがありません！"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.add_theme_font_size_override("font_size", 24)
	msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	msg.offset_left = -200
	msg.offset_right = 200
	msg.offset_top = -20
	msg.offset_bottom = 20
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(msg, "modulate:a", 0.0, 0.3)
	tw.tween_callback(msg.queue_free)
	tw.tween_callback(_on_end_turn)

func _on_end_turn() -> void:
	selected_card = null
	_show_target_buttons(false)
	CombatManager.end_player_turn()

func _on_flee() -> void:
	CombatManager.flee()

func _on_reroll() -> void:
	CombatManager.emergency_reroll()
	_update_hand()
	_update_player_hud()
	_update_controls()

func _on_engine_brake() -> void:
	if CombatManager.engine_brake():
		_update_player_hud()
		_update_controls()

func _on_turn_started(_turn: int) -> void:
	_update_hand()
	_update_player_hud()
	_update_controls()
	_update_consumable_buttons()
	if not CombatManager.has_playable_card():
		_auto_end_turn()

func _on_card_played(_card: CardData) -> void:
	pass

func _on_cards_drawn(_cards: Array[CardData]) -> void:
	_update_hand()

func _on_enemy_defeated(idx: int) -> void:
	if idx < enemy_panels.size():
		enemy_panels[idx].modulate = Color(0.3, 0.3, 0.3, 0.5)
	if idx < target_buttons.size():
		target_buttons[idx].visible = false

func _on_enemy_hp_changed(idx: int, hp: int, max_hp: int) -> void:
	if idx < hp_labels.size():
		hp_labels[idx].text = "HP: %d/%d" % [hp, max_hp]
	if idx < hp_bars.size():
		hp_bars[idx].max_value = max_hp
		hp_bars[idx].value = hp
	if idx < enemy_panels.size():
		_pop_node(enemy_panels[idx])
		if _tooltip_pending_source == enemy_panels[idx] and _tooltip_panel != null and _tooltip_panel.visible:
			_request_tooltip(_enemy_tooltip_title(idx), _enemy_tooltip_body(idx), enemy_panels[idx])

func _on_enemy_block_changed(idx: int, block: int) -> void:
	if idx < block_labels.size():
		block_labels[idx].text = "ブロック: %d" % block if block > 0 else ""

func _on_enemy_intent_updated(idx: int, intent: Dictionary) -> void:
	if idx < intent_labels.size():
		_update_enemy_intent_label(idx, intent)

func _on_enemy_status_changed(idx: int, status: Dictionary) -> void:
	if idx < status_labels.size():
		status_labels[idx].text = _format_status(status)
	if idx < weakness_labels.size():
		weakness_labels[idx].text = _format_weakness_label(idx)
	if idx < intent_labels.size():
		var intent: Dictionary = CombatManager.enemies[idx].get("intent", {})
		_update_enemy_intent_label(idx, intent)
	if idx < enemy_panels.size() and _tooltip_pending_source == enemy_panels[idx] and _tooltip_panel != null and _tooltip_panel.visible:
		_request_tooltip(_enemy_tooltip_title(idx), _enemy_tooltip_body(idx), enemy_panels[idx])

func _on_player_status_changed(status: Dictionary) -> void:
	$PlayerHUD/StatusLabel.text = _format_status(status)
	_update_portrait_state()
	if _tooltip_pending_source == $PlayerHUD and _tooltip_panel != null and _tooltip_panel.visible:
		_request_tooltip(_get_player_tooltip_title(), _get_player_tooltip_body(), $PlayerHUD)

func _on_acceleration_changed(_gauge: int, _max_gauge: int) -> void:
	_update_gauge_display()
	_update_controls()

func _on_player_buffs_changed(_buffs: Dictionary) -> void:
	_update_buff_display()
	_update_portrait_state()
	_update_hand()

func _on_ultimate_activated() -> void:
	_flash_screen(Color(0.2, 0.8, 0.9, 0.4))
	var msg := Label.new()
	msg.text = "フルスロットル！"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.add_theme_font_size_override("font_size", 32)
	msg.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
	msg.offset_left = -200
	msg.offset_right = 200
	msg.offset_top = -30
	msg.offset_bottom = 30
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(msg, "modulate:a", 0.0, 0.5)
	tw.tween_callback(msg.queue_free)

func _update_gauge_display() -> void:
	if CombatManager._is_cultist():
		var gear: int = CombatManager.player_gear
		var mx: int = CombatManager.GEAR_MAX
		$PlayerHUD/GaugeLabel.text = "ギア %d/%d" % [gear, mx]
	else:
		$PlayerHUD/GaugeLabel.text = ""

func _update_buff_display() -> void:
	var parts: Array[String] = []
	var buffs: Dictionary = CombatManager.player_buffs
	var ult: int = int(buffs.get("ultimate", 0))
	var oc: int = int(buffs.get("overcharge", 0))
	var mp: int = int(buffs.get("melee_power", 0))
	var rd: int = int(buffs.get("ranged_double", 0))
	var pd: int = int(buffs.get("partner_defense", 0))
	var cg: int = int(buffs.get("companion_guard", 0))
	var hf: int = int(buffs.get("herd_fatigue", 0))
	if ult > 0:
		parts.append("フルスロットル(%dt)" % ult)
	if oc > 0:
		parts.append("過充電(%dt)" % oc)
	if mp > 0:
		parts.append("近+3(%dt)" % mp)
	if rd > 0:
		parts.append("射×2(%d)" % rd)
	if pd > 0:
		parts.append("防御指示")
	if cg > 0:
		parts.append("かばう(%d)" % cg)
	if hf > 0:
		parts.append("群れ疲労")
	$PlayerHUD/BuffLabel.text = " ".join(parts)

func _targets_enemy_status(card: CardData) -> bool:
	if card.status_stacks == 0:
		return false
	if CombatManager._is_player_effect(card.status_effect):
		return false
	if card.status_effect == &"charm":
		return true
	if card.status_effect == &"investigate":
		return true
	return CombatManager._map_status(card.status_effect) != &""

func _update_enemy_intent_label(idx: int, intent: Dictionary) -> void:
	if idx < 0 or idx >= intent_labels.size():
		return
	var label: Label = intent_labels[idx]
	if _uses_investigation_reveal() and not _is_enemy_intent_revealed(idx):
		label.text = "意図: ???"
		label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		return
	var intent_type: String = intent.get("type", "")
	var intent_label_text: String = intent.get("label", "")
	var val: int = intent.get("value", 0)
	var hits: int = intent.get("hits", 1)
	match intent_type:
		"attack":
			if hits > 1:
				label.text = "⚔ %s (%d×%d)" % [intent_label_text, val, hits]
			else:
				label.text = "⚔ %s (%d)" % [intent_label_text, val]
			label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		"defend":
			label.text = "🛡 %s (%d)" % [intent_label_text, val]
			label.add_theme_color_override("font_color", Color(0.3, 0.6, 0.9))
		"attack_defend":
			var atk_val: int = intent.get("attack", 0)
			var blk_val: int = intent.get("block", 0)
			label.text = "⚔🛡 %s (%d/%d)" % [intent_label_text, atk_val, blk_val]
			label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		_:
			label.text = "? %s" % intent_label_text

func _format_weakness_label(idx: int) -> String:
	if idx < 0 or idx >= CombatManager.enemies.size():
		return ""
	var enemy: Dictionary = CombatManager.enemies[idx]
	var data: EnemyData = enemy["data"]
	if data.weaknesses.is_empty():
		return "弱点: なし" if _is_enemy_weakness_revealed(idx) else "弱点: ???"
	if _uses_investigation_reveal() and not _is_enemy_weakness_revealed(idx):
		return "弱点: ???"
	return "弱点: %s" % _tags_to_text(data.weaknesses)

func _uses_investigation_reveal() -> bool:
	return GameManager.current_character != null and GameManager.current_character.unique_system == &"investigation"

func _is_enemy_weakness_revealed(idx: int) -> bool:
	if not _uses_investigation_reveal():
		return true
	return _enemy_investigation_stack(idx) >= 2 or CombatManager._is_missing_link_target(idx)

func _is_enemy_intent_revealed(idx: int) -> bool:
	if not _uses_investigation_reveal():
		return true
	return _enemy_investigation_stack(idx) >= 1 or CombatManager._is_missing_link_target(idx)

func _enemy_investigation_stack(idx: int) -> int:
	if idx < 0 or idx >= CombatManager.enemies.size():
		return 0
	var status: Dictionary = CombatManager.enemies[idx]["status"]
	return int(status.get("investigation", 0))

func _format_status(status: Dictionary) -> String:
	if status.is_empty():
		return ""
	var parts: Array[String] = []
	var burn: int = int(status.get("burn", 0))
	var bleed: int = int(status.get("bleed", 0))
	var weak: int = int(status.get("weak", 0))
	var vuln: int = int(status.get("vulnerable", 0))
	var strg: int = int(status.get("strength", 0))
	var atk_down: int = int(status.get("atk_down", 0))
	var charm: int = int(status.get("charm", 0))
	var investigation: int = int(status.get("investigation", 0))
	var stun: int = int(status.get("stun", 0))
	var guard_break: int = int(status.get("guard_break", 0))
	if burn > 0:
		parts.append("🔥%d" % burn)
	if bleed > 0:
		parts.append("🩸%d" % bleed)
	if weak > 0:
		parts.append("弱%d" % weak)
	if vuln > 0:
		parts.append("脆%d" % vuln)
	if strg > 0:
		parts.append("力%d" % strg)
	if atk_down > 0:
		parts.append("攻-%d" % atk_down)
	if charm > 0:
		parts.append("💘%d" % charm)
	if investigation > 0:
		parts.append("調%d" % investigation)
	if stun > 0:
		parts.append("止%d" % stun)
	if guard_break > 0:
		parts.append("砕%d" % guard_break)
	return " ".join(parts)

func _on_player_hp_changed(hp: int, max_hp: int) -> void:
	$PlayerHUD/HPLabel.text = "HP: %d/%d" % [hp, max_hp]
	$PlayerHUD/HPBar.max_value = max_hp
	$PlayerHUD/HPBar.value = hp
	_update_portrait_state()
	if _tooltip_pending_source == $PlayerHUD and _tooltip_panel != null and _tooltip_panel.visible:
		_request_tooltip(_get_player_tooltip_title(), _get_player_tooltip_body(), $PlayerHUD)
	if hp < _last_player_hp:
		_flash_screen(Color(0.8, 0.1, 0.1, 0.35))
	_last_player_hp = hp

# 被弾時の画面赤フラッシュ（手触り）
func _flash_screen(color: Color) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.3)
	tw.tween_callback(rect.queue_free)

# ノードを一瞬拡大して戻す（ヒットの手応え）
func _pop_node(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.06)
	tw.tween_property(node, "scale", Vector2.ONE, 0.10)

func _on_player_block_changed(block: int) -> void:
	$PlayerHUD/BlockLabel.text = "防御: %d" % block
	_update_portrait_state()

func _on_ap_changed(new_ap: int) -> void:
	if new_ap < 0:
		$PlayerHUD/APLabel.text = "AP: %d/%d" % [new_ap, CombatManager.max_ap]
		$PlayerHUD/APLabel.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		$PlayerHUD/APLabel.text = "AP: %d/%d" % [new_ap, CombatManager.max_ap]
		$PlayerHUD/APLabel.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	_update_portrait_state()
	_update_hand()
	_update_controls()

func _on_combat_won(rewards: Array) -> void:
	if CombatManager.has_boss_enemy():
		GameManager.boss_cleared = true
	_show_reward_screen(rewards)

func _on_combat_lost() -> void:
	GameManager.pending_result = &"defeat"
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main/game_over.tscn")

func _on_player_fled() -> void:
	_return_to_map()

func _show_reward_screen(rewards: Array) -> void:
	for child in $HandArea.get_children():
		child.queue_free()
	_update_controls()

	var reward_panel := PanelContainer.new()
	reward_panel.name = "RewardPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	reward_panel.add_theme_stylebox_override("panel", style)
	reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	reward_panel.custom_minimum_size = Vector2(700, 400)
	reward_panel.offset_left = -350
	reward_panel.offset_top = -200
	reward_panel.offset_right = 350
	reward_panel.offset_bottom = 200

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)

	var title_label := Label.new()
	title_label.text = "勝利！"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	vbox.add_child(title_label)

	var card_label := Label.new()
	card_label.text = "報酬を1つ選択（スキップ可）:"
	card_label.add_theme_font_size_override("font_size", 16)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(card_label)

	var choice_hbox := HBoxContainer.new()
	choice_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_hbox.add_theme_constant_override("separation", 10)

	var pool := CardDatabase.get_reward_pool(GameManager.current_act, GameManager.current_character.id)
	pool.shuffle()
	var pool_idx := 0
	for reward: Dictionary in rewards:
		match reward.get("type", "card"):
			"fuel":
				var amount: int = reward.get("amount", 0)
				var fuel_btn := _create_fuel_reward_button(amount)
				fuel_btn.pressed.connect(_on_reward_fuel_picked.bind(amount))
				choice_hbox.add_child(fuel_btn)
			"scrap":
				var amount: int = reward.get("amount", 0)
				var scrap_btn := _create_scrap_reward_button(amount)
				scrap_btn.pressed.connect(_on_reward_scrap_picked.bind(amount))
				choice_hbox.add_child(scrap_btn)
			"relic", "consumable":
				var item_id: StringName = reward.get("item_id", &"")
				var item := ItemDatabase.get_item(item_id)
				if item != null:
					var item_btn := _create_item_reward_button(item)
					item_btn.pressed.connect(_on_reward_item_picked.bind(item))
					choice_hbox.add_child(item_btn)
			_:
				if pool_idx < pool.size():
					var card: CardData = pool[pool_idx]
					pool_idx += 1
					var btn := _create_card_button(card)
					btn.disabled = false
					btn.pressed.connect(_on_reward_card_picked.bind(card))
					choice_hbox.add_child(btn)
	vbox.add_child(choice_hbox)

	var skip_btn := Button.new()
	skip_btn.text = "スキップ"
	skip_btn.custom_minimum_size = Vector2(200, 40)
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_return_to_map)
	vbox.add_child(skip_btn)

	reward_panel.add_child(vbox)
	add_child(reward_panel)
	awaiting_reward = true

func _create_fuel_reward_button(amount: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 190)
	btn.text = "%s\n+%d" % [GameManager.get_travel_resource_name(), amount]
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.25, 0.15, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.3, 0.6, 0.4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _on_reward_fuel_picked(amount: int) -> void:
	ResourceManager.add_fuel(amount)
	_return_to_map()

func _create_scrap_reward_button(amount: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 190)
	btn.text = "スクラップ\n+%d" % amount
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.5, 0.5, 0.6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 16)
	return btn

func _on_reward_scrap_picked(amount: int) -> void:
	ResourceManager.add_scrap(amount)
	_return_to_map()

func _create_item_reward_button(item: ItemData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 190)
	var type_str := "遺物" if item.item_type == ItemData.ItemType.RELIC else "消耗品"
	btn.text = "[%s]\n%s\n%s" % [type_str, item.display_name, item.description]
	var style := StyleBoxFlat.new()
	if item.item_type == ItemData.ItemType.RELIC:
		style.bg_color = Color(0.25, 0.18, 0.08, 0.9)
		style.border_color = Color(0.8, 0.6, 0.2)
	else:
		style.bg_color = Color(0.1, 0.2, 0.25, 0.9)
		style.border_color = Color(0.3, 0.6, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _on_reward_item_picked(item: ItemData) -> void:
	ItemDatabase.add_to_inventory(item.id)
	_return_to_map()

func _on_reward_card_picked(card: CardData) -> void:
	DeckManager.add_card_to_deck(card)
	_return_to_map()

func _return_to_map() -> void:
	CombatManager.state = CombatManager.CombatState.INACTIVE
	get_tree().change_scene_to_file("res://scenes/map/map_screen.tscn")
