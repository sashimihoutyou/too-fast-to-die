class_name DebugResourceBrowser extends RefCounted

signal resource_selected(path: String)

var _tree: Tree
var _search_bar: LineEdit
var _resource_meta: Dictionary = {}


func setup(tree: Tree, search_bar: LineEdit) -> void:
	_tree = tree
	_search_bar = search_bar
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_search_bar.text_changed.connect(_on_search_changed)
	build_tree()


func build_tree() -> void:
	_tree.clear()
	_resource_meta.clear()
	var root: TreeItem = _tree.create_item()
	root.set_text(0, "resources/")
	root.set_meta("is_directory", true)
	root.set_meta("file_path", "res://resources")
	_scan_directory("res://resources", root)


func get_selected_directory() -> String:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return "res://resources"
	var is_dir: bool = item.get_meta("is_directory", true)
	if is_dir:
		return item.get_meta("file_path", "res://resources")
	var path: String = item.get_meta("file_path", "")
	return path.get_base_dir()


func _scan_directory(path: String, parent: TreeItem) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	var dirs: PackedStringArray = []
	var files: PackedStringArray = []

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not entry_name.begins_with("."):
			if dir.current_is_dir():
				dirs.append(entry_name)
			elif entry_name.ends_with(".tres"):
				files.append(entry_name)
		entry_name = dir.get_next()

	dirs.sort()
	files.sort()

	for dir_name: String in dirs:
		var item: TreeItem = _tree.create_item(parent)
		item.set_text(0, dir_name + "/")
		item.set_meta("is_directory", true)
		item.set_meta("file_path", path.path_join(dir_name))
		item.collapsed = true
		_scan_directory(path.path_join(dir_name), item)

	for file_name: String in files:
		var full_path: String = path.path_join(file_name)
		var res: Resource = load(full_path)

		var item: TreeItem = _tree.create_item(parent)
		item.set_text(0, file_name.get_basename())
		item.set_meta("is_directory", false)
		item.set_meta("file_path", full_path)

		var meta: Dictionary = {"path": full_path}
		if res != null:
			item.set_meta("resource_class", res.get_class())
			meta["class_name"] = res.get_class()
			if "id" in res:
				meta["id"] = str(res.get("id"))
			if "display_name" in res:
				meta["display_name"] = str(res.get("display_name"))

		_resource_meta[full_path] = meta


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	if item.get_meta("is_directory", true):
		return
	var path: String = item.get_meta("file_path", "")
	if not path.is_empty():
		resource_selected.emit(path)

func _on_item_activated() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return
	if item.get_meta("is_directory", true):
		item.collapsed = not item.collapsed
		return
	var path: String = item.get_meta("file_path", "")
	if not path.is_empty():
		resource_selected.emit(path)


func _on_search_changed(text: String) -> void:
	if _tree.get_root() == null:
		return
	if text.is_empty():
		_show_all_items(_tree.get_root())
		return
	var query: String = text.to_lower()
	_filter_items(_tree.get_root(), query)


func _show_all_items(item: TreeItem) -> void:
	if item == null:
		return
	item.visible = true
	var child: TreeItem = item.get_first_child()
	while child != null:
		_show_all_items(child)
		child = child.get_next()


func _filter_items(item: TreeItem, query: String) -> bool:
	if item == null:
		return false

	var any_child_visible: bool = false
	var child: TreeItem = item.get_first_child()
	while child != null:
		if _filter_items(child, query):
			any_child_visible = true
		child = child.get_next()

	if item.get_meta("is_directory", true):
		item.visible = any_child_visible
		if any_child_visible:
			item.collapsed = false
		return any_child_visible

	var file_path: String = item.get_meta("file_path", "")
	var meta: Dictionary = _resource_meta.get(file_path, {})
	var matches: bool = false

	if item.get_text(0).to_lower().contains(query):
		matches = true
	elif meta.get("id", "").to_lower().contains(query):
		matches = true
	elif meta.get("display_name", "").to_lower().contains(query):
		matches = true

	item.visible = matches
	return matches
