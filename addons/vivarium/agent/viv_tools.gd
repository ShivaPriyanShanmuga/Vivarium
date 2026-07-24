@tool
class_name VivTools
extends RefCounted
## The agent / tool surface (§6.2) — the deterministic operations the AI (or a human) drives
## the code<->motion loop with. Everything here is headless-friendly except capture() which
## needs a GPU. Order matters and saves cost (§6.3): compile -> validate -> measure ->
## capture -> VLM. write_creature returns a diff for review and never touches disk until
## accept_write() (§6: the agent never writes project files without the diff being accepted).

var _runs: Dictionary = {}       # run_id -> { runner, rec, scenario }
var _next_run := 1
var _pending: Dictionary = {}    # path -> source awaiting accept

# ---------------------------------------------------------------- source

func read_creature(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)

## Stage a write and return a review diff. Nothing is written until accept_write().
func write_creature(path: String, source: String) -> Dictionary:
	var old := read_creature(path)
	_pending[path] = source
	return {"path": path, "diff": _diff(old, source), "changed": old != source}

func accept_write(path: String) -> bool:
	if not _pending.has(path):
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(_pending[path])
	f.close()
	_pending.erase(path)
	return true

func discard_write(path: String) -> void:
	_pending.erase(path)

# ---------------------------------------------------------------- runs

## Run a scenario and record series for metrics. Returns a run_id (or -1 on failure).
## scenario keys: creature (path), seed, terrain (VivTerrain|null), gravity (Vector2).
func run_scenario(scenario: Dictionary, ticks: int) -> int:
	var r := VivCreatureRunner.new()
	r.terrain = scenario.get("terrain", null)
	r.gravity = scenario.get("gravity", Vector2(0.0, 40.0))
	if not r.load_script(scenario["creature"]) or not r.spawn(int(scenario.get("seed", 1))):
		return -1
	var rec := _record(r, ticks)
	var id := _next_run
	_next_run += 1
	_runs[id] = {"runner": r, "rec": rec, "scenario": scenario}
	return id

func compile_creature(path: String) -> Dictionary:
	# Cheapest gate (§6.3): does it load + instantiate as a VivCreature?
	var r := VivCreatureRunner.new()
	var ok: bool = r.load_script(path, true) and r.spawn(1)
	return {"ok": ok, "path": path}

func validate(run_id: int) -> Array:
	var run = _runs.get(run_id)
	if run == null:
		return []
	var r: VivCreatureRunner = run["runner"]
	var ctx := VivDrawContext.new()
	ctx.palette = VivPaletteRamps.default_creature()
	ctx.clear()
	r.creature.draw(ctx, 0.0)
	return VivValidators.validate(r.creature.chunks, ctx)

func measure(run_id: int, names: Array) -> Dictionary:
	var run = _runs.get(run_id)
	if run == null:
		return {}
	var r: VivCreatureRunner = run["runner"]
	var rec: Dictionary = run["rec"]
	var out := {}
	for n in names:
		match n:
			"foot_slide": out[n] = VivMetrics.foot_slide(rec["foot_x"], rec["planted"])
			"duty_factor": out[n] = VivMetrics.duty_factor(rec["planted"])
			"stride_length": out[n] = VivMetrics.stride_length(rec["foot_x"], rec["planted"])
			"stride_frequency": out[n] = VivMetrics.stride_frequency(rec["planted"], VivSimClock.DT)
			"com_oscillation": out[n] = VivMetrics.com_oscillation(rec["body_y"], 40)
			"distance": out[n] = rec["distance"]
			"hash": out[n] = r.hash_state()
			_: out[n] = null
	return out

## Metric deltas b - a for the numeric metrics both runs report.
func diff_runs(a: int, b: int, names: Array) -> Dictionary:
	var ma := measure(a, names)
	var mb := measure(b, names)
	var d := {}
	for n in names:
		var va = ma.get(n)
		var vb = mb.get(n)
		if (va is float or va is int) and (vb is float or vb is int):
			d[n] = vb - va
	return d

func snapshot_run(run_id: int) -> Dictionary:
	return _runs[run_id]["runner"].snapshot()

func restore_run(run_id: int, snap: Dictionary) -> void:
	_runs[run_id]["runner"].restore(snap)

func run_hash(run_id: int) -> String:
	return _runs[run_id]["runner"].hash_state()

# ---------------------------------------------------------------- internals

func _record(r: VivCreatureRunner, ticks: int) -> Dictionary:
	var foot_x := PackedFloat64Array()
	var planted: Array = []
	var body_y := PackedFloat64Array()
	var limbs = r.creature.get("limbs")
	var body = r.creature.get("body")
	var start_x: float = r.creature.chunks[0].pos.x if r.creature.chunks.size() > 0 else 0.0
	for _t in ticks:
		r.step(1)
		if limbs != null and limbs.size() > 0:
			var lm: VivLimb = limbs[0]
			foot_x.append(lm.foot.pos.x)
			planted.append(lm.planted)
		elif r.creature.chunks.size() > 0:
			foot_x.append(r.creature.chunks[0].pos.x)
			planted.append(true)
		if body != null:
			body_y.append(body.pos.y)
		elif r.creature.chunks.size() > 0:
			body_y.append(r.creature.chunks[0].pos.y)
	var end_x: float = 0.0
	if body != null:
		end_x = body.pos.x
	elif r.creature.chunks.size() > 0:
		end_x = r.creature.chunks[0].pos.x
	return {"foot_x": foot_x, "planted": planted, "body_y": body_y, "distance": end_x - start_x}

## Single-hunk line diff (common prefix/suffix trimmed) for review.
func _diff(a_text: String, b_text: String) -> String:
	if a_text == b_text:
		return "(no changes)"
	var a := a_text.split("\n")
	var b := b_text.split("\n")
	var p := 0
	while p < a.size() and p < b.size() and a[p] == b[p]:
		p += 1
	var sa := a.size() - 1
	var sb := b.size() - 1
	while sa >= p and sb >= p and a[sa] == b[sb]:
		sa -= 1
		sb -= 1
	var out := "@@ -%d,%d +%d,%d @@\n" % [p + 1, sa - p + 1, p + 1, sb - p + 1]
	for i in range(p, sa + 1):
		out += "- " + a[i] + "\n"
	for i in range(p, sb + 1):
		out += "+ " + b[i] + "\n"
	return out
