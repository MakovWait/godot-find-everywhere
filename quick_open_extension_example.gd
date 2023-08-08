@tool
extends "res://addons/find-everywhere/src/quick_open_extension_base.gd"


func _add_source_to(plugin: FindEverywhere):
	plugin.quick_open_add_source(_get_src_name(), _update_search)


func _get_src_name():
	return "test"


func _update_search(search_text: String, output):
	var item_id = "test_item::run_current_scene"
	var item_name = "Run current scene"
	if not output.is_reached_max_results():
		output.add_search_result({
			"recent_id": item_id, # unique id in order to let quick_open sort items by recent usage
			"score": search_text.similarity(item_name), # float value. will be taken into account while sorting items
			"fill_tree_item": func(item: TreeItem):
				item.set_meta("on_activate", func():
					# callback that is called every time the item is activated
					get_editor_interface().play_current_scene()
				)
				item.set_meta("on_select", func():
					# callback that is called every time the item is selected
					pass
				)
				item.set_meta("recent_id", item_id) # has to be duplicated 
				item.set_text(0, "Run current scene")
		})
