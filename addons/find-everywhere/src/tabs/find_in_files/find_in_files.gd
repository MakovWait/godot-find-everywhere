@tool
extends VBoxContainer

const LINE_EDIT_DEBOUNCE_TIME_MSEC = 300
const FindInFilesCoroutine = preload(
	"res://addons/find-everywhere/src/tabs/find_in_files/find_in_files_coroutine.gd"
)

var editor_interface: EditorInterface

@onready var _search_options: Tree = %SearchOptions
@onready var _code_edit: CodeEdit = %CodeEdit
@onready var _line_edit: LineEdit = %LineEdit
@onready var _file_name_label: Label = %FileNameLabel
@onready var _file_path_label: Label = %FilePathLabel
@onready var _check_boxes: HBoxContainer = %CheckBoxes
@onready var _line_edit_options: HBoxContainer = %LineEditOptions
@onready var _search_history_button: Button = %SearchHistoryButton
@onready var _file_dialog: FileDialog = $FileDialog
@onready var _folder_button: Button = %FolderButton
@onready var _folder_line_edit: LineEdit = %FolderLineEdit
@onready var _code_edit_editable_check: CheckBox = %CodeEditEditableCheckBox

var _parent_popup: ConfirmationDialog
var _search_coroutine: FindInFilesCoroutine
var _line_edit_debounce: Timer


func _init() -> void:
	_line_edit_debounce = Timer.new()
	_line_edit_debounce.one_shot = true
	_line_edit_debounce.timeout.connect(func():
		_update_search()
	)
	add_child(_line_edit_debounce)
	
	_search_coroutine = FindInFilesCoroutine.new()
	_search_coroutine.result_found.connect(_on_result_found)
	add_child(_search_coroutine)


func _ready() -> void:
	_file_path_label.clip_text = true
	_file_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_path_label.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_FILE
	
	var add_filter = func(filter_name):
		return func(toggled):
			var filters = self._search_coroutine.extension_filter
			var found_filter_idx = filters.find(filter_name)
			if found_filter_idx != -1:
				filters.remove_at(found_filter_idx)
			if toggled:
				filters.append(filter_name)
			_update_search()
	
	var set_property = func(prop_name):
		return func(toggled):
			self._search_coroutine.set(prop_name, toggled)
			_update_search()
	
	_add_search_toggle_button("W", false, set_property.call("whole_words"), "Words")
	_add_search_toggle_button("Cc", false, set_property.call("match_case"), "Match case")
	_add_search_toggle_button(".*", false, set_property.call("regex"), "Regex")

	_add_search_checkbox("gd", true, add_filter.call("gd"))
	_add_search_checkbox("tscn", true, add_filter.call("tscn"))
	_add_search_checkbox("gdshader", false, add_filter.call("gdshader"))
	
	_update_theme()
	theme_changed.connect(_update_theme)

	_line_edit.clear_button_enabled = true
	_line_edit.focus_neighbor_bottom = _line_edit.get_path()
	_line_edit.focus_neighbor_top = _line_edit.get_path()
	_line_edit.gui_input.connect(func(event):
		if event.has_meta("___find_in_files_line_edit_handled___"): return
		var k = event as InputEventKey
		if k:
			match k.keycode:
				KEY_UP, KEY_DOWN, KEY_PAGEDOWN, KEY_PAGEUP:
					_search_options.grab_focus()
					_line_edit.accept_event()
					var e = event.duplicate()
					e.set_meta("___find_in_files_line_edit_handled___", true)
					Input.parse_input_event(e)
	)
	_line_edit.text_changed.connect(func(_new_text):
		_line_edit_debounce.start(
			LINE_EDIT_DEBOUNCE_TIME_MSEC / 1000.0
		)
	)

	_search_options.item_selected.connect(_on_tree_item_selected)
	_search_options.item_activated.connect(func():
		_parent_popup.hide()
		_open_selected_item()
	)
	_search_options.gui_input.connect(func(_event): 
		_line_edit.grab_focus()
	)
	_search_options.hide_folding = true
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)
	_search_options.columns = 3
	_search_options.create_item()
	_search_options.select_mode = Tree.SELECT_ROW
	_search_options.set_column_expand_ratio(0, 4)
	_search_options.set_column_expand(0, true)
	_search_options.set_column_expand(1, true)
	_search_options.set_column_expand(2, false)
	_search_options.set_column_clip_content(0, true)
	_search_options.set_column_clip_content(1, true)
	_search_options.scroll_horizontal_enabled = false


	_code_edit_editable_check.toggled.connect(func(pressed):
		_code_edit.editable = pressed
	)
	
	_code_edit.draw_tabs = true
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.scroll_smooth = true
#	_code_edit.set("theme_override_styles/read_only", StyleBoxEmpty.new())
#	_code_edit.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	_code_edit.editable = false
	_code_edit.focus_exited.connect(func():
		if not _code_edit.editable:
			return
		var selected_params = _search_options.get_selected().get_meta("params")
		var selected_path: String =  selected_params.fpath
		var file = FileAccess.open(selected_path, FileAccess.WRITE)
		if file:
			file.store_string(_code_edit.text)
	)
	
	_parent_popup = get_parent()
	_parent_popup.register_text_enter(_line_edit)
	_parent_popup.confirmed.connect(_open_selected_item)
	
	visibility_changed.connect(func():
		if is_visible_in_tree():
			focus()
		else:
			blur()
	)
	
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.dir_selected.connect(func(path):
		var i = path.find("://");
		if i != -1:
			path = path.substr(i + 3)
		_folder_line_edit.text = path
		_search_coroutine.folder = path
		_update_search()
	)
	
	_folder_line_edit.focus_exited.connect(func():
		_search_coroutine.folder = "res://" + _folder_line_edit.text
		_update_search()
	)
	
	_folder_button.pressed.connect(func():
		_file_dialog.popup_centered_clamped(Vector2i(700, 500), 0.8)
	)


