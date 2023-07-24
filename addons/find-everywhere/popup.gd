@tool
extends ConfirmationDialog


func _ready() -> void:
	var tree = $VBoxContainer/Tree
	tree.hide_folding = true
	tree.hide_root = true
	
	var root = tree.create_item()
	var item  = tree.create_item(root)
	item.set_text(0, "abc")

	item  = tree.create_item(root)
	item.set_text(0, "abc")

	item  = tree.create_item(root)
	item.set_text(0, "abc")

	item  = tree.create_item(root)
	item.set_text(0, "abc")

	item  = tree.create_item(root)
	item.set_text(0, "abc")
	tree.add_theme_constant_override("draw_guides", 1)
	
	$VBoxContainer/CodeEdit.text = get_script().source_code
	$VBoxContainer/CodeEdit.draw_tabs = true
	$VBoxContainer/CodeEdit.gutters_draw_line_numbers = true
	$VBoxContainer/CodeEdit.scroll_smooth = true


func raise(edscale):
#	$VBoxContainer/CodeEdit.syntax_highlighter = syntax_highlighter
	popup_centered_clamped(Vector2(600, 440) * edscale, 0.8)
