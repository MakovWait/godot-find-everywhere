@tool
extends VBoxContainer

const Output = preload("res://addons/find-everywhere/src/windows/quick_open/output.gd")
const LINE_EDIT_DEBOUNCE_TIME_MSEC = 300

var editor_interface: EditorInterface
var search_sources_to_add = []

@onready var _line_edit: LineEdit = $LineEdit
@onready var _search_options: Tree = $SearchOptions

var _auto_select_active = false
var _search_result_sources = {}

var _files = []
var _recent_options = []
var _search_results = []
var _queued_to_rebuild_cache = false
var _queued_to_update_search = false
var _icon_by_extension = {}
var _default_icon
var _parent_popup: ConfirmationDialog
var _line_edit_debounce: Timer


func _init() -> void:
	_line_edit_debounce = Timer.new()
	_line_edit_debounce.one_shot = true
	_line_edit_debounce.timeout.connect(func():
		_update_search()
	)
	add_child(_line_edit_debounce)


func _ready() -> void:
	_parent_popup = get_parent()
	_parent_popup.register_text_enter(_line_edit)
	_parent_popup.confirmed.connect(_on_popup_confirmed)
	_parent_popup.get_ok_button().hide()
	_parent_popup.get_cancel_button().hide()
	_parent_popup.title = "Quick Open"
	
	_update_theme()
	theme_changed.connect(_update_theme)

	_search_options.hide_folding = false
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)
	_search_options.columns = 2
	_search_options.select_mode = Tree.SELECT_ROW
	_search_options.set_column_expand(0, true)
	_search_options.set_column_expand(1, true)
	_search_options.set_column_clip_content(0, true)
	_search_options.set_column_clip_content(1, true)
	_search_options.scroll_horizontal_enabled = false
	_search_options.gui_input.connect(func(event):
		_line_edit.grab_focus()
	)
	_search_options.item_selected.connect(func():
		var selected = _search_options.get_selected()
		if selected and selected.has_meta("on_select"):
			selected.get_meta("on_select").call()
	)
	_search_options.item_activated.connect(_on_popup_confirmed)
	_search_options.create_item()

	_line_edit.clear_button_enabled = true
	_line_edit.focus_neighbor_bottom = _line_edit.get_path()
	_line_edit.focus_neighbor_top = _line_edit.get_path()
	_line_edit.gui_input.connect(func(event):
		if event.has_meta("___quick_open_line_edit_handled___"): return
		var k = event as InputEventKey
		if k:
			match k.keycode:
				KEY_UP, KEY_DOWN, KEY_PAGEDOWN, KEY_PAGEUP:
					_search_options.grab_focus()
					_auto_select_active = false
					_line_edit.accept_event()
					var e = event.duplicate()
					e.set_meta("___quick_open_line_edit_handled___", true)
					Input.parse_input_event(e)
	)
	_line_edit.text_changed.connect(func(_new_text):
		_line_edit_debounce.start(
			LINE_EDIT_DEBOUNCE_TIME_MSEC / 1000.0
		)
	)
	
	editor_interface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	
	visibility_changed.connect(func():
		if is_visible_in_tree():
			focus()
		else:
			blur()
	)
	
	add_search_results_source("files", _update_files_search)
	for src in search_sources_to_add:
		add_search_results_source(src.name, src.handler)
	
	_rebuild_search_cache()
	_update_search()


func _exit_tree() -> void:
	if editor_interface:
		var fs = editor_interface.get_resource_filesystem()
		if fs.filesystem_changed.is_connected(_on_filesystem_changed):
			fs.filesystem_changed.disconnect(_on_filesystem_changed)


func add_search_results_source(src_name, src):
	_search_result_sources[src_name] = src
	if src is Node:
		self.add_child(src)
	_queued_to_update_search = true


func remove_search_results_source(src_name):
	if not src_name in _search_result_sources:
		push_warning("%s source was not found" % src_name)
		return
	var src = _search_result_sources[src_name]
	_search_result_sources.erase(src_name)
	if src is Node:
		self.remove_child(src)
	_queued_to_update_search = true


