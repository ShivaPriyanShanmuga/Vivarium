extends SceneTree
## Phase 1 acceptance harness (master-prompt §9).
##   ACCEPT: editing a creature source file respawns it in under 300 ms;
##           identical seeds hash identically.
## Run: godot --headless --path . --script res://test/phase1_harness.gd

const BLOB := "res://creatures/test_blob.gd"
const CREATURES_DIR := "res://creatures"
const PROBE := "res://creatures/_reload_probe.gd"
const PROBE_W := "res://creatures/_watch_probe.gd"

const RESPAWN_BUDGET_MS := 300.0

func _initialize() -> void:
	var fails := 0
	fails += _t_determinism()
	fails += _t_seed_sensitivity()
	fails += _t_trace_determinism()
	fails += _t_draw_purity()
	fails += _t_reload_reflects_edit_and_timing()
	fails += _t_watcher_detects_change()
	fails += _t_registry()
	print("PHASE1_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

# --- same seed -> same hash --------------------------------------------------
func _t_determinism() -> int:
	var h1 := _run(BLOB, 7, 500)
	var h2 := _run(BLOB, 7, 500)
	var ok := h1 == h2
	print("[determinism]  seed 7 x500 ticks  h1==h2: ", ok, "  h=", h1.substr(0, 16))
	return 0 if ok else 1

# --- different seed -> different hash (RNG actually feeds the sim) ------------
func _t_seed_sensitivity() -> int:
	var h1 := _run(BLOB, 7, 500)
	var h3 := _run(BLOB, 8, 500)
	var ok := h1 != h3
	print("[seed-sens]    seed 7 vs 8         differ: ", ok)
	return 0 if ok else 1

# --- full per-tick hash traces are identical across independent runs ---------
func _t_trace_determinism() -> int:
	var a := VivCreatureRunner.new(); a.load_script(BLOB); a.spawn(42)
	var b := VivCreatureRunner.new(); b.load_script(BLOB); b.spawn(42)
	var ok := true
	for i in 300:
		a.step(1); b.step(1)
		if a.hash_state() != b.hash_state():
			ok = false; print("    trace diverged at tick ", i); break
	print("[trace-det]    300-tick traces identical: ", ok)
	return 0 if ok else 1

# --- draw() must not mutate sim state (§2) -----------------------------------
func _t_draw_purity() -> int:
	var r := VivCreatureRunner.new(); r.load_script(BLOB); r.spawn(3); r.step(100)
	var ok: bool = r.assert_draw_pure(VivDrawContext.new())
	print("[draw-purity]  draw() leaves state unchanged: ", ok)
	return 0 if ok else 1

# --- reload picks up an on-disk edit, under the 300 ms budget -----------------
func _t_reload_reflects_edit_and_timing() -> int:
	_write(PROBE, _probe_src(2))
	var r := VivCreatureRunner.new()
	if not r.load_script(PROBE, true) or not r.spawn(1):
		print("[reload]       FAILED to load/spawn probe v1"); _rm(PROBE); return 1
	var n1 := r.creature.chunks.size()
	# Edit the file on disk, then reload+respawn and time it.
	_write(PROBE, _probe_src(4))
	var ms := r.reload_and_respawn()
	var n2 := r.creature.chunks.size()
	_rm(PROBE)
	var reflects := n1 == 2 and n2 == 4
	var in_budget := ms < RESPAWN_BUDGET_MS
	print("[reload]       edit 2->4 chunks reflected: ", reflects,
		"  respawn=%.1f ms (<%d): " % [ms, int(RESPAWN_BUDGET_MS)], in_budget)
	return 0 if (reflects and in_budget) else 1

# --- watcher detects a changed file ------------------------------------------
func _t_watcher_detects_change() -> int:
	_write(PROBE_W, _probe_src(2))
	var w := VivFileWatcher.new()
	w.set_dir(CREATURES_DIR)   # baseline (probe present)
	var hits := {"changed": false}
	w.file_changed.connect(func(p): if p == PROBE_W: hits["changed"] = true)
	# get_modified_time is second-granularity; cross a second boundary so the edit shows.
	OS.delay_msec(1100)
	_write(PROBE_W, _probe_src(3))
	w.poll()
	_rm(PROBE_W)
	var ok: bool = hits["changed"]
	print("[watcher]      poll detects changed file: ", ok)
	return 0 if ok else 1

# --- registry discovers creatures, rejects non-creatures ---------------------
func _t_registry() -> int:
	var reg := VivCreatureRegistry.new()
	var found := reg.discover(CREATURES_DIR)
	var has_blob := false
	for e in found:
		if e["path"] == BLOB: has_blob = true
	var rejects_rng: bool = not reg.is_creature_script(load("res://runtime/viv_rng.gd"))
	var ok := has_blob and rejects_rng
	print("[registry]     found test_blob: ", has_blob, "  rejects non-creature: ", rejects_rng)
	return 0 if ok else 1

# --- helpers -----------------------------------------------------------------
func _run(path: String, seed_value: int, ticks: int) -> String:
	var r := VivCreatureRunner.new()
	r.load_script(path); r.spawn(seed_value); r.step(ticks)
	return r.hash_state()

func _probe_src(chunk_count: int) -> String:
	return "@tool\nextends \"res://runtime/viv_creature.gd\"\n" + \
		"func init(w):\n\tfor i in %d:\n\t\tadd_chunk(Vector2(float(i), 0.0))\n" % chunk_count + \
		"func tick(dt):\n\tfor c in chunks:\n\t\tc.pos += Vector2(0.0, dt)\n"

func _write(res_path: String, src: String) -> void:
	var f := FileAccess.open(res_path, FileAccess.WRITE)
	f.store_string(src)
	f.close()

func _rm(res_path: String) -> void:
	var d := DirAccess.open(res_path.get_base_dir())
	if d:
		d.remove(res_path.get_file())
		if d.file_exists(res_path.get_file() + ".uid"):
			d.remove(res_path.get_file() + ".uid")
