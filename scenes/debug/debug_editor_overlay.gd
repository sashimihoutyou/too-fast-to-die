extends CanvasLayer

var _browser: DebugResourceBrowser
var _editor: DebugPropertyEditor

var _background: ColorRect
var _search_bar: LineEdit
var _browser_tree: Tree
var _header_label: Label
var _dirty_label: Label
var _property_list: VBoxContainer
var _property_scroll: ScrollContainer
var _status_bar: Label
var _toast_label: Label


func _ready() -> void:
	_build_ui()
	_browser = DebugResourceBrowser.new()
	_browser.setup(_browser_tree, _search_bar)
	_browser.resource_selected.connect(_on_resource_selected)
	_editor = DebugPropertyEditor.new()
	_editor.setup(_header_label, _dirty_label, _property_list, _property_scroll)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE:
				_on_close_pressed()
				get_viewport().set_input_as_handled()


# --- UI Construction ---

func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = Color(0, 0, 0, 0.6)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_background.add_child(margin)

	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	margin.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)

	_build_toolbar(main_vbox)
	_build_main_content(main_vbox)
	_build_status_bar(main_vbox)
	_build_toast(main_vbox)


func _build_toolbar(parent: VBoxContainer) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	var new_btn := Button.new()
	new_btn.text = "新規作成"
	new_btn.pressed.connect(_on_new_pressed)
	toolbar.add_child(new_btn)

	var dup_btn := Button.new()
	dup_btn.text = "複製"
	dup_btn.pressed.connect(_on_duplicate_pressed)
	toolbar.add_child(dup_btn)

	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_btn)

	var del_btn := Button.new()
	del_btn.text = "削除"
	del_btn.pressed.connect(_on_delete_pressed)
	toolbar.add_child(del_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "× 閉じる"
	close_btn.pressed.connect(_on_close_pressed)
	toolbar.add_child(close_btn)

	parent.add_child(toolbar)


func _build_main_content(parent: VBoxContainer) -> void:
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280

	# Left panel: browser
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 250
	left.add_theme_constant_override("separation", 4)

	_search_bar = LineEdit.new()
	_search_bar.placeholder_text = "検索..."
	left.add_child(_search_bar)

	_browser_tree = Tree.new()
	_browser_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_browser_tree.hide_root = false
	_browser_tree.allow_reselect = true
	left.add_child(_browser_tree)

	split.add_child(left)

	# Right panel: property editor
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)

	var header_row := HBoxContainer.new()
	_header_label = Label.new()
	_header_label.text = "リソースを選択してください"
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", 16)
	header_row.add_child(_header_label)

	_dirty_label = Label.new()
	_dirty_label.text = ""
	_dirty_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_dirty_label.add_theme_font_size_override("font_size", 14)
	header_row.add_child(_dirty_label)

	right.add_child(header_row)

	var separator := HSeparator.new()
	right.add_child(separator)

	_property_scroll = ScrollContainer.new()
	_property_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_property_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_property_list = VBoxContainer.new()
	_property_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_list.add_theme_constant_override("separation", 6)
	_property_scroll.add_child(_property_list)

	right.add_child(_property_scroll)
	split.add_child(right)

	parent.add_child(split)


func _build_status_bar(parent: VBoxContainer) -> void:
	var separator := HSeparator.new()
	parent.add_child(separator)

	_status_bar = Label.new()
	_status_bar.text = "準備完了"
	_status_bar.add_theme_font_size_override("font_size", 12)
	_status_bar.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	parent.add_child(_status_bar)


func _build_toast(parent: VBoxContainer) -> void:
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_toast_label.visible = false
	parent.add_child(_toast_label)


# --- Event handlers ---

func _on_resource_selected(path: String) -> void:
	if _editor.is_dirty():
		_show_unsaved_dialog_then(func() -> void:
			_editor.edit_resource(path)
			_update_status(path)
		)
		return
	_editor.edit_resource(path)
	_update_status(path)


func _on_save_pressed() -> void:
	var error: String = _editor.validate()
	if not error.is_empty():
		_show_message("バリデーションエラー", error)
		return

	var resource: Resource = _editor.get_current_resource()
	var path: String = _editor.get_current_path()

	if path.is_empty() or not path.ends_with(".tres"):
		_show_save_path_dialog()
		return

	_show_confirm("保存確認", "%s に保存しますか？" % path, func() -> void:
		_do_save(resource, path)
	)


func _on_new_pressed() -> void:
	_show_new_resource_dialog()


func _on_duplicate_pressed() -> void:
	var res: Resource = _editor.get_current_resource()
	if res == null:
		_show_message("エラー", "リソースが選択されていません")
		return

	var copy: Resource = res.duplicate(true)
	if "id" in copy:
		var original_id: String = str(copy.get("id"))
		copy.set("id", StringName(original_id + "_copy"))

	var base_dir: String = _editor.get_current_path().get_base_dir()
	var new_id: String = str(copy.get("id")) if "id" in copy else "new_resource"
	var new_path: String = base_dir.path_join(new_id + ".tres")

	_editor.edit_new_resource(copy, new_path)
	_update_status(new_path)


