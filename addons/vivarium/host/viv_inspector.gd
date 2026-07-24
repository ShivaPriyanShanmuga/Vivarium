@tool
class_name VivInspector
extends RefCounted
## Reads a creature's @export_range vars as live tunables (§5 inspector): any such field
## becomes a control that edits the running instance without a reload. Tunables are the
## float/int properties carrying a RANGE hint, so plain internal vars are excluded.

## Array of { name, value, min, max, step } for each @export_range tunable.
static func list_tunables(creature) -> Array:
	var out: Array = []
	if creature == null:
		return out
	for p in creature.get_property_list():
		if int(p.get("hint", 0)) != PROPERTY_HINT_RANGE:
			continue
		var t := int(p["type"])
		if t != TYPE_FLOAT and t != TYPE_INT:
			continue
		var name := String(p["name"])
		var mn := 0.0
		var mx := 1.0
		var step := 0.01
		var parts := String(p.get("hint_string", "0,1")).split(",")
		if parts.size() >= 2:
			mn = float(parts[0]); mx = float(parts[1])
		if parts.size() >= 3:
			step = float(parts[2])
		out.append({"name": name, "value": creature.get(name), "min": mn, "max": mx, "step": step})
	return out

static func set_tunable(creature, name: String, value) -> void:
	if creature != null and name in creature:
		creature.set(name, value)