func focus():
	_line_edit.grab_focus()
	_line_edit.select_all()
	if _queued_to_rebuild_cache:
		_rebuild_search_cache()
		_update_search()
	elif _queued_to_update_search:
		_update_search()
	_queued_to_update_search = false


func blur():
	_line_edit_debounce.stop()


func request_update_search():
	_queued_to_update_search = true


func add_search_result(result):
	_search_results.push_back(result)


func is_reached_max_results():
	return _search_options.get_root().get_child_count() >= 300


func _update_search():
	_auto_select_active = true
	_clear_tree_item_children(_search_options.get_root())
	_search_results.clear()
	
	var search_text = _line_edit.text
	var output = Output.new(self)
	for src in _search_result_sources.values():
		if src is Callable:
			src.call(search_text, output)
		else:
			src.update_search(search_text, output)
	_build_tree()


func _build_tree():
	_search_results.sort_custom(func(a,b): return a.score > b.score)
	
	for result in _search_results:
		if is_reached_max_results():
			return
		
		if result.has("recent_id") and _line_edit.text.is_empty():
			var recent_idx = _recent_options.find(result["recent_id"])
			if recent_idx != -1:
				var additional_score = 0.1 * (1.0 - 0.1 * (float(recent_idx) / len(_recent_options)))
				result["score"] = result["score"] + additional_score
		
		var root = _search_options.get_root()
		var idx = -1
		for c_idx in root.get_child_count():
			var c = root.get_child(c_idx)
			if result["score"] > c.get_meta("score"):
				idx = c_idx
				break
		var item: TreeItem = root.create_child(idx)
		result["fill_tree_item"].call(item)
		item.set_meta("score", result["score"])
		
		if _auto_select_active:
			var to_select = _search_options.get_root().get_first_child()
			if not to_select:
				return
			to_select.select(0)
			_search_options.scroll_to_item(to_select)


func _on_popup_confirmed():
	var selected = _if_null(
		_search_options.get_selected(), 
		_search_options.get_root().get_first_child()
	)
	if not selected:
		return
	if selected.has_meta("on_activate"):
		var on_activate = selected.get_meta("on_activate")
		on_activate.call()
		if selected.get_meta("recent_id"):
			_recent_options.push_front(selected.get_meta("recent_id"))
			if len(_recent_options) > 10:
				_recent_options.resize(10)
	_parent_popup.hide()


func _update_theme():
	_fill_icons()
	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")


func _update_files_search(search_text: String, output):
	var empty_search = search_text.is_empty()
	for file in _files:
		if empty_search or search_text.is_subsequence_ofn(file):
			var scored_path = _score_path(search_text, file.to_lower())
			var score = scored_path
			if empty_search:
				score = 0.1
			output.add_search_result({
				"recent_id": file,
				"score": score,
				"fill_tree_item": func(item: TreeItem):
					item.set_meta("on_activate", func():
						_open_file(item)
					)
					item.set_meta("recent_id", file)
					item.set_meta("full_path", "res://" + file)
					item.set_text(0, file.get_file())
					item.set_text(1, file.get_base_dir())
					item.set_text_direction(1, Control.TEXT_DIRECTION_RTL)
					item.set_tooltip_text(1, file)
					item.set_tooltip_text(0, file)
		#			item.set_text(1, str(entries[i].score))
					item.set_custom_color(1, _search_options.get_theme_color("font_color") * Color(1, 1, 1, 0.5))
					item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
					item.set_icon(
						0, 
						_icon_by_extension.get(
							file.get_extension(), 
							_default_icon
						)
					)
			})


func _clear_tree_item_children(item):
	for child in item.get_children():
		child.free()


func _score_path(search, path):
	var score = 0.9 + .1 * (search.length() / float(path.length()))

	# Exact match.
	if search == path:
		return 1.2

	# Positive bias for matches close to the beginning of the file name.
	var file = path.get_file()
	if file.get_extension() != "gd":
		score = score * 0.9
	
	var pos = file.findn(search)
	if pos != -1:
		return score * (1.0 - 0.1 * (float(pos) / file.length()))

	# Similarity
	return path.to_lower().similarity(search.to_lower())


func _rebuild_search_cache():
	_files.clear()
	_build_search_cache(editor_interface.get_resource_filesystem().get_filesystem())
	_queued_to_rebuild_cache = false


