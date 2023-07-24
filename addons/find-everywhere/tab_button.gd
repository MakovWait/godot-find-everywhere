@tool
extends Button

@export var _tab_container: TabContainer
@export var _tab_control: Control


func _ready() -> void:
	pressed.connect(func():
		get_tree().set_group("header_tab_button", "button_pressed", false)
		button_pressed = true
		_tab_container.current_tab = _tab_container.get_tab_idx_from_control(
			_tab_control
		)
	)
	
	flat = true
	toggle_mode = true
	add_to_group("header_tab_button")
