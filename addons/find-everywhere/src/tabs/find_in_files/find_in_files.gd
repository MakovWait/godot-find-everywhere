@tool
extends VBoxContainer

const LINE_EDIT_DEBOUNCE_TIME_MSEC = 800
const FindInFilesCoroutine = preload(
	"res://addons/find-everywhere/src/tabs/find_in_files/find_in_files_coroutine.gd"
)

var editor_interface: EditorInterface

@onready var _search_options: Tree = %SearchOptions
@onready var _code_edit: CodeEdit = %CodeEdit
@onready var _line_edit: LineEdit = $LineEdit

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


func _tab_setup(popup):
	_parent_popup = popup
	_parent_popup.register_text_enter(_line_edit)
	
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

	_search_options.hide_folding = true
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)
	_search_options.gui_input.connect(func(event):
		_line_edit.grab_focus()
	)
	_search_options.create_item()

	_code_edit.text = get_script().source_code
	_code_edit.draw_tabs = true
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.scroll_smooth = true


func _tab_focus():
	_line_edit.grab_focus()
	_line_edit.select_all()
	_parent_popup.confirmed.connect(_on_popup_confirmed)


func _tab_blur():
	if _parent_popup.is_connected("confirmed", _on_popup_confirmed):
		_parent_popup.confirmed.disconnect(_on_popup_confirmed)
	_search_coroutine.stop()
	_line_edit_debounce.stop()


func _update_search():
	_clear_tree_item_children(_search_options.get_root())
	_search_coroutine.search_text = _line_edit.text
	_search_coroutine.extension_filter = ["gd"]
#	_search_coroutine.extension_filter = ["md"]
	_search_coroutine.whole_words = false
	_search_coroutine.folder = ""
	_search_coroutine.stop()
	_search_coroutine.start()


func _on_result_found(fpath, line_number, begin, end, line):
	var root = _search_options.get_root()
	var item = _search_options.create_item()
	item.set_text(0, line)


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


func _update_theme():
	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")


func _clear_tree_item_children(item):
	for child in item.get_children():
		item.remove_child(child)
		child.free()