func _build_search_cache(dir: EditorFileSystemDirectory):
	for i in dir.get_subdir_count():
		_build_search_cache(dir.get_subdir(i))
	
	for i in dir.get_file_count():
		var file = dir.get_file_path(i)
		var engine_type = dir.get_file_type(i)
#		var script_type = dir.get_file_resource_script_class(i)
#		var actual_type = script_type.is_empty() ? engine_type : script_type
		var actual_type = engine_type
		for parent_type in ["Resource", "TextFile"]:
			if ClassDB.is_parent_class(engine_type, parent_type):
				_files.push_back(file.substr(6, file.length()))
				break


func _on_filesystem_changed():
	_queued_to_rebuild_cache = true


func _if_null(a, b):
	var result = a
	if not a:
		result = b
	return result


func _open_file(item):
	if not item.has_meta("full_path"):
		return
	var selected_path = item.get_meta("full_path")
	var scene_extensions = ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	if selected_path.get_extension() in scene_extensions:
		editor_interface.open_scene_from_path(selected_path)
	else:
		if ResourceLoader.exists(selected_path):
			editor_interface.edit_resource(load(selected_path))
	editor_interface.get_file_system_dock().navigate_to_path(selected_path)


func _fill_icons():
	_default_icon = get_theme_icon(StringName("Object"), StringName("EditorIcons"))
	
	#https://github.com/godotengine/godot/blob/f6187014ec1d7a47b7201f64f3a8376a5da2f42d/editor/editor_asset_installer.cpp#L97
	_icon_by_extension.clear()
	_icon_by_extension["bmp"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["dds"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["exr"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["hdr"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["jpg"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["jpeg"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["png"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["svg"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["tga"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))
	_icon_by_extension["webp"] = get_theme_icon(StringName("ImageTexture"), StringName("EditorIcons"))

	_icon_by_extension["wav"] = get_theme_icon(StringName("AudioStreamWAV"), StringName("EditorIcons"))
	_icon_by_extension["ogg"] = get_theme_icon(StringName("AudioStreamOggVorbis"), StringName("EditorIcons"))
	_icon_by_extension["mp3"] = get_theme_icon(StringName("AudioStreamMP3"), StringName("EditorIcons"))

	_icon_by_extension["scn"] = get_theme_icon(StringName("PackedScene"), StringName("EditorIcons"))
	_icon_by_extension["tscn"] = get_theme_icon(StringName("PackedScene"), StringName("EditorIcons"))
	_icon_by_extension["escn"] = get_theme_icon(StringName("PackedScene"), StringName("EditorIcons"))
	_icon_by_extension["dae"] = get_theme_icon(StringName("PackedScene"), StringName("EditorIcons"))
	_icon_by_extension["gltf"] = get_theme_icon(StringName("PackedScene"), StringName("EditorIcons"))
	_icon_by_extension["glb"] = get_theme_icon(StringName("PackedScene"), StringName("EditorIcons"))

	_icon_by_extension["gdshader"] = get_theme_icon(StringName("Shader"), StringName("EditorIcons"))
	_icon_by_extension["gdshaderinc"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["gd"] = get_theme_icon(StringName("GDScript"), StringName("EditorIcons"))
	if Engine.has_singleton("GodotSharp"):
		_icon_by_extension["cs"] = get_theme_icon(StringName("CSharpScript"), StringName("EditorIcons"))
	else:
		_icon_by_extension["cs"] = get_theme_icon(StringName("ImportFail"), StringName("EditorIcons"))
	_icon_by_extension["res"] = get_theme_icon(StringName("Resource"), StringName("EditorIcons"))
	_icon_by_extension["tres"] = get_theme_icon(StringName("Resource"), StringName("EditorIcons"))
	_icon_by_extension["atlastex"] = get_theme_icon(StringName("AtlasTexture"), StringName("EditorIcons"))

	_icon_by_extension["obj"] = get_theme_icon(StringName("Mesh"), StringName("EditorIcons"))

	_icon_by_extension["txt"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["md"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["rst"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["json"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["yml"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["yaml"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["toml"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["cfg"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
	_icon_by_extension["ini"] = get_theme_icon(StringName("TextFile"), StringName("EditorIcons"))