func _on_delete_pressed() -> void:
	var path: String = _editor.get_current_path()
	if path.is_empty():
		_show_message("エラー", "リソースが選択されていません")
		return

	_show_confirm("削除確認", "%s を削除しますか？この操作は元に戻せません。" % path.get_file(), func() -> void:
		var err: Error = DirAccess.remove_absolute(path)
		if err != OK:
			_show_message("削除失敗", "ファイルの削除に失敗しました: %s" % error_string(err))
			return
		DebugResourceHotReload.reload_for_path(path)
		_editor.clear()
		_browser.build_tree()
		_update_status("削除完了: " + path.get_file())
	)


func _on_close_pressed() -> void:
	request_close()


func request_close() -> void:
	if _editor.is_dirty():
		_show_unsaved_dialog_then(func() -> void:
			DebugEditorManager.force_close()
		)
		return
	DebugEditorManager.force_close()


# --- Save logic ---

func _do_save_and_return(resource: Resource, path: String) -> Error:
	var dir_path: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err: Error = ResourceSaver.save(resource, path)
	if err != OK:
		_show_message("保存失敗", "保存に失敗しました: %s" % error_string(err))
		return err

	_editor.set_current_path(path)
	_editor.mark_clean()
	_update_status("保存完了: " + path)

	DebugResourceHotReload.reload_for_path(path)
	_browser.build_tree()

	if DebugResourceHotReload.is_combat_active():
		_show_toast("戦闘中の変更は次回の戦闘から反映されます")
	return OK


func _do_save(resource: Resource, path: String) -> void:
	_do_save_and_return(resource, path)


# --- Dialogs ---

func _show_message(title: String, text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _show_confirm(title: String, text: String, on_confirm: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.confirmed.connect(func() -> void:
		on_confirm.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _show_unsaved_dialog_then(on_proceed: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "未保存の変更"
	dialog.dialog_text = "保存されていない変更があります。"
	dialog.ok_button_text = "保存"
	dialog.cancel_button_text = "キャンセル"

	dialog.add_button("破棄", true, "discard")
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			dialog.queue_free()
			on_proceed.call()
	)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		var resource: Resource = _editor.get_current_resource()
		var path: String = _editor.get_current_path()
		if resource != null and not path.is_empty() and path.ends_with(".tres"):
			var err: Error = _do_save_and_return(resource, path)
			if err != OK:
				return
		on_proceed.call()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _show_save_path_dialog() -> void:
	var resource: Resource = _editor.get_current_resource()
	if resource == null:
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "保存先を指定"
	dialog.size = Vector2i(500, 200)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var dir_label := Label.new()
	dir_label.text = "フォルダ:"
	vbox.add_child(dir_label)

	var dir_edit := LineEdit.new()
	dir_edit.text = _browser.get_selected_directory()
	vbox.add_child(dir_edit)

	var name_label := Label.new()
	name_label.text = "ファイル名 (.tres):"
	vbox.add_child(name_label)

	var name_edit := LineEdit.new()
	var res_id: String = str(resource.get("id")) if "id" in resource else "new_resource"
	name_edit.text = res_id
	vbox.add_child(name_edit)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func() -> void:
		var file_name: String = name_edit.text.strip_edges()
		if file_name.is_empty():
			dialog.queue_free()
			_show_message("エラー", "ファイル名を入力してください")
			return
		if not file_name.ends_with(".tres"):
			file_name += ".tres"
		var full_path: String = dir_edit.text.strip_edges().path_join(file_name)
		_editor.set_current_path(full_path)
		dialog.queue_free()
		_do_save(resource, full_path)
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _show_new_resource_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "新規リソース作成"
	dialog.size = Vector2i(400, 350)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var type_label := Label.new()
	type_label.text = "リソースタイプ:"
	vbox.add_child(type_label)

	var type_list := ItemList.new()
	type_list.custom_minimum_size.y = 160
	var types: PackedStringArray = [
		"CardData", "EnemyData", "EventData", "BikePartData",
		"CharacterData", "CompanionData", "ItemData",
	]
	for t: String in types:
		type_list.add_item(PropertyWidgets.get_resource_type_label(t))
	type_list.select(0)
	vbox.add_child(type_list)

	var dir_label := Label.new()
	dir_label.text = "保存先フォルダ:"
	vbox.add_child(dir_label)

	var dir_edit := LineEdit.new()
	dir_edit.text = _browser.get_selected_directory()
	vbox.add_child(dir_edit)

	var name_label := Label.new()
	name_label.text = "ファイル名:"
	vbox.add_child(name_label)

	var name_edit := LineEdit.new()
	name_edit.text = "new_resource"
	vbox.add_child(name_edit)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func() -> void:
		var selected: PackedInt32Array = type_list.get_selected_items()
		if selected.is_empty():
			dialog.queue_free()
			_show_message("エラー", "タイプを選択してください")
			return

		var type_name: String = types[selected[0]]
		var resource: Resource = PropertyWidgets._create_resource_instance(type_name)
		if resource == null:
			dialog.queue_free()
			_show_message("エラー", "リソースの作成に失敗しました")
			return

		var file_name: String = name_edit.text.strip_edges()
		if file_name.is_empty():
			file_name = "new_resource"
		if not file_name.ends_with(".tres"):
			file_name += ".tres"

		var full_path: String = dir_edit.text.strip_edges().path_join(file_name)
		dialog.queue_free()
		_editor.edit_new_resource(resource, full_path)
		_update_status(full_path + " (新規)")
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


# --- Status ---

func _update_status(text: String) -> void:
	_status_bar.text = text


func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func() -> void:
		_toast_label.visible = false
	)
