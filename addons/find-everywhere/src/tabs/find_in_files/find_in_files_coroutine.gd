#https://github.com/godotengine/godot/blob/f6187014ec1d7a47b7201f64f3a8376a5da2f42d/editor/find_in_files.cpp
extends Node

signal result_found(fpath, line_number, begin, end, line)
signal finished

var search_text = ""
var match_case = false
var whole_words = false
var folder = ""
var extension_filter = []
var max_results_found = 20

var _current_dir = ""
var _folders_stack = []
var _files_to_scan = []
var _initial_files_count = 0
var _searching = false
var _results_found = 0


func _init() -> void:
	set_process(false)


func start():
	if search_text.is_empty():
		print_verbose("Nothing to search, pattern is empty")
		finished.emit()
	
	if len(extension_filter) == 0:
		print_verbose("Nothing to search, filter matches no files")
		finished.emit()
	
	_results_found = 0
	_current_dir = ""
	var init_folder = []
	init_folder.push_back(folder)
	_folders_stack.clear()
	_folders_stack.push_back(init_folder)

	_initial_files_count = 0

	_searching = true
	set_process(true)


func stop():
	_searching = false
	_current_dir = ""
	set_process(false)


func _process(delta: float) -> void:
	var time_before = Time.get_ticks_usec()
	while(is_processing()):
		_iterate()
		var elapsed = Time.get_ticks_usec() - time_before
		if elapsed > 8:
			break


func _iterate():
	if _folders_stack.size() != 0:
		# Scan folders first so we can build a list of files and have progress info later.

		var folders_to_scan = _folders_stack[_folders_stack.size() - 1]

		if folders_to_scan.size() != 0:
			# Scan one folder below.

			var folder_name = folders_to_scan[folders_to_scan.size() - 1]
			folders_to_scan.resize(len(folders_to_scan) - 1)

			_current_dir = _current_dir.path_join(folder_name)

			var sub_dirs = _scan_dir("res://" + _current_dir)

			_folders_stack.push_back(sub_dirs)

		else:
			# Go back one level.
			_folders_stack.resize(len(_folders_stack) - 1)
			_current_dir = _current_dir.get_base_dir()
			if _folders_stack.size() == 0:
				# All folders scanned.
				_initial_files_count = _files_to_scan.size()
	elif _files_to_scan.size() != 0:
		# Then scan files.

		var fpath = _files_to_scan[_files_to_scan.size() - 1]
		_files_to_scan.resize(len(_files_to_scan) - 1)
		_scan_file(fpath)

	else:
		print_verbose("Search complete")
		set_process(false)
		_current_dir = ""
		_searching = false
		finished.emit()


func _scan_dir(path):
	var out_folders = []
	var dir = DirAccess.open(path)
	if dir == null:
		print_verbose("Cannot open directory! " + path)
		return out_folders

	dir.list_dir_begin()
	for i in range(1000):
		var file = dir.get_next()

		if file.is_empty():
			break

		# If there is a .gdignore file in the directory, skip searching the directory.
		if file == ".gdignore":
			break

		# Ignore special directories (such as those beginning with . and the project data directory).
#		var project_data_dir_name = ProjectSettings.get_project_data_dir_name()
#		if file.begins_with(".") || file == project_data_dir_name:
		if file.begins_with("."):
			continue
#		if dir.current_is_hidden():
#			continue
		
		if dir.current_is_dir():
			out_folders.push_back(file)
		else:
			var file_ext = file.get_extension()
			if extension_filter.has(file_ext):
				_files_to_scan.push_back(path.path_join(file))
	return out_folders


func _scan_file(fpath):
	var f = FileAccess.open(fpath, FileAccess.READ)
	if f == null:
		print_verbose(String("Cannot open file ") + fpath)
		return

	var line_number = 0

	while not f.eof_reached():
		# Line number starts at 1.
		++line_number

		var begin = {'value': 0}
		var end = {'value': 0}

		var line = f.get_line()

#		while find_next(line, search_text, end, match_case, whole_words, begin, end):
		for _i in range(10000): 
			if find_next(line, search_text, end.value, match_case, whole_words, begin, end):
				result_found.emit(fpath, line_number, begin.value, end.value, line)
				_results_found += 1
				if _results_found >= max_results_found:
					return


static func find_next(line, pattern, from, match_case, whole_words, out_begin, out_end):
	var end = from

#	while true:
	for _i in range(10000):
		var begin = line.find(pattern, end) if match_case else line.findn(pattern, end)

		if begin == -1:
			return false

		end = begin + pattern.length()
		out_begin.value = begin
		out_end.value = end

		if whole_words:
			if begin > 0 && (is_ascii_identifier_char(line[begin - 1])):
				continue
			if end < len(line) && (is_ascii_identifier_char(line[end])):
				continue

		return true


static func is_ascii_identifier_char(c):
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'