func focus():
	var script_editor = _get_current_script_editor()
	if script_editor:
		var syntax_highlighter = script_editor.syntax_highlighter
		_code_edit.syntax_highlighter = syntax_highlighter
	
	_line_edit.grab_focus()
	_line_edit.select_all()


func blur():
	_search_coroutine.stop()
	_line_edit_debounce.stop()


func _update_search():
	if not is_node_ready():
		return
	_clear_tree_item_children(_search_options.get_root())
	_search_coroutine.editor_filesystem = editor_interface.get_resource_filesystem()
	_search_coroutine.search_text = _line_edit.text
	_search_coroutine.max_results = 200
	_search_coroutine.stop()
	_search_coroutine.start()


func _on_tree_item_selected():
	var selected_item = _search_options.get_selected()
	if selected_item and selected_item.has_meta("params"):
		var params = selected_item.get_meta("params")
		var file = FileAccess.open(params.fpath, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			_code_edit.text = content
			_goto_line_selection(
				_code_edit, 
				params.line_number - 1, 
				params.begin, 
				params.end
			)
			_file_path_label.text = params.fpath.get_base_dir()
			_file_name_label.text = params.fpath.get_file()


func _on_result_found(fpath: String, line_number: int, begin: int, end: int, line: String):
	var root = _search_options.get_root()
	var item = _search_options.create_item()
	
	var old_text_size = len(line)
	var text = line.strip_edges(true, false)
	var chars_removed = old_text_size - len(text)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CUSTOM)
	item.set_text(0, text)
	item.set_custom_draw(0, self, "_draw_result_text")
	
	item.set_text(1, fpath.get_file())
	item.set_text(2, str(line_number))
	item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)

	item.set_custom_color(1, _search_options.get_theme_color("font_color") * Color(1, 1, 1, 0.5))
	item.set_custom_color(2, _search_options.get_theme_color("font_color") * Color(1, 1, 1, 0.6))
	
	item.set_meta('params', {
		'fpath': fpath,
		'line_number': line_number,
		'begin': begin,
		'begin_trimmed': max(0, begin - chars_removed),
		'end': end,
		'end_trimmed': max(0, end - chars_removed),
		'line': line
	})
	if root.get_child_count() == 1:
		item.select(0)
		_search_options.scroll_to_item(item, true)


