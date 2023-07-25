@tool
extends EditorPlugin

const DoubleClick = preload("res://addons/find-everywhere/src/triggers/double_click.gd")
const PluginPopup: PackedScene = preload("res://addons/find-everywhere/src/popup.tscn")

var _popup_trigger
var _popup_dialog


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
	_popup_dialog.add_tab("Find", find_in_files)


func _exit_tree() -> void:
	_popup_trigger.triggered.disconnect(_show_popup)
	_popup_dialog.queue_free()


func _show_popup():
#	var b = get_editor_interface().get_script_editor().get_current_editor().get_base_editor().syntax_highlighter
	_popup_dialog.raise(get_editor_interface().get_editor_scale())


func _input(event: InputEvent) -> void:
	_popup_trigger.input(event)
