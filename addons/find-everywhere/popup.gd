@tool
extends ConfirmationDialog

@onready var _header_container: HBoxContainer = %HeaderContainer
@onready var _tab_container: TabContainer = %TabContainer

var _prev_rect
var _tabs = {}


func _ready() -> void:
	visibility_changed.connect(func():
		if not visible:
			_prev_rect = Rect2i(position, size)
	)
	_tab_container.tabs_visible = false


func raise(edscale):
	if _prev_rect:
		popup(_prev_rect)
	else:
		popup_centered_clamped(Vector2(600, 440) * edscale, 0.8)


func add_tab(name, control):
	if name in _tabs:
		push_error("Tab %s is already registered" % name)
		return
	var tab_control = Control.new()
	tab_control.add_child(control)
	
	var tab_button = TabButton.new()
	tab_button.tab_container = _tab_container
	tab_button.tab_control = tab_control
	tab_button.text = name
	
	_tab_container.add_child(tab_control)
	_header_container.add_child(tab_button)
	
	_tabs[name] = {
		"control": tab_control,
		"button": tab_button
	}


func remove_tab(name):
	if not name in _tabs:
		push_error("Unknown tab %s" % name)
		return
	var clear_data = _tabs[name]
	clear_data["control"].queue_free()
	clear_data["button"].queue_free()


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
	
	func _get_tab_idx():
		return tab_container.get_tab_idx_from_control(tab_control)
