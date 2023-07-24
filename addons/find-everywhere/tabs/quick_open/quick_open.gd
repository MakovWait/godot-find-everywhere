@tool
extends VBoxContainer

@onready var _line_edit: LineEdit = $LineEdit
@onready var _search_options: Tree = $SearchOptions


func _ready() -> void:
	_update_theme()
	theme_changed.connect(_update_theme)
	
	_search_options.hide_folding = true
	_search_options.hide_root = true
	_search_options.add_theme_constant_override("draw_guides", 1)


func _update_theme():
	_line_edit.right_icon = get_theme_icon("Search", "EditorIcons")
