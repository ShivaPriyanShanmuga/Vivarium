extends SceneTree
## Phase 6 acceptance harness (§7, §9): a deliberately broken creature — flipped winding,
## NaN vertex, detached geometry, out-of-range index — is caught and precisely localized;
## a clean creature stays clean; motion metrics compute on a real gait.
## Run: godot --headless --path . --script res://test/phase6_harness.gd

const SERPENT := "res://creatures/serpent.gd"
const QUAD := "res://creatures/quadruped.gd"
const MUT := "res://creatures/_mut_probe.gd"

func _initialize() -> void:
	var fails := 0
	fails += _t_clean()
	fails += _t_nan()
	fails += _t_winding()
	fails += _t_detached()
	fails += _t_index_range()
	fails += _t_degenerate()
	fails += _t_bad_color()
	fails += _t_budget()
	fails += _t_draw_mutation()
	fails += _t_metrics()
	print("PHASE6_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

# --- clean creature produces no findings -------------------------------------
func _t_clean() -> int:
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40); r.load_script(SERPENT); r.spawn(1); r.step(200)
	var ctx := _draw(r)
	var f := VivValidators.validate(r.creature.chunks, ctx)
	var ok := f.is_empty()
	print("[clean]        serpent findings: ", VivValidators.summarize(f), " -> ", ok)
	return 0 if ok else 1

# --- NaN vertex --------------------------------------------------------------
func _t_nan() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"body", 0)
	ctx.mesh(&"body", PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(NAN, 5)]),
		PackedInt32Array([0, 1, 2]), _white(3))
	var f := VivValidators.validate([], ctx, 6000, 0.0)
	var ok := _has(f, "nan_vertex", "body", 2)
	print("[nan]          caught nan_vertex@body:2 -> ", ok)
	return 0 if ok else 1

# --- flipped winding ---------------------------------------------------------
func _t_winding() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"m", 0)
	var v := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	# tri 0 CCW, tri 1 reversed (CW) -> mixed winding in the layer
	ctx.mesh(&"m", v, PackedInt32Array([0, 1, 2, 0, 3, 2]), _white(4))
	var f := VivValidators.validate([], ctx, 6000, 0.0)
	var ok := _has(f, "winding", "m", -999)
	print("[winding]      caught mixed winding: ", ok)
	return 0 if ok else 1

# --- detached geometry -------------------------------------------------------
func _t_detached() -> int:
	var chunk := VivChunk.new(Vector2(0, 0), 2.0)
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"b", 0)
	ctx.mesh(&"b", PackedVector2Array([Vector2(1, 0), Vector2(2, 1), Vector2(9999, 0)]),
		PackedInt32Array([0, 1, 2]), _white(3))
	var f := VivValidators.validate([chunk], ctx, 6000, 70.0)
	var ok := _has(f, "detached", "b", 2)
	print("[detached]     caught detached@b:2 -> ", ok)
	return 0 if ok else 1

# --- index out of range ------------------------------------------------------
func _t_index_range() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"l", 0)
	ctx.mesh(&"l", PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 9)]),
		PackedInt32Array([0, 1, 5]), _white(3))  # 5 out of range
	var f := VivValidators.validate([], ctx, 6000, 0.0)
	var ok := _has(f, "index_range", "l", -999)
	print("[index]        caught out-of-range index: ", ok)
	return 0 if ok else 1

# --- degenerate triangle -----------------------------------------------------
func _t_degenerate() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"l", 0)
	ctx.mesh(&"l", PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)]),
		PackedInt32Array([0, 1, 2]), _white(3))  # colinear
	var f := VivValidators.validate([], ctx, 6000, 0.0)
	var ok := _has(f, "degenerate", "l", 0)
	print("[degenerate]   caught zero-area tri -> ", ok)
	return 0 if ok else 1

# --- bad color ---------------------------------------------------------------
func _t_bad_color() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"l", 0)
	ctx.mesh(&"l", PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(5, 9)]),
		PackedInt32Array([0, 1, 2]), PackedColorArray([Color(2.0, 0, 0), Color.WHITE, Color.WHITE]))
	var f := VivValidators.validate([], ctx, 6000, 0.0)
	var ok := _has(f, "bad_color", "l", 0)
	print("[bad-color]    caught out-of-range color -> ", ok)
	return 0 if ok else 1

