static func get_find_in_files(editor_interface: EditorInterface):
	var PopupBase = preload("res://addons/find-everywhere/src/popup_base.gd")
	var scene = preload(
		"res://addons/find-everywhere/src/windows/find_in_files/find_in_files.tscn"
	).instantiate()
	scene.script = load(
		"res://addons/find-everywhere/src/windows/find_in_files/find_in_files.gd"
	)
	scene.editor_interface = editor_interface
	var popup = PopupBase.new()
	popup.set_origin(scene)
	return popup
