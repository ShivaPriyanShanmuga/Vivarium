extends SceneTree
## Phase 7 (part 1) — the agent tool surface (§6.2), tested end-to-end headless. The LLM
## critique loop (§6.3) is deferred (needs API keys + a VLM, best validated with the user).
## Run: godot --headless --path . --script res://test/phase7_harness.gd

const SERPENT := "res://creatures/serpent.gd"
const QUAD := "res://creatures/quadruped.gd"
const PROBE := "res://creatures/_tool_probe.gd"

func _initialize() -> void:
	var fails := 0
	fails += _t_read_write_diff()
	fails += _t_compile_gate()
	fails += _t_run_validate_measure()
	fails += _t_determinism_via_surface()
	fails += _t_diff_runs()
	print("PHASE7_TOOLS_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

# --- read / write(+diff) / accept / discard, never writing without accept ------
func _t_read_write_diff() -> int:
	var tools := VivTools.new()
	var src_a := "@tool\nextends \"res://runtime/viv_creature.gd\"\nfunc init(w):\n\tadd_chunk(Vector2(0,0))\n"
	# staging a write does not touch disk
	var d0 := tools.write_creature(PROBE, src_a)
	var staged_only: bool = not FileAccess.file_exists(PROBE) and d0["changed"]
	# accept writes it
	tools.accept_write(PROBE)
	var wrote := tools.read_creature(PROBE) == src_a
	# a change produces a hunk diff; discard leaves the file untouched
	var src_b := src_a.replace("Vector2(0,0)", "Vector2(5,0)")
	var d1 := tools.write_creature(PROBE, src_b)
	var has_hunk: bool = d1["diff"].contains("+ ") and d1["diff"].contains("- ")
	tools.discard_write(PROBE)
	var unchanged := tools.read_creature(PROBE) == src_a
	_rm(PROBE)
	var ok: bool = staged_only and wrote and has_hunk and unchanged
	print("[read/write]   stage-only:%s accept:%s diff-hunk:%s discard:%s" % [staged_only, wrote, has_hunk, unchanged])
	return 0 if ok else 1

# --- compile is the cheapest gate --------------------------------------------
func _t_compile_gate() -> int:
	var tools := VivTools.new()
	var good := tools.compile_creature(SERPENT)
	_write(PROBE, "@tool\nextends \"res://runtime/viv_creature.gd\"\nfunc init(w) this is broken\n")
	var bad := tools.compile_creature(PROBE)
	_rm(PROBE)
	var ok: bool = good["ok"] and not bad["ok"]
	print("[compile]      good:%s  broken-rejected:%s" % [good["ok"], not bad["ok"]])
	return 0 if ok else 1

# --- run -> validate -> measure ----------------------------------------------
func _t_run_validate_measure() -> int:
	var tools := VivTools.new()
	var terrain := VivTerrain.new()
	terrain.add_floor(40.0, -200.0, 1600.0); terrain.friction = 0.6
	var id := tools.run_scenario({"creature": QUAD, "seed": 1, "terrain": terrain}, 700)
	var findings := tools.validate(id)
	var m := tools.measure(id, ["foot_slide", "duty_factor", "distance", "hash"])
	var clean := findings.is_empty()
	var slide_ok: bool = float(m["foot_slide"]) < 0.5
	var moved: bool = float(m["distance"]) > 100.0
	var ok: bool = id > 0 and clean and slide_ok and moved and m["hash"] is String
	print("[run/measure]  id:%d clean:%s slide %.3f moved %.0f -> %s"
		% [id, clean, m["foot_slide"], m["distance"], ok])
	return 0 if ok else 1

# --- determinism through the surface -----------------------------------------
func _t_determinism_via_surface() -> int:
	var tools := VivTools.new()
	var a := tools.run_scenario({"creature": SERPENT, "seed": 3}, 300)
	var b := tools.run_scenario({"creature": SERPENT, "seed": 3}, 300)
	var ok: bool = tools.run_hash(a) == tools.run_hash(b)
	print("[determinism]  identical scenarios -> same hash: ", ok)
	return 0 if ok else 1

# --- diff_runs surfaces metric deltas ----------------------------------------
func _t_diff_runs() -> int:
	var tools := VivTools.new()
	var terrain := VivTerrain.new()
	terrain.add_floor(40.0, -200.0, 1600.0)
	var a := tools.run_scenario({"creature": QUAD, "seed": 1, "terrain": terrain}, 300)
	var b := tools.run_scenario({"creature": QUAD, "seed": 1, "terrain": terrain}, 700)
	var d := tools.diff_runs(a, b, ["distance"])
	var ok: bool = d.has("distance") and float(d["distance"]) > 0.0
	print("[diff_runs]    distance delta (700t vs 300t) %.0f > 0: %s" % [d.get("distance", 0.0), ok])
	return 0 if ok else 1

func _write(path: String, src: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(src); f.close()

func _rm(path: String) -> void:
	var dd := DirAccess.open(path.get_base_dir())
	if dd:
		dd.remove(path.get_file())
		if dd.file_exists(path.get_file() + ".uid"):
			dd.remove(path.get_file() + ".uid")
