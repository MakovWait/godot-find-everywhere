@tool
extends ConfirmationDialog

@onready var _header_container: HBoxContainer = %HeaderContainer
@onready var _tab_container: TabContainer = %TabContainer

var _prev_rect
var _tabs = {}

var _prev_tab_idx = null


func _ready() -> void:
	visibility_changed.connect(func():
		if visible:
			_handle_tab_changed(_tab_container.current_tab)
		if not visible:
			_prev_rect = Rect2i(position, size)
	)
	
	_tab_container.tabs_visible = false
	_tab_container.tab_changed.connect(_handle_tab_changed)


func raise(edscale):
	if _prev_rect:
		popup(_prev_rect)
	else:
		popup_centered_clamped(Vector2(600, 440) * edscale, 0.8)


func add_tab(name, control):
	if name in _tabs:
		push_error("Tab %s is already registered" % name)
		return
	
#	var tab_control = Control.new()
#	tab_control.add_child(control)
	var tab_control = control
	var tab_button = TabButton.new()
	tab_button.tab_container = _tab_container
	tab_button.tab_control = tab_control
	tab_button.text = name
	
	_tab_container.add_child(tab_control)
	_header_container.add_child(tab_button)
	
	_call_lifecycle_method(tab_control, "_tab_setup", [self])
	
	_tabs[name] = {
		"tab_idx": _tab_container.get_tab_idx_from_control(tab_control),
		"tab_control": tab_control,
		"tab_button": tab_button,
	}


func remove_tab(name):
	if not name in _tabs:
		push_error("Unknown tab %s" % name)
		return
	
	var clear_data = _tabs[name]
	clear_data["tab_control"].queue_free()
	clear_data["tab_button"].queue_free()
	_tabs.erase(name)


func _handle_tab_changed(idx):
	var prev_tab = _find_tab_control_by_idx(_prev_tab_idx)
	var current_tab = _find_tab_control_by_idx(idx)
	
	_call_lifecycle_method(prev_tab, "_tab_blur")
	_call_lifecycle_method(current_tab, "_tab_focus")
	
	_prev_tab_idx = idx


func _find_tab_control_by_idx(idx):
	if idx == null:
		return null
	for value in _tabs.values():
		if value.tab_idx == idx:
			return value.tab_control
	return null


func _call_lifecycle_method(obj, method_name, args=[]):
	if obj == null:
		return
	if obj.has_method(method_name):
		obj.callv(method_name, args)


class TabButton extends Button:
	var tab_container: TabContainer
	var tab_control: Control
	
	func _ready() -> void:
		flat = true
		toggle_mode = true
		add_to_group("header_tab_button")
		
		pressed.connect(func():
			get_tree().set_group("header_tab_button", "button_pressed", false)
			set_pressed_no_signal(true)
			tab_container.current_tab = _get_tab_idx()
		)
	
		if tab_container.current_tab == _get_tab_idx():
			set_pressed_no_signal(true)
		
#		add_theme_font_override("font", get_theme_font("main_button_font", "EditorFonts"))
#		add_theme_font_size_override("font_size", get_theme_font_size("main_button_font_size", "EditorFonts"))
	
	func _get_tab_idx():
		return tab_container.get_tab_idx_from_control(tab_control)
