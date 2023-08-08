extends Node

const Output = preload("res://addons/find-everywhere/src/windows/quick_open/output.gd")

## [param output] is ["addons/find-everywhere/src/windows/quick_open/output.gd"][br]Example:
## [codeblock]
##output.add_search_result({
##     "recent_id": "unique string id", # unique id in order to let quick_open sort items by recent usage
##     "score": 1.0 if search_text.to_lower() == item_name.to_lower() else 0.0, # float value. will be taken into account while sorting items
##     "fill_tree_item": func(item: TreeItem):
##          item.set_meta("on_activate", func():
##               # callback that is called every time the item is activated
##          )
##          item.set_meta("on_select", func():
##               # callback that is called every time the item is selected
##          )
##          item.set_meta("recent_id", "unique string id") # has to be duplicated 
##          item.set_text(0, "title")
##})
func update_search(search_text: String, output: Output):
	pass
