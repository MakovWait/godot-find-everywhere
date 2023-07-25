@tool
extends VBoxContainer


@onready var _search_options: Tree = %SearchOptions
@onready var _code_edit: CodeEdit = %CodeEdit
@onready var _line_edit: LineEdit = $LineEdit


func _ready() -> void:
	_update_theme()
	theme_changed.connect(_update_theme)
	
	_code_edit.text = get_script().source_code
	_code_edit.draw_tabs = true
	_code_edit.gutters_draw_line_numbers = true
	_code_edit.scroll_smooth = true
	
	_search_options.hide_folding = true
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)


func _update_theme():
	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")