# --- over budget -------------------------------------------------------------
func _t_budget() -> int:
	var ctx := VivDrawContext.new()
	ctx.declare_layer(&"l", 0)
	var v := PackedVector2Array()
	for i in 60:
		v.append(Vector2(i, 0))
	var tris := PackedInt32Array()
	for i in 20:
		tris.append_array(PackedInt32Array([i * 3, i * 3 + 1, i * 3 + 2]))
	ctx.mesh(&"l", v, tris, _white(60))
	var f := VivValidators.validate([], ctx, 10, 0.0)  # tiny budget
	var ok := _has(f, "budget", "", -999)
	print("[budget]       caught over-budget vertex count -> ", ok)
	return 0 if ok else 1

# --- draw() mutation detection ----------------------------------------------
func _t_draw_mutation() -> int:
	# clean creature is pure
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40); r.load_script(SERPENT); r.spawn(1); r.step(50)
	var pure := r.assert_draw_pure(VivDrawContext.new())
	# a creature whose draw() mutates a chunk is caught
	_write(MUT, "@tool\nextends \"res://runtime/viv_creature.gd\"\n" +
		"func init(w):\n\tadd_chunk(Vector2(0,0))\n" +
		"func draw(ctx, ts):\n\tchunks[0].pos.x += 1.0\n")
	var m := VivCreatureRunner.new()
	m.load_script(MUT, true); m.spawn(1); m.step(1)
	var caught := not m.assert_draw_pure(VivDrawContext.new())
	_rm(MUT)
	var ok: bool = pure and caught
	print("[draw-mut]     clean pure:%s  mutation caught:%s" % [pure, caught])
	return 0 if ok else 1

# --- motion metrics compute on a real gait -----------------------------------
func _t_metrics() -> int:
	var terrain := VivTerrain.new()
	terrain.add_floor(40.0, -200.0, 1600.0)
	terrain.friction = 0.6
	var r := VivCreatureRunner.new()
	r.terrain = terrain; r.load_script(QUAD); r.spawn(1); r.step(1)
	var q: Variant = r.creature
	var body: VivChunk = q.body
	var lm0: VivLimb = q.limbs[0]
	var xs := PackedFloat64Array()
	var planted := []
	var ys := PackedFloat64Array()
	for _t in 900:
		r.step(1)
		xs.append(lm0.foot.pos.x)
		planted.append(lm0.planted)
		ys.append(body.pos.y)
	var slide := VivMetrics.foot_slide(xs, planted)
	var duty := VivMetrics.duty_factor(planted)
	var steps := VivMetrics.step_count(planted)
	var freq := VivMetrics.stride_frequency(planted, VivSimClock.DT)
	var length := VivMetrics.stride_length(xs, planted)
	var bob := VivMetrics.com_oscillation(ys, 40)
	var ok: bool = slide < 0.5 and duty > 0.4 and duty < 0.9 and steps > 3 and length > 5.0 and is_finite(bob)
	print("[metrics]      slide %.3f duty %.2f steps %d freq %.2f/s stride %.1f bob %.2f -> %s"
		% [slide, duty, steps, freq, length, bob, ok])
	return 0 if ok else 1

# --- helpers -----------------------------------------------------------------
func _draw(r: VivCreatureRunner) -> VivDrawContext:
	var ctx := VivDrawContext.new()
	ctx.palette = VivPaletteRamps.default_creature()
	ctx.clear()
	r.creature.draw(ctx, 0.5)
	return ctx

func _white(n: int) -> PackedColorArray:
	var c := PackedColorArray()
	c.resize(n); c.fill(Color.WHITE)
	return c

func _has(findings: Array, kind: String, layer: String, index: int) -> bool:
	for f in findings:
		if f["kind"] == kind and (layer == "" or f["layer"] == layer) and (index == -999 or f["index"] == index):
			return true
	return false

func _write(path: String, src: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(src); f.close()

func _rm(path: String) -> void:
	var d := DirAccess.open(path.get_base_dir())
	if d:
		d.remove(path.get_file())
		if d.file_exists(path.get_file() + ".uid"):
			d.remove(path.get_file() + ".uid")
