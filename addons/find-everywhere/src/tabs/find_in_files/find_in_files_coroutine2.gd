#https://github.com/godotengine/godot/blob/f6187014ec1d7a47b7201f64f3a8376a5da2f42d/editor/find_in_files.cpp
extends Node

signal result_found(fpath, line_number, begin, end, line)
signal finished

var search_text = ""
var match_case = false
var whole_words = false
var editor_filesystem: EditorFileSystem

var folder = "":
	set(value):
		if folder != value:
			_queued_to_rebuild_cache = true
		folder = value

var extension_filter = []:
	set(value):
		if extension_filter != value:
			_queued_to_rebuild_cache = true
		extension_filter = value

var _files = []
var _current_file_idx = 0
var _queued_to_rebuild_cache = true


func _ready() -> void:
	set_process(false)


func _on_filesystem_changed():
	_queued_to_rebuild_cache = true


func start():
	if not editor_filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		editor_filesystem.filesystem_changed.connect(_on_filesystem_changed)
	if search_text.is_empty():
		print_verbose("Nothing to search, pattern is empty")
		finished.emit()
		return
	
	if len(extension_filter) == 0:
		print_verbose("Nothing to search, filter matches no files")
		finished.emit()
		return
	
	if _queued_to_rebuild_cache:
		_files.clear()
		_build_search_cache(editor_filesystem.get_filesystem_path(folder))
		_queued_to_rebuild_cache = false
	
	_current_file_idx = 0
	set_process(true)


func stop():
	set_process(false)


func _process(delta: float) -> void:
	var time_before = Time.get_ticks_usec()
	while _current_file_idx < len(_files) and is_processing():
		_scan_file(_files[_current_file_idx])
		_current_file_idx += 1
		var elapsed = Time.get_ticks_usec() - time_before
		if elapsed > 8:
			return
	set_process(false)
	finished.emit()


func _build_search_cache(dir: EditorFileSystemDirectory):
	for i in dir.get_subdir_count():
		_build_search_cache(dir.get_subdir(i))

	for i in dir.get_file_count():
		var file = dir.get_file_path(i)
		var engine_type = dir.get_file_type(i)
#		var script_type = dir.get_file_resource_script_class(i)
#		var actual_type = script_type.is_empty() ? engine_type : script_type
		var actual_type = engine_type
		
		if file.get_extension() in ["gd", "gdshader", "tscn"]:
			_files.push_back(file)


func _scan_file(fpath):
	if not extension_filter.has(fpath.get_extension()):
		return
	var f = FileAccess.open(fpath, FileAccess.READ)
	if f == null:
		print_verbose(String("Cannot open file ") + fpath)
		return
	
	var iteration_start = Time.get_ticks_usec()
	var line_number = 0
	while f.get_position() < f.get_length():
		line_number += 1
		var line = f.get_line()
		_scan_line(fpath, line, line_number)


func _scan_line(fpath: String, line: String, line_number: int):
	var end = 0
	while true:
		var begin = line.find(search_text, end) if match_case else line.findn(search_text, end)

		if begin == -1:
			return

		end = begin + search_text.length()

		if whole_words:
			if begin > 0 && (is_ascii_identifier_char(line[begin - 1])):
				continue
			if end < len(line) && (is_ascii_identifier_char(line[end])):
				continue

		result_found.emit(fpath, line_number, begin, end, line)
		return


static func is_ascii_identifier_char(c: String) -> bool:
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'
