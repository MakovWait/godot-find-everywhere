extends ConfirmationDialog


var _prev_rect
var _origin


var block_auto_hide = false


func _ready() -> void:
	focus_exited.connect(func():
		if not block_auto_hide:
			self.hide()
	)
	visibility_changed.connect(func():
		if not visible:
			_prev_rect = Rect2i(position, size)
	)


func raise(edscale):
	if _prev_rect:
		popup(_prev_rect)
	else:
		popup_centered_clamped(Vector2(600, 800) * edscale, 0.8)


func set_origin(o):
	_origin = o
	add_child(o)


func unwrap():
	return _origin
