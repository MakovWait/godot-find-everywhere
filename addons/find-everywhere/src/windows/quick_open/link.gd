static func get_quick_open(
	editor_interface: EditorInterface, 
	search_sources_to_add: Array
):
	var PopupBase = preload("res://addons/find-everywhere/src/popup_base.gd")
	var scene = preload(
		"res://addons/find-everywhere/src/windows/quick_open/quick_open.tscn"
	).instantiate()
	scene.script = load(
		"res://addons/find-everywhere/src/windows/quick_open/quick_open.gd"
	)
	scene.editor_interface = editor_interface
	scene.search_sources_to_add = search_sources_to_add
	var popup = PopupBase.new()
	popup.set_origin(scene)
	return popup
