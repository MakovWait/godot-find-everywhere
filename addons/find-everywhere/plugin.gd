@tool
extends EditorPlugin

const DoubleClick = preload("res://addons/find-everywhere/triggers/double_click.gd")
const PluginPopup: PackedScene = preload("res://addons/find-everywhere/popup.tscn")

var _popup_trigger
var _popup_dialog


func _enter_tree() -> void:
	_popup_trigger = DoubleClick.new(
		KEY_SHIFT, 300
	)
	_popup_trigger.triggered.connect(_show_popup)
	_popup_dialog = PluginPopup.instantiate()
	get_editor_interface().get_base_control().add_child(_popup_dialog)


func _exit_tree() -> void:
	_popup_trigger.triggered.disconnect(_show_popup)
	_popup_dialog.queue_free()


func _show_popup():
#	var b = get_editor_interface().get_script_editor().get_current_editor().get_base_editor().syntax_highlighter
	_popup_dialog.raise(get_editor_interface().get_editor_scale())


func _input(event: InputEvent) -> void:
	_popup_trigger.input(event)
