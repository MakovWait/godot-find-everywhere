static func get_quick_open(editor_interface: EditorInterface):
	var scene = preload(
		"res://addons/find-everywhere/src/tabs/quick_open/quick_open.tscn"
	).instantiate()
	scene.script = load(
		"res://addons/find-everywhere/src/tabs/quick_open/quick_open.gd"
	)
	scene.editor_interface = editor_interface
	return scene
