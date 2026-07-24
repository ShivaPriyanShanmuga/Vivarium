@tool
class_name VivCreatureRegistry
extends RefCounted
## Discovers creature programs — .gd scripts whose base-script chain includes VivCreature
## — in a watched directory (left rail in §5). Returns sorted entries so selection state
## and UI order are deterministic.

const CREATURE_BASE := preload("res://runtime/viv_creature.gd")

## Returns Array[Dictionary]: { path:String, name:String, script:GDScript }.
func discover(dir_res: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_res)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and f.get_extension() == "gd":
			var path := dir_res.path_join(f)
			var scr := load(path)
			if is_creature_script(scr):
				out.append({"path": path, "name": f.get_basename(), "script": scr})
		f = d.get_next()
	d.list_dir_end()
	out.sort_custom(func(a, b): return a["path"] < b["path"])
	return out

## True iff `scr` is a GDScript deriving from VivCreature (identity walk up the chain —
## robust to filename/class_name changes).
func is_creature_script(scr) -> bool:
	if not (scr is GDScript):
		return false
	var s: GDScript = scr
	while s != null:
		if s == CREATURE_BASE:
			return true
		s = s.get_base_script()
	return false
