@tool
class_name VivScenario
extends RefCounted
## A saved test setup (§5, §4.5): creature + seed + gravity + terrain + tunable overrides,
## persisted as JSON so scenarios survive restarts. capture()/apply() move between a live
## runner and a plain Dictionary; save()/load_from() persist it.

static func capture(runner: VivCreatureRunner, creature_path: String) -> Dictionary:
	var segs: Array = []
	var friction := 0.5
	if runner.terrain != null:
		friction = runner.terrain.friction
		for i in runner.terrain.size():
			var a := runner.terrain.seg_a[i]
			var b := runner.terrain.seg_b[i]
			segs.append([a.x, a.y, b.x, b.y])
	return {
		"creature": creature_path,
		"seed": runner.seed,
		"gravity": [runner.gravity.x, runner.gravity.y],
		"friction": friction,
		"segments": segs,
		"tunables": runner.tunables.duplicate(),
	}

static func apply(runner: VivCreatureRunner, scenario: Dictionary) -> void:
	var g: Array = scenario.get("gravity", [0.0, 40.0])
	runner.gravity = Vector2(g[0], g[1])
	var segs: Array = scenario.get("segments", [])
	if segs.size() > 0:
		var t := VivTerrain.new()
		t.friction = float(scenario.get("friction", 0.5))
		for s in segs:
			t.add_segment(Vector2(s[0], s[1]), Vector2(s[2], s[3]))
		runner.terrain = t
	else:
		runner.terrain = null
	var tn = scenario.get("tunables", {})
	runner.tunables = (tn as Dictionary).duplicate() if tn is Dictionary else {}

static func save(scenario: Dictionary, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(scenario, "\t"))
	f.close()
	return true

static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}
