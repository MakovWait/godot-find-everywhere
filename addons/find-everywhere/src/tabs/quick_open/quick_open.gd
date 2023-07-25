@tool
extends VBoxContainer

var editor_interface: EditorInterface

@onready var _line_edit: LineEdit = $LineEdit
@onready var _search_options: Tree = $SearchOptions

var _files = []
var _queued_to_rebuild_cache = false
var _icon_by_extension = {}
var _default_icon
var _recent_opened = []
var _parent_popup: ConfirmationDialog


var _tree_section_recent
var _tree_section_results


func _tab_setup(popup):
	_parent_popup = popup
	_parent_popup.register_text_enter(_line_edit)
	
	_update_theme()
	theme_changed.connect(_update_theme)

	_search_options.hide_folding = false
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)
	_search_options.gui_input.connect(func(event):
		_line_edit.grab_focus()
	)
	var root = _search_options.create_item()
	_tree_section_recent = _search_create_section(root, "Recent")
	_tree_section_results = _search_create_section(root, "Files")
	
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
					_line_edit.accept_event()
					var e = event.duplicate()
					e.set_meta("___quick_open_line_edit_handled___", true)
					Input.parse_input_event(e)
	)
	_line_edit.text_changed.connect(func(_new_text):
		_update_search()
	)
	
	editor_interface.get_resource_filesystem().filesystem_changed.connect(func():
		_queued_to_rebuild_cache = true
	)
	
	_rebuild_search_cache()
	_update_search()


func _tab_focus():
	_line_edit.grab_focus()
	_line_edit.select_all()
	_parent_popup.confirmed.connect(_on_popup_confirmed)
	
	_update_recent()
	if _queued_to_rebuild_cache:
		_rebuild_search_cache()
		_update_search()


func _tab_blur():
	if _parent_popup.is_connected("confirmed", _on_popup_confirmed):
		_parent_popup.confirmed.disconnect(_on_popup_confirmed)


func _update_theme():
	_fill_icons()
	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")


func _update_search():
	var search_text = _line_edit.text
	var empty_search = search_text.is_empty()
	
	var entries = []
	for file in _files:
		if empty_search or search_text.is_subsequence_ofn(file):
			entries.push_back({
				"path": file,
				"score": _score_path(search_text, file.to_lower())
			})
	
	var search_results = _tree_section_results
	_clear_tree_item_children(search_results)
	if len(entries) > 0:
		if not empty_search:
			entries.sort_custom(func(a, b): return a.score > b.score)
		
		var entry_limit = min(len(entries), 300)
		for i in entry_limit:
			var item = _search_options.create_item(search_results)
			item.set_text(0, entries[i].path)
			item.set_icon(
				0, 
				_icon_by_extension.get(
					entries[i].path.get_extension(), 
					_default_icon
				)
			)

		var to_select = search_results.get_first_child()
		to_select.select(0)
#		to_select.set_as_cursor(0)
		_search_options.scroll_to_item(to_select)
	else:
		_search_options.deselect_all()


func _update_recent():
	var recent = _tree_section_recent
	_clear_tree_item_children(recent)
	for recent_item in _recent_opened:
		var item = _search_options.create_item(recent)
		item.set_selectable(0, ResourceLoader.exists(recent_item))
		item.set_text(0, recent_item.substr(6, len(recent_item)))
		item.set_icon(
			0, 
			_icon_by_extension.get(
				recent_item.get_extension(), 
				_default_icon
			)
		)
	var select_if_can = func(idx):
		if idx < 0 or idx >= len(_recent_opened):
			return
		var to_select = recent.get_child(idx)
		to_select.select(0)
		_search_options.scroll_to_item(to_select)
	select_if_can.call(min(1, len(_recent_opened) - 1))


func _search_create_section(root, item_name):
	var section = _search_options.create_item(root)
	section.set_text(0, item_name)
	section.set_selectable(0, false)
	section.set_custom_bg_color(0, _search_options.get_theme_color(StringName("prop_subsection"), StringName("Editor")))
	return section


func _clear_tree_item_children(item):
	for child in item.get_children():
		item.remove_child(child)
		child.free()


func _score_path(search, path):
	var score = 0.9 + .1 * (search.length() / float(path.length()))

	# Exact match.
	if search == path:
		return 1.2

	# Positive bias for matches close to the beginning of the file name.
	var file = path.get_file();
	var pos = file.findn(search);
	if pos != -1:
		return score * (1.0 - 0.1 * (float(pos) / file.length()))

	# Similarity
	return path.to_lower().similarity(search.to_lower());


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
		
		for parent_type in ["Resource"]:
			if ClassDB.is_parent_class(engine_type, parent_type):
				_files.push_back(file.substr(6, file.length()))
				break


func _on_popup_confirmed():
	if not _search_options.get_selected():
		return
	var selected_path = "res://" + _search_options.get_selected().get_text(0)
	var scene_extensions = ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	if selected_path.get_extension() in scene_extensions:
		editor_interface.open_scene_from_path(selected_path)
	else:
		if ResourceLoader.exists(selected_path):
			editor_interface.edit_resource(load(selected_path))
	editor_interface.get_file_system_dock().navigate_to_path(selected_path)
	
	var recent_path_idx = _recent_opened.find(selected_path)
	if recent_path_idx != -1:
		_recent_opened.remove_at(recent_path_idx)
	_recent_opened.push_front(selected_path)
	if len(_recent_opened) > 5:
		_recent_opened.pop_back()


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
