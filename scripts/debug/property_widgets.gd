class_name PropertyWidgets extends RefCounted

const LONG_TEXT_PROPERTIES: PackedStringArray = [
	"description", "body_text", "result_text", "upgrade_description",
	"passive_description", "risk_description", "departure_reward_description",
]

const EXCLUDED_PROPERTIES: PackedStringArray = [
	"resource_local_to_scene", "resource_path", "resource_name", "script",
]


static func is_editable_property(prop: Dictionary) -> bool:
	var prop_name: String = prop["name"]
	if prop_name in EXCLUDED_PROPERTIES:
		return false
	var usage: int = prop["usage"]
	return (usage & PROPERTY_USAGE_STORAGE) != 0 and (usage & PROPERTY_USAGE_EDITOR) != 0


static func create_property_row(prop: Dictionary, resource: Resource, on_changed: Callable) -> Control:
	var prop_name: String = prop["name"]
	var prop_type: int = prop["type"]
	var hint: int = prop.get("hint", 0)
	var hint_string: String = prop.get("hint_string", "")

	if prop_type == TYPE_STRING and prop_name in LONG_TEXT_PROPERTIES:
		return _create_long_text_row(prop_name, resource, on_changed)

	if prop_type == TYPE_ARRAY:
		return _create_array_row(prop_name, resource, hint, hint_string, on_changed)

	if prop_type == TYPE_DICTIONARY:
		return _create_dictionary_row(prop_name, resource, on_changed)

	if prop_type == TYPE_OBJECT:
		if hint_string.contains("Texture2D") or hint_string.contains("Texture"):
			return _create_texture_row(prop_name, resource, on_changed)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = prop_name
	label.custom_minimum_size.x = 180
	row.add_child(label)

	var widget: Control = _create_widget_for_type(prop_name, prop_type, hint, hint_string, resource, on_changed)
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(widget)

	return row


static func _create_widget_for_type(prop_name: String, prop_type: int, hint: int, hint_string: String, resource: Resource, on_changed: Callable) -> Control:
	match prop_type:
		TYPE_BOOL:
			return _create_bool_widget(prop_name, resource, on_changed)
		TYPE_INT:
			if hint == PROPERTY_HINT_ENUM:
				return _create_enum_widget(prop_name, hint_string, resource, on_changed)
			return _create_int_widget(prop_name, hint_string, resource, on_changed)
		TYPE_FLOAT:
			return _create_float_widget(prop_name, resource, on_changed)
		TYPE_STRING:
			return _create_line_edit_widget(prop_name, resource, on_changed)
		TYPE_STRING_NAME:
			return _create_string_name_widget(prop_name, resource, on_changed)
		TYPE_OBJECT:
			return _create_unsupported_label("Object: " + hint_string)
		_:
			return _create_unsupported_label("TYPE_%d" % prop_type)


# --- Bool ---

