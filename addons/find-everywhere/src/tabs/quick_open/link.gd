static func get_quick_open(editor_interface: EditorInterface):
	var PopupBase = preload("res://addons/find-everywhere/src/popup_base.gd")
	var scene = preload(
		"res://addons/find-everywhere/src/tabs/quick_open/quick_open.tscn"
	).instantiate()
	scene.script = load(
		"res://addons/find-everywhere/src/tabs/quick_open/quick_open.gd"
	)
	scene.editor_interface = editor_interface
	var popup = PopupBase.new()
	popup.add_child(scene)
	return popup
