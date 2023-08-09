@tool
extends EditorPlugin

const FIND_IN_FILES_SH_SETTING_NAME = "addons/FindEverywhere/find_in_files_shortcut"
const QUICK_OPEN_DETECT_INPUT_MS = "addons/FindEverywhere/quick_open_detect_input_ms"
const QUICK_OPEN_IGNORE_INPUT_MS = "addons/FindEverywhere/quick_open_ignore_input_ms"

const DoubleClick = preload("res://addons/find-everywhere/src/triggers/double_click.gd")

var _popup_trigger
var _sh: Shortcut

var _find_in_files_popup
var _quick_open_popup


func _enter_tree() -> void:
	_load_name()
	_init_settings()
	_load_settings()
	get_editor_interface().get_editor_settings().settings_changed.connect(_load_settings)

	_find_in_files_popup = preload(
		"res://addons/find-everywhere/src/windows/find_in_files/link.gd"
	).get_find_in_files(get_editor_interface())
	
	_quick_open_popup = preload(
		"res://addons/find-everywhere/src/windows/quick_open/link.gd"
	).get_quick_open(get_editor_interface(), [])
	
	var base_control = get_editor_interface().get_base_control()
	base_control.add_child(_find_in_files_popup)
	base_control.add_child(_quick_open_popup)


func _exit_tree() -> void:
	_popup_trigger.triggered.disconnect(_show_popup)
	_quick_open_popup.queue_free()
	_find_in_files_popup.queue_free()


## [param src] should be a [Callable] or [Object] (see ["addons/find-everywhere/src/windows/quick_open/search_results_source_base.gd"])[br]
## [code]Note[/code]: if [param src] is [Node], it will be added to ["addons/find-everywhere/src/windows/quick_open/quick_open.gd"] as a child. 
func quick_open_add_source(src_name: String, src):
	_quick_open_popup.unwrap().add_search_results_source(src_name, src)


func quick_open_remove_source(src_name):
	_quick_open_popup.unwrap().remove_search_results_source(src_name)


## the next time ["addons/find-everywhere/src/windows/quick_open/quick_open.gd"] is raised, search results will be updated [br]
func quick_open_request_update_search():
	_quick_open_popup.unwrap().request_update_search()


func _shortcut_input(event: InputEvent) -> void:
	if _sh.matches_event(event):
		_find_in_files_popup.raise(get_editor_interface().get_editor_scale())


func _input(event: InputEvent) -> void:
	_popup_trigger.input(event)


func _show_popup():
#	var b = get_editor_interface().get_script_editor().get_current_editor().get_base_editor().syntax_highlighter
	_quick_open_popup.raise(get_editor_interface().get_editor_scale())


func _load_settings():
	var editor_settings = get_editor_interface().get_editor_settings()
	_sh = editor_settings.get_setting(FIND_IN_FILES_SH_SETTING_NAME)
	
	_popup_trigger = DoubleClick.new(
		KEY_SHIFT, 
		editor_settings.get_setting(QUICK_OPEN_DETECT_INPUT_MS), 
		editor_settings.get_setting(QUICK_OPEN_IGNORE_INPUT_MS)
	)
	_popup_trigger.triggered.connect(_show_popup)


func _init_settings():
	_init_ms_setting(QUICK_OPEN_DETECT_INPUT_MS, 200)
	_init_ms_setting(QUICK_OPEN_IGNORE_INPUT_MS, 120)
	var editor_settings = get_editor_interface().get_editor_settings()
	if not editor_settings.has_setting(FIND_IN_FILES_SH_SETTING_NAME):
		var sh = Shortcut.new()
		var ev = InputEventKey.new()
		ev.device = -1
		ev.shift_pressed = true
		if OS.has_feature("macos"):
			ev.ctrl_pressed = true
		else:
			ev.alt_pressed = true
		ev.keycode = 70
		sh.events = [ev]
		editor_settings.set_setting(FIND_IN_FILES_SH_SETTING_NAME, sh)
	editor_settings.add_property_info({
		"name": FIND_IN_FILES_SH_SETTING_NAME,
		"type": TYPE_OBJECT,
	})


func _init_ms_setting(setting_name, default_value):
	var editor_settings = get_editor_interface().get_editor_settings()
	if not editor_settings.has_setting(setting_name):
		editor_settings.set_setting(setting_name, default_value)
	editor_settings.add_property_info({
		"name": setting_name,
		"type": TYPE_INT,
	})


func _load_name():
	var cfg = ConfigFile.new()
	cfg.load("res://addons/find-everywhere/plugin.cfg")
	var cfg_name = cfg.get_value("plugin", "name")
	if cfg_name:
		name = cfg_name
