@tool
class_name VivHerd
extends RefCounted
## Multi-instance: spawn N copies of a creature (seed = base_seed + i) to see variation and
## per-instance cost (§5). Each instance is an independent deterministic VivCreatureRunner.

static func spawn(path: String, count: int, base_seed: int, gravity: Vector2,
		terrain: VivTerrain) -> Array:
	var out: Array = []
	for i in count:
		var r := VivCreatureRunner.new()
		r.gravity = gravity
		r.terrain = terrain
		if r.load_script(path) and r.spawn(base_seed + i):
			out.append(r)
	return out

static func step_all(herd: Array, ticks: int) -> void:
	for r: VivCreatureRunner in herd:
		r.step(ticks)

## Total tick cost of one step across the herd, in microseconds (per-instance cost probe).
static func step_all_timed(herd: Array, ticks: int) -> float:
	var t0 := Time.get_ticks_usec()
	step_all(herd, ticks)
	return float(Time.get_ticks_usec() - t0)
