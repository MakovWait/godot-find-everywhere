extends ConfirmationDialog


var _prev_rect


func _ready() -> void:
	visibility_changed.connect(func():
		if not visible:
			_prev_rect = Rect2i(position, size)
	)


func raise(edscale):
	if _prev_rect:
		popup(_prev_rect)
	else:
		popup_centered_clamped(Vector2(600, 440) * edscale, 0.8)