static func _create_bool_widget(prop_name: String, resource: Resource, on_changed: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.button_pressed = resource.get(prop_name)
	cb.toggled.connect(func(value: bool) -> void:
		resource.set(prop_name, value)
		on_changed.call()
	)
	return cb


# --- Int ---

static func _create_int_widget(prop_name: String, hint_string: String, resource: Resource, on_changed: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = -9999
	sb.max_value = 9999
	sb.step = 1
	if not hint_string.is_empty() and hint_string.contains(","):
		var parts: PackedStringArray = hint_string.split(",")
		if parts.size() >= 2:
			sb.min_value = parts[0].to_float()
			sb.max_value = parts[1].to_float()
	sb.value = resource.get(prop_name)
	sb.value_changed.connect(func(value: float) -> void:
		resource.set(prop_name, int(value))
		on_changed.call()
	)
	return sb


# --- Float ---

static func _create_float_widget(prop_name: String, resource: Resource, on_changed: Callable) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = -9999.0
	sb.max_value = 9999.0
	sb.step = 0.01
	sb.value = resource.get(prop_name)
	sb.value_changed.connect(func(value: float) -> void:
		resource.set(prop_name, value)
		on_changed.call()
	)
	return sb


# --- Enum (OptionButton) ---

static func _create_enum_widget(prop_name: String, hint_string: String, resource: Resource, on_changed: Callable) -> OptionButton:
	var ob := OptionButton.new()
	var entries: PackedStringArray = hint_string.split(",")
	for entry: String in entries:
		var parts: PackedStringArray = entry.split(":")
		var label_text: String = parts[0].strip_edges()
		var value: int = parts[1].strip_edges().to_int() if parts.size() > 1 else ob.item_count
		ob.add_item(label_text, value)

	var current_value: int = resource.get(prop_name)
	for i: int in range(ob.item_count):
		if ob.get_item_id(i) == current_value:
			ob.selected = i
			break

	ob.item_selected.connect(func(index: int) -> void:
		resource.set(prop_name, ob.get_item_id(index))
		on_changed.call()
	)
	return ob


# --- String (LineEdit) ---

static func _create_line_edit_widget(prop_name: String, resource: Resource, on_changed: Callable) -> LineEdit:
	var le := LineEdit.new()
	var value: Variant = resource.get(prop_name)
	le.text = str(value) if value != null else ""
	le.text_changed.connect(func(new_text: String) -> void:
		resource.set(prop_name, new_text)
		on_changed.call()
	)
	return le


# --- StringName (LineEdit) ---

static func _create_string_name_widget(prop_name: String, resource: Resource, on_changed: Callable) -> LineEdit:
	var le := LineEdit.new()
	var value: Variant = resource.get(prop_name)
	le.text = str(value) if value != null else ""
	le.text_changed.connect(func(new_text: String) -> void:
		resource.set(prop_name, StringName(new_text))
		on_changed.call()
	)
	return le


# --- Long text (TextEdit) ---

static func _create_long_text_row(prop_name: String, resource: Resource, on_changed: Callable) -> VBoxContainer:
	var vbox := VBoxContainer.new()

	var label := Label.new()
	label.text = prop_name
	vbox.add_child(label)

	var te := TextEdit.new()
	te.custom_minimum_size.y = 80
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value: Variant = resource.get(prop_name)
	te.text = str(value) if value != null else ""
	te.text_changed.connect(func() -> void:
		resource.set(prop_name, te.text)
		on_changed.call()
	)
	vbox.add_child(te)

	return vbox


# --- Array ---

static func _create_array_row(prop_name: String, resource: Resource, hint: int, hint_string: String, on_changed: Callable) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = prop_name
	vbox.add_child(header)

	var elem_info: Dictionary = _parse_array_hint(hint_string)
	var elem_type: int = elem_info.get("type", TYPE_NIL)
	var elem_hint: int = elem_info.get("hint", PROPERTY_HINT_NONE)
	var elem_hint_string: String = elem_info.get("hint_string", "")

	if elem_type == TYPE_INT and elem_hint == PROPERTY_HINT_ENUM:
		var checkbox_container: HFlowContainer = _create_enum_array_widget(prop_name, elem_hint_string, resource, on_changed)
		vbox.add_child(checkbox_container)
		return vbox

	if elem_type == TYPE_OBJECT and elem_hint == PROPERTY_HINT_RESOURCE_TYPE:
		_build_subresource_array_ui(vbox, prop_name, elem_hint_string, resource, on_changed)
		return vbox

	_build_simple_array_ui(vbox, prop_name, elem_type, resource, on_changed)
	return vbox


static func _parse_array_hint(hint_string: String) -> Dictionary:
	var result: Dictionary = {"type": TYPE_NIL, "hint": PROPERTY_HINT_NONE, "hint_string": ""}
	if hint_string.is_empty():
		return result

	var slash_pos: int = hint_string.find("/")
	var colon_pos: int = hint_string.find(":")

	if slash_pos >= 0:
		result["type"] = hint_string.substr(0, slash_pos).to_int()
		if colon_pos >= 0 and colon_pos > slash_pos:
			result["hint"] = hint_string.substr(slash_pos + 1, colon_pos - slash_pos - 1).to_int()
			result["hint_string"] = hint_string.substr(colon_pos + 1)
		else:
			result["hint"] = hint_string.substr(slash_pos + 1).to_int()
	elif colon_pos >= 0:
		result["type"] = hint_string.substr(0, colon_pos).to_int()
		result["hint_string"] = hint_string.substr(colon_pos + 1)
	else:
		result["type"] = hint_string.to_int()

	return result


# --- Array[Enum] → CheckBox group ---

static func _create_enum_array_widget(prop_name: String, enum_hint: String, resource: Resource, on_changed: Callable) -> HFlowContainer:
	var container := HFlowContainer.new()
	container.add_theme_constant_override("h_separation", 12)

	var entries: PackedStringArray = enum_hint.split(",")
	var current_array: Array = resource.get(prop_name)

	for i: int in range(entries.size()):
		var entry: String = entries[i].strip_edges()
		var entry_parts: PackedStringArray = entry.split(":")
		var entry_name: String = entry_parts[0]
		var entry_value: int = entry_parts[1].to_int() if entry_parts.size() > 1 else i

		var cb := CheckBox.new()
		cb.text = entry_name
		cb.button_pressed = entry_value in current_array
		cb.set_meta("enum_value", entry_value)

		cb.toggled.connect(func(_pressed: bool) -> void:
			var arr: Array = resource.get(prop_name)
			arr.clear()
			for child: Node in container.get_children():
				if child is CheckBox:
					var child_cb: CheckBox = child as CheckBox
					if child_cb.button_pressed:
						arr.append(child_cb.get_meta("enum_value"))
			on_changed.call()
		)
		container.add_child(cb)

	return container


# --- Array[SubResource] ---

static func _build_subresource_array_ui(parent: VBoxContainer, prop_name: String, res_class: String, resource: Resource, on_changed: Callable) -> void:
	var items_container := VBoxContainer.new()
	items_container.add_theme_constant_override("separation", 8)
	parent.add_child(items_container)

	var add_btn := Button.new()
	add_btn.text = "+ 追加"
	add_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(add_btn)

	_rebuild_subresource_items(items_container, prop_name, res_class, resource, on_changed)

	add_btn.pressed.connect(func() -> void:
		var arr: Array = resource.get(prop_name)
		var new_item: Resource = _create_resource_instance(res_class)
		if new_item != null:
			arr.append(new_item)
			_rebuild_subresource_items(items_container, prop_name, res_class, resource, on_changed)
			on_changed.call()
	)


static func _rebuild_subresource_items(container: VBoxContainer, prop_name: String, res_class: String, resource: Resource, on_changed: Callable) -> void:
	for child: Node in container.get_children():
		child.queue_free()

	var arr: Array = resource.get(prop_name)
	for i: int in range(arr.size()):
		var item: Resource = arr[i] as Resource
		if item == null:
			continue

		var item_panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.22, 1.0)
		style.set_content_margin_all(8)
		style.set_corner_radius_all(4)
		item_panel.add_theme_stylebox_override("panel", style)

		var item_vbox := VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 4)
		item_panel.add_child(item_vbox)

		var item_header := HBoxContainer.new()
		var index_label := Label.new()
		index_label.text = "[%d] %s" % [i, res_class]
		index_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_header.add_child(index_label)

		var delete_btn := Button.new()
		delete_btn.text = "×"
		delete_btn.custom_minimum_size = Vector2(30, 0)
		var captured_i: int = i
		delete_btn.pressed.connect(func() -> void:
			var current_arr: Array = resource.get(prop_name)
			current_arr.remove_at(captured_i)
			_rebuild_subresource_items(container, prop_name, res_class, resource, on_changed)
			on_changed.call()
		)
		item_header.add_child(delete_btn)
		item_vbox.add_child(item_header)

		for prop: Dictionary in item.get_property_list():
			if is_editable_property(prop):
				var row: Control = create_property_row(prop, item, on_changed)
				item_vbox.add_child(row)

		container.add_child(item_panel)


