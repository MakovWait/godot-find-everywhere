@tool
extends EditorPlugin

const DoubleClick = preload("res://addons/find-everywhere/src/triggers/double_click.gd")
const PluginPopup: PackedScene = preload("res://addons/find-everywhere/src/popup.tscn")
const PopupBase = preload("res://addons/find-everywhere/src/popup_base.gd")

var _popup_trigger
var _popup_dialog
var _sh: Shortcut


var _find_in_files_popup


func _enter_tree() -> void:
	_popup_trigger = DoubleClick.new(
		KEY_SHIFT, 300
	)
	_popup_trigger.triggered.connect(_show_popup)
	_popup_dialog = PluginPopup.instantiate()
	get_editor_interface().get_base_control().add_child(_popup_dialog)
	
#	var quick_open = preload(
#		"res://addons/find-everywhere/src/tabs/quick_open/quick_open.tscn"
#	).instantiate()
#	quick_open.script = load("res://addons/find-everywhere/src/tabs/quick_open/quick_open.gd")
#	quick_open.editor_interface = get_editor_interface()

	var quick_open = preload(
		"res://addons/find-everywhere/src/tabs/quick_open/link.gd"
	).get_quick_open(get_editor_interface())
	
#	var quick_open = load("res://addons/find-everywhere/src/tabs/quick_open/quick_open.gd").new()
#	quick_open.editor_interface = get_editor_interface()
	
	_popup_dialog.add_tab("Open", quick_open)
	
	var find_in_files = preload(
		"res://addons/find-everywhere/src/tabs/find_in_files/link.gd"
	).get_find_in_files(get_editor_interface())
	_find_in_files_popup = PopupBase.new()
	get_editor_interface().get_base_control().add_child(_find_in_files_popup)
	_find_in_files_popup.add_child(find_in_files)
	
	var editor_settings = get_editor_interface().get_editor_settings()
	if not editor_settings.has_setting("addons/FindEverywhere/find_in_files_shortcut"):
		var sh = Shortcut.new()
		var ev = InputEventKey.new()
		ev.device = -1
		ev.shift_pressed = true
		ev.meta_pressed = true
		ev.keycode = 70
		sh.events = [ev]
		editor_settings.set_setting("addons/FindEverywhere/find_in_files_shortcut", sh)
	editor_settings.add_property_info({
		"name": "FindEverywhere/find_in_files_shortcut",
		"type": TYPE_OBJECT,
	})
	_sh = editor_settings.get_setting("FindEverywhere/find_in_files_shortcut")
#	var b = Button.new()
#	sh.events
#	b.shortcut = sh


func _shortcut_input(event: InputEvent) -> void:
	if _sh.matches_event(event):
		_find_in_files_popup.raise(get_editor_interface().get_editor_scale())


func _exit_tree() -> void:
	_popup_trigger.triggered.disconnect(_show_popup)
	_popup_dialog.queue_free()
	_find_in_files_popup.queue_free()


func _show_popup():
#	var b = get_editor_interface().get_script_editor().get_current_editor().get_base_editor().syntax_highlighter
	_popup_dialog.raise(get_editor_interface().get_editor_scale())


func _input(event: InputEvent) -> void:
	_popup_trigger.input(event)
