extends RefCounted

signal triggered

var _trigger_key: Key
var _ms_detect_input: int
var _ms_ignore_input: int

var _last_time_trigger_key_pressed: int
var _trigger_key_was_pressed: bool = false


func _init(trigger_key: Key, ms_detect_input: int, ms_ignore_input) -> void:
	self._trigger_key = trigger_key
	self._ms_detect_input = ms_detect_input
	self._ms_ignore_input = ms_ignore_input


func input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.keycode == _trigger_key:
			_trigger_key_was_pressed = false
		if key_event.keycode == _trigger_key and key_event.is_pressed():
			var delta_time = Time.get_ticks_msec() - _last_time_trigger_key_pressed
			if _trigger_key_was_pressed and delta_time > _ms_ignore_input and delta_time < _ms_detect_input:
				_trigger_key_was_pressed = false
				triggered.emit()
			else:
				_trigger_key_was_pressed = true
				_last_time_trigger_key_pressed = Time.get_ticks_msec()