# --- Array[Simple] (StringName, int, etc.) ---

static func _build_simple_array_ui(parent: VBoxContainer, prop_name: String, elem_type: int, resource: Resource, on_changed: Callable) -> void:
	var items_container := VBoxContainer.new()
	parent.add_child(items_container)

	var add_btn := Button.new()
	add_btn.text = "+ 追加"
	add_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(add_btn)

	_rebuild_simple_array_items(items_container, prop_name, elem_type, resource, on_changed)

	add_btn.pressed.connect(func() -> void:
		var arr: Array = resource.get(prop_name)
		match elem_type:
			TYPE_STRING_NAME:
				arr.append(&"")
			TYPE_STRING:
				arr.append("")
			TYPE_INT:
				arr.append(0)
			TYPE_FLOAT:
				arr.append(0.0)
			_:
				arr.append("")
		_rebuild_simple_array_items(items_container, prop_name, elem_type, resource, on_changed)
		on_changed.call()
	)


static func _rebuild_simple_array_items(container: VBoxContainer, prop_name: String, elem_type: int, resource: Resource, on_changed: Callable) -> void:
	for child: Node in container.get_children():
		child.queue_free()

	var arr: Array = resource.get(prop_name)
	for i: int in range(arr.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var index_label := Label.new()
		index_label.text = "[%d]" % i
		index_label.custom_minimum_size.x = 40
		row.add_child(index_label)

		var captured_i: int = i
		var widget: Control = _create_simple_array_element_widget(arr, captured_i, elem_type, on_changed)
		widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(widget)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(30, 0)
		del_btn.pressed.connect(func() -> void:
			var current_arr: Array = resource.get(prop_name)
			current_arr.remove_at(captured_i)
			_rebuild_simple_array_items(container, prop_name, elem_type, resource, on_changed)
			on_changed.call()
		)
		row.add_child(del_btn)
		container.add_child(row)


static func _create_simple_array_element_widget(arr: Array, index: int, elem_type: int, on_changed: Callable) -> Control:
	match elem_type:
		TYPE_STRING_NAME:
			var le := LineEdit.new()
			le.text = str(arr[index])
			le.text_changed.connect(func(new_text: String) -> void:
				arr[index] = StringName(new_text)
				on_changed.call()
			)
			return le
		TYPE_STRING:
			var le := LineEdit.new()
			le.text = str(arr[index])
			le.text_changed.connect(func(new_text: String) -> void:
				arr[index] = new_text
				on_changed.call()
			)
			return le
		TYPE_INT:
			var sb := SpinBox.new()
			sb.min_value = -9999
			sb.max_value = 9999
			sb.value = arr[index]
			sb.value_changed.connect(func(value: float) -> void:
				arr[index] = int(value)
				on_changed.call()
			)
			return sb
		_:
			var le := LineEdit.new()
			le.text = str(arr[index])
			le.editable = false
			return le


# --- Dictionary ---

static func _create_dictionary_row(prop_name: String, resource: Resource, on_changed: Callable) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = prop_name
	vbox.add_child(label)

	var items_container := VBoxContainer.new()
	vbox.add_child(items_container)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	var type_selector := OptionButton.new()
	type_selector.add_item("int", 0)
	type_selector.add_item("float", 1)
	type_selector.add_item("String", 2)
	add_row.add_child(type_selector)

	var add_btn := Button.new()
	add_btn.text = "+ エントリ追加"
	add_row.add_child(add_btn)
	vbox.add_child(add_row)

	_rebuild_dictionary_items(items_container, prop_name, resource, on_changed)

	add_btn.pressed.connect(func() -> void:
		var dict: Dictionary = resource.get(prop_name)
		var new_key: String = "key_%d" % dict.size()
		match type_selector.selected:
			0:
				dict[new_key] = 0
			1:
				dict[new_key] = 0.0
			2:
				dict[new_key] = ""
		_rebuild_dictionary_items(items_container, prop_name, resource, on_changed)
		on_changed.call()
	)

	return vbox


static func _rebuild_dictionary_items(container: VBoxContainer, prop_name: String, resource: Resource, on_changed: Callable) -> void:
	for child: Node in container.get_children():
		child.queue_free()

	var dict: Dictionary = resource.get(prop_name)

	for key: Variant in dict.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var captured_key: Variant = key

		var key_edit := LineEdit.new()
		key_edit.custom_minimum_size.x = 120
		key_edit.text = str(key)
		key_edit.text_submitted.connect(func(new_key: String) -> void:
			if new_key == str(captured_key) or new_key.is_empty():
				return
			var d: Dictionary = resource.get(prop_name)
			var val: Variant = d.get(captured_key)
			d.erase(captured_key)
			d[new_key] = val
			_rebuild_dictionary_items(container, prop_name, resource, on_changed)
			on_changed.call()
		)
		row.add_child(key_edit)

		var value: Variant = dict[key]
		var value_widget: Control = _create_dict_value_widget(dict, captured_key, value, on_changed)
		value_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value_widget)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(30, 0)
		del_btn.pressed.connect(func() -> void:
			var d: Dictionary = resource.get(prop_name)
			d.erase(captured_key)
			_rebuild_dictionary_items(container, prop_name, resource, on_changed)
			on_changed.call()
		)
		row.add_child(del_btn)

		container.add_child(row)


