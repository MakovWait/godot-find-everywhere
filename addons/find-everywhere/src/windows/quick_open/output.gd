extends RefCounted

var _delegate

func _init(delegate) -> void:
	_delegate = delegate


## item is a [Dictionary] with entries:[br]
##[br][param recent_id]: [String] - unique id in order to let quick_open sort items by recent usage
##[br][param score]: [float] - will be taken into account while sorting items
##[br][param fill_tree_item]: [Callable]
## [codeblock]
##     "fill_tree_item": func(item: TreeItem):
##          item.set_meta("on_activate", func():
##               # callback that is called every time the item is activated
##          )
##          item.set_meta("on_select", func():
##               # callback that is called every time the item is selected
##          )
##          item.set_meta("recent_id", "unique string id") # has to be duplicated with the item field
##          item.set_text(0, "title")
## [/codeblock]
func add_search_result(item: Dictionary):
	_delegate.add_search_result(item)


func is_reached_max_results() -> bool:
	return _delegate.is_reached_max_results()
