extends EditorPlugin

const FindEverywhere = preload("res://addons/find-everywhere/plugin.gd")


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	_handle_plugin_setup(_find_plugin())


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	get_tree().node_removed.disconnect(_on_node_removed)
	_handle_plugin_cleanup(_find_plugin())


func _on_node_added(node):
	if node is FindEverywhere:
		_handle_plugin_setup(node)


func _on_node_removed(node):
	if node is FindEverywhere:
		_handle_plugin_cleanup(node)


func _handle_plugin_setup(plugin):
	if plugin:
		_add_source_to(plugin)


func _handle_plugin_cleanup(plugin):
	if plugin:
		plugin.quick_open_remove_source(_get_src_name())


func _find_plugin() -> FindEverywhere:
	var ed_parent = get_editor_interface().get_parent()
	for node in ed_parent.get_children():
		if node is FindEverywhere:
			return node
	return null


func _add_source_to(plugin: FindEverywhere):
	pass


func _get_src_name():
	return ""
