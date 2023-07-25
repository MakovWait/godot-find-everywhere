static func get_find_in_files(editor_interface: EditorInterface):
	var scene = preload(
		"res://addons/find-everywhere/src/tabs/find_in_files/find_in_files.tscn"
	).instantiate()
	scene.script = load(
		"res://addons/find-everywhere/src/tabs/find_in_files/find_in_files.gd"
	)
	scene.editor_interface = editor_interface
	return scene
