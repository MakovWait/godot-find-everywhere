@tool
extends VBoxContainer

const QuickOpenSectinBase = preload(
	"res://addons/find-everywhere/src/tabs/quick_open/quick_open_section_base.gd"
)

var editor_interface: EditorInterface

@onready var _line_edit: LineEdit = $LineEdit
@onready var _search_options: Tree = $SearchOptions

var _files = []
var _dirs = []
var _queued_to_rebuild_cache = false
var _icon_by_extension = {}
var _default_icon
var _parent_popup: ConfirmationDialog
var _sections = {}
var _sections_order = []


func _ready() -> void:
	_parent_popup = get_parent()
	_parent_popup.register_text_enter(_line_edit)
	_parent_popup.confirmed.connect(_on_popup_confirmed)
	
	_update_theme()
	theme_changed.connect(_update_theme)

	_search_options.hide_folding = false
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)
	_search_options.columns = 2
	_search_options.select_mode = Tree.SELECT_ROW
	_search_options.gui_input.connect(func(event):
		_line_edit.grab_focus()
	)
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
	
	visibility_changed.connect(func():
		if is_visible_in_tree():
			focus()
		else:
			blur()
	)
	
	add_section("files", _update_files_search)
	add_section("dirs", _update_dirs_search)
#	add_section(
#		"builtin-actions", 
#		preload(
#			"res://addons/find-everywhere/src/tabs/quick_open/command_palette_module.gd"
#		).new(editor_interface)
#	)
	
	_rebuild_search_cache()
	_update_search()


func add_section(section_name, section):
	_sections[section_name] = section
	_sections_order.push_back(section_name)


func focus():
	_line_edit.grab_focus()
	_line_edit.select_all()
	
#	_update_recent()
	if _queued_to_rebuild_cache:
		_rebuild_search_cache()
		_update_search()


func blur():
	pass


func _update_theme():
	_fill_icons()
	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")


func _update_search():
	_clear_tree_item_children(_search_options.get_root())
	
	var search_text = _line_edit.text
	var entries = []
	for section_name in _sections_order:
		var section = _sections[section_name]
		if section is Callable:
			entries.append_array(section.call(search_text))
		else:
			entries.append_array(section.update_search(search_text))
	
	if not search_text.is_empty():
		entries.sort_custom(func(a, b): return a.score > b.score)
	
	for i in range(min(300, len(entries))):
		var e = entries[i]
		entries[i]["to_tree_item"].call(_search_options)
	
	var to_select = _search_options.get_root().get_first_child()
	if not to_select:
		return
	to_select.select(0)
	_search_options.scroll_to_item(to_select)


func _update_files_search(search_text: String):
	var empty_search = search_text.is_empty()
	var entries = []
	for file in _files:
		if empty_search or search_text.is_subsequence_ofn(file):
			entries.push_back({
				"score": _score_path(search_text, file.to_lower()),
				"to_tree_item": func(search_options: Tree):
					var item = search_options.create_item(search_options.get_root())
					item.set_meta("on_activate", func():
						_open_file(item)
					)
					item.set_meta("full_path", file)
					item.set_text(0, file.get_file())
					item.set_text(1, file.get_base_dir())
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
	return entries



func _update_dirs_search(search_text: String):
	var empty_search = search_text.is_empty()
	var entries = []
	for dir in _dirs:
		if empty_search or search_text.is_subsequence_ofn(dir.name):
			entries.push_back({
				"score": 1.2 if search_text.to_lower() == dir.name.to_lower() else 0.0,
				"to_tree_item": func(search_options: Tree):
					var item = search_options.create_item(search_options.get_root())
					item.set_meta("on_activate", func():
						editor_interface.get_file_system_dock().navigate_to_path(dir.path)
					)
					item.set_text(0, dir.name)
					item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
					item.set_icon(
						0, 
						get_theme_icon("Folder", "EditorIcons")
					)
			})
	return entries


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
	_dirs.clear()
	_build_search_cache(editor_interface.get_resource_filesystem().get_filesystem())
	_queued_to_rebuild_cache = false


func _build_search_cache(dir: EditorFileSystemDirectory):
	_dirs.push_back({
		'path': dir.get_path(),
		'name': "res://" if dir.get_name().is_empty() else dir.get_name(),
	})
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
	var selected = _search_options.get_selected()
	if selected.has_meta("on_activate"):
		var on_activate = selected.get_meta("on_activate")
		on_activate.call()


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