static func _create_dict_value_widget(dict: Dictionary, key: Variant, value: Variant, on_changed: Callable) -> Control:
	var value_type: int = typeof(value)
	match value_type:
		TYPE_INT:
			var sb := SpinBox.new()
			sb.min_value = -9999
			sb.max_value = 9999
			sb.value = value
			sb.value_changed.connect(func(v: float) -> void:
				dict[key] = int(v)
				on_changed.call()
			)
			return sb
		TYPE_FLOAT:
			var sb := SpinBox.new()
			sb.min_value = -9999.0
			sb.max_value = 9999.0
			sb.step = 0.01
			sb.value = value
			sb.value_changed.connect(func(v: float) -> void:
				dict[key] = v
				on_changed.call()
			)
			return sb
		_:
			var le := LineEdit.new()
			le.text = str(value)
			le.text_changed.connect(func(new_text: String) -> void:
				dict[key] = new_text
				on_changed.call()
			)
			return le


# --- Texture2D ---

static func _create_texture_row(prop_name: String, resource: Resource, on_changed: Callable) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var label := Label.new()
	label.text = prop_name
	vbox.add_child(label)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)

	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(128, 128)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var current_tex: Variant = resource.get(prop_name)
	if current_tex is Texture2D:
		preview.texture = current_tex
	preview_row.add_child(preview)

	var btn_col := VBoxContainer.new()
	btn_col.add_theme_constant_override("separation", 4)

	var path_label := Label.new()
	if current_tex is Texture2D and current_tex.resource_path != "":
		path_label.text = current_tex.resource_path
	else:
		path_label.text = "(なし)"
	path_label.add_theme_font_size_override("font_size", 12)
	btn_col.add_child(path_label)

	var change_btn := Button.new()
	change_btn.text = "変更..."
	change_btn.pressed.connect(func() -> void:
		var fd := FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.access = FileDialog.ACCESS_RESOURCES
		fd.filters = PackedStringArray(["*.png, *.jpg, *.svg, *.webp ; Images"])
		fd.size = Vector2i(600, 400)
		fd.file_selected.connect(func(path: String) -> void:
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				resource.set(prop_name, tex)
				preview.texture = tex
				path_label.text = path
				on_changed.call()
			fd.queue_free()
		)
		fd.canceled.connect(fd.queue_free)
		vbox.get_tree().root.add_child(fd)
		fd.popup_centered()
	)
	btn_col.add_child(change_btn)

	var clear_btn := Button.new()
	clear_btn.text = "クリア"
	clear_btn.pressed.connect(func() -> void:
		resource.set(prop_name, null)
		preview.texture = null
		path_label.text = "(なし)"
		on_changed.call()
	)
	btn_col.add_child(clear_btn)

	preview_row.add_child(btn_col)
	vbox.add_child(preview_row)

	return vbox


# --- Unsupported ---

static func _create_unsupported_label(type_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "未対応の型: " + type_text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	return lbl


# --- Resource factory ---

static func _create_resource_instance(res_class_name: String) -> Resource:
	match res_class_name:
		"EventChoiceData":
			return EventChoiceData.new()
		"CardData":
			return CardData.new()
		"EnemyData":
			return EnemyData.new()
		"EventData":
			return EventData.new()
		"BikePartData":
			return BikePartData.new()
		"CharacterData":
			return CharacterData.new()
		"CompanionData":
			return CompanionData.new()
		"ItemData":
			return ItemData.new()
	return null
