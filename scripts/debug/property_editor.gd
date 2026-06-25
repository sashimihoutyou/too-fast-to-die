class_name DebugPropertyEditor extends RefCounted

signal dirty_changed(is_dirty: bool)

var _header_label: Label
var _dirty_label: Label
var _property_list: VBoxContainer
var _scroll: ScrollContainer
var _current_resource: Resource
var _current_path: String
var _is_dirty: bool = false


func setup(header_label: Label, dirty_label: Label, property_list: VBoxContainer, scroll: ScrollContainer) -> void:
	_header_label = header_label
	_dirty_label = dirty_label
	_property_list = property_list
	_scroll = scroll


func edit_resource(path: String) -> void:
	_current_path = path
	_current_resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if _current_resource == null:
		_header_label.text = "読み込み失敗: " + path
		_clear_properties()
		return

	_header_label.text = "%s  —  %s" % [PropertyWidgets.get_resource_type_label(_current_resource.get_class()), path.get_file()]
	_set_dirty(false)
	_build_property_ui()


func edit_new_resource(resource: Resource, path: String) -> void:
	_current_resource = resource
	_current_path = path
	_header_label.text = "%s  —  %s (新規)" % [PropertyWidgets.get_resource_type_label(resource.get_class()), path.get_file()]
	_set_dirty(true)
	_build_property_ui()


func get_current_resource() -> Resource:
	return _current_resource


func get_current_path() -> String:
	return _current_path


func set_current_path(path: String) -> void:
	_current_path = path


func is_dirty() -> bool:
	return _is_dirty


func mark_clean() -> void:
	_set_dirty(false)


func clear() -> void:
	_current_resource = null
	_current_path = ""
	_header_label.text = "リソースを選択してください"
	_set_dirty(false)
	_clear_properties()


func validate() -> String:
	if _current_resource == null:
		return "リソースが選択されていません"
	if "id" in _current_resource:
		var id: Variant = _current_resource.get("id")
		if id == null or str(id).is_empty():
			return "id が空です"
	if _current_path.is_empty():
		return "保存先が指定されていません"
	return ""


func _set_dirty(dirty: bool) -> void:
	_is_dirty = dirty
	if _dirty_label != null:
		_dirty_label.text = " *未保存" if dirty else ""
	dirty_changed.emit(dirty)


func _on_property_changed() -> void:
	_set_dirty(true)


func _clear_properties() -> void:
	for child: Node in _property_list.get_children():
		child.queue_free()


func _build_property_ui() -> void:
	_clear_properties()
	if _current_resource == null:
		return

	for prop: Dictionary in _current_resource.get_property_list():
		if PropertyWidgets.is_editable_property(prop):
			var row: Control = PropertyWidgets.create_property_row(prop, _current_resource, _on_property_changed)
			_property_list.add_child(row)
