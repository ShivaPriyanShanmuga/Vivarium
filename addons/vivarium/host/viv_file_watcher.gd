@tool
class_name VivFileWatcher
extends RefCounted
## Polls modification times of *.gd files under a directory and emits change signals.
##
## A poll-based watcher (rather than the editor's own filesystem signals) so it works on
## any directory the tool is pointed at, and so change detection is explicit and testable
## (§1 hot reload). File lists are sorted for deterministic iteration.

signal file_added(res_path: String)
signal file_changed(res_path: String)
signal file_removed(res_path: String)

var dir_res := ""
var _mtimes: Dictionary = {}   # res_path -> int (unix mtime)

## Point the watcher at a directory and take a baseline (no signals emitted).
func set_dir(res_dir: String) -> void:
	dir_res = res_dir
	_mtimes.clear()
	for f in list_scripts():
		_mtimes[f] = _mtime(f)

## Sorted list of *.gd paths directly under dir_res.
func list_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir_res)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.get_extension() == "gd":
			out.append(dir_res.path_join(f))
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

## Compare current mtimes to the baseline; emit added/changed/removed.
func poll() -> void:
	var seen := {}
	for f in list_scripts():
		seen[f] = true
		var mt := _mtime(f)
		if not _mtimes.has(f):
			_mtimes[f] = mt
			file_added.emit(f)
		elif _mtimes[f] != mt:
			_mtimes[f] = mt
			file_changed.emit(f)
	for f in _mtimes.keys():
		if not seen.has(f):
			_mtimes.erase(f)
			file_removed.emit(f)

func _mtime(res_path: String) -> int:
	# FileAccess.get_modified_time needs an absolute path (VERIFIED, Godot 4.7).
	return FileAccess.get_modified_time(ProjectSettings.globalize_path(res_path))
