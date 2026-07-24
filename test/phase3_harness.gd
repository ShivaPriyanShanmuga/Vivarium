extends SceneTree
## Phase 3 headless harness — the non-visual half of the renderer acceptance (§4).
## (The shaded-look acceptance is judged from rendered PNGs, test/render_creature.gd.)
## Covers: render-clock interpolation, integer layer sort, generated-geometry validity,
## draw() purity on a real mesh creature, and deterministic snapshot / reverse-replay.
## Run: godot --headless --path . --script res://test/phase3_harness.gd

const SERPENT := "res://creatures/serpent.gd"

func _initialize() -> void:
	var fails := 0
	fails += _t_interpolation()
	fails += _t_layer_sort()
	fails += _t_geometry_valid()
	fails += _t_draw_pure()
	fails += _t_snapshot_replay()
	print("PHASE3_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

# --- render-clock interpolation: draw reads lerp(last, cur, ts) --------------
func _t_interpolation() -> int:
	var c := VivChunk.new(Vector2.ZERO, 1.0)
	c.last_pos = Vector2(0, 0)
	c.pos = Vector2(10, 20)
	var a := c.draw_pos(0.0).is_equal_approx(Vector2(0, 0))
	var b := c.draw_pos(1.0).is_equal_approx(Vector2(10, 20))
	var m := c.draw_pos(0.5).is_equal_approx(Vector2(5, 10))
	# store_last discipline through the runner: last == pre-tick pos
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40)
	r.load_script(SERPENT); r.spawn(1)
	var before: Vector2 = r.creature.chunks[3].pos
	r.step(1)
	var ch: VivChunk = r.creature.chunks[3]
	var disc: bool = ch.last_pos.is_equal_approx(before) and ch.draw_pos(1.0).is_equal_approx(ch.pos)
	var ok: bool = a and b and m and disc
	print("[interp]       endpoints:%s midpoint:%s store_last:%s" % [a and b, m, disc])
	return 0 if ok else 1

# --- integer layer sort (no depth buffer) ------------------------------------
func _t_layer_sort() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"body", 10)
	ctx.declare_layer(&"outline", 0)
	ctx.declare_layer(&"fx", 5)
	var order := ctx.layer_names_sorted()
	var ok: bool = order.size() == 3 and order[0] == &"outline" and order[1] == &"fx" and order[2] == &"body"
	print("[layer-sort]   ", order, " -> ", ok)
	return 0 if ok else 1

# --- generated geometry is valid (the §7 geometry validators, early) ---------
func _t_geometry_valid() -> int:
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40)
	r.load_script(SERPENT); r.spawn(1); r.step(300)
	var ctx := VivDrawContext.new()
	ctx.palette = VivPaletteRamps.default_creature()
	ctx.clear()
	r.creature.draw(ctx, 0.5)
	var finite := true
	var idx_ok := true
	var color_ok := true
	var degenerate := 0
	var tri_total := 0
	for name in ctx.layer_names_sorted():
		var pts := ctx.layer_points(name)
		var idx := ctx.layer_indices(name)
		var cols := ctx.layer_colors(name)
		for p in pts:
			if not p.is_finite():
				finite = false
		if idx.size() % 3 != 0:
			idx_ok = false
		for ii in idx:
			if ii < 0 or ii >= pts.size():
				idx_ok = false
		if cols.size() != pts.size():
			color_ok = false
		var tcount := idx.size() / 3
		for t in tcount:
			var a := pts[idx[t * 3]]
			var b := pts[idx[t * 3 + 1]]
			var c := pts[idx[t * 3 + 2]]
			var area := absf((b - a).cross(c - a)) * 0.5
			if area < 1e-4:
				degenerate += 1
			tri_total += 1
	var ok: bool = finite and idx_ok and color_ok and degenerate == 0 and tri_total > 0
	print("[geometry]     tris:%d finite:%s idx:%s colors:%s degenerate:%d -> %s"
		% [tri_total, finite, idx_ok, color_ok, degenerate, ok])
	return 0 if ok else 1

# --- draw() does not mutate sim state, even on a real mesh creature -----------
func _t_draw_pure() -> int:
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40)
	r.load_script(SERPENT); r.spawn(3); r.step(200)
	var ctx := VivDrawContext.new()
	ctx.palette = VivPaletteRamps.default_creature()
	var before := r.hash_state()
	ctx.clear(); r.creature.draw(ctx, 0.5)
	var ok := r.hash_state() == before
	print("[draw-pure]    serpent draw() leaves sim unchanged: ", ok)
	return 0 if ok else 1

# --- deterministic snapshot + reverse-replay (§4.4) --------------------------
func _t_snapshot_replay() -> int:
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40)
	r.load_script(SERPENT); r.spawn(2); r.step(100)
	var snap := r.snapshot()
	r.step(50)
	var forward := r.hash_state()
	r.restore(snap); r.step(50)
	var replayed := r.hash_state()
	var replay_ok := forward == replayed
	# reverse one-plus: restore then replay 49 must match a fresh run to 149
	var fresh := _run_hash(SERPENT, 2, 149)
	r.restore(snap); r.step(49)
	var reverse_ok := r.hash_state() == fresh
	var ok: bool = replay_ok and reverse_ok
	print("[replay]       replay==forward:%s  reverse==fresh:%s" % [replay_ok, reverse_ok])
	return 0 if ok else 1

func _run_hash(path: String, seed_value: int, ticks: int) -> String:
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40)
	r.load_script(path); r.spawn(seed_value); r.step(ticks)
	return r.hash_state()