func _draw_result_text(item: TreeItem, rect: Rect2):
	if not item.has_meta("params"):
		return
	var item_text = item.get_text(0)
	var font = _search_options.get_theme_font(StringName("font"))
	var font_size = _search_options.get_theme_font_size(StringName("font_size"))
	var match_rect = rect
	var r = item.get_meta("params")
	match_rect.position.x += font.get_string_size(item_text.left(r.begin_trimmed), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x - 1
	match_rect.size.x = font.get_string_size(item_text.substr(r.begin_trimmed, r.end_trimmed - r.begin_trimmed), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1
	match_rect.position.y += 1 * editor_interface.get_editor_scale()
	match_rect.size.y -= 2 * editor_interface.get_editor_scale()
	_search_options.draw_rect(match_rect, get_theme_color("accent_color", "Editor") * Color(1, 1, 1, 0.33), false, 2.0)
	_search_options.draw_rect(match_rect, get_theme_color("accent_color", "Editor") * Color(1, 1, 1, 0.17), true)


func _open_selected_item():
	if not _search_options.get_selected():
		return
	var selected_params = _search_options.get_selected().get_meta("params")
	var selected_path: String =  selected_params.fpath
	var scene_extensions = ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	if selected_path.get_extension() in scene_extensions:
		editor_interface.open_scene_from_path(selected_path)
	else:
		var resource = load(selected_path)
		if resource is Script:
			editor_interface.edit_script(
				resource, 
				selected_params.line_number,
				selected_params.begin
			)
		elif ResourceLoader.exists(selected_path):
			editor_interface.edit_resource(resource)
		if "TextFile" in str(resource) or resource is Script:
			var editor = _get_current_script_editor() as CodeEdit
			if editor:
				_goto_line_selection(
					editor, 
					selected_params.line_number - 1, 
					selected_params.begin, 
					selected_params.end
				)
	editor_interface.get_file_system_dock().navigate_to_path(selected_path)


func _update_theme():
#	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")
	_search_history_button.icon = get_theme_icon("Search", "EditorIcons")
	_line_edit.right_icon = null
	_line_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_file_path_label.add_theme_color_override(
		"font_color",
		get_theme_color("font_color", "Tree")
	)
	_file_name_label.add_theme_color_override(
		"font_color",
		get_theme_color("font_color", "Tree")
	)


func _clear_tree_item_children(item):
	if not item: 
		return
	for child in item.get_children():
		item.remove_child(child)
		child.free()


func _get_current_script_editor():
	var script_editor = editor_interface.get_script_editor()
	if script_editor.get_current_editor():
		if script_editor.get_current_editor().get_base_editor():
			var editor = script_editor.get_current_editor().get_base_editor()
			return editor
	return null


func _add_search_checkbox(cname, button_pressed, on_toggled):
	var check_box = CheckBox.new()
	check_box.text = cname
	check_box.toggled.connect(on_toggled)
	check_box.button_pressed = button_pressed
	_check_boxes.add_child(check_box)


func _add_search_toggle_button(bname, button_pressed, on_toggled, tooltip=""):
	var button = Button.new()
	button.tooltip_text = tooltip
	button.text = bname
	button.button_pressed = button_pressed
	button.flat = true
	button.toggle_mode = true
	button.toggled.connect(func(toggled):
		on_toggled.call(toggled)
		_line_edit.grab_focus()
	)
	_line_edit_options.add_child(button)
#	_check_boxes.add_child(check_box)


func _goto_line_selection(text_editor: CodeEdit, p_line: int, p_begin: int, p_end: int):
	text_editor.remove_secondary_carets()
	text_editor.unfold_line(p_line)
	text_editor.call_deferred("set_caret_line", p_line)
	text_editor.call_deferred("set_caret_column", p_end)
	text_editor.select(p_line, p_begin, p_line, p_end)
