extends SceneTree
## Phase 4 acceptance harness (§9): a quadruped crosses uneven terrain with foot slide
## under 0.5 px, no penetration, no hovering.
## Run: godot --headless --path . --script res://test/phase4_harness.gd

const QUAD := "res://creatures/quadruped.gd"
const TICKS := 2400

func _initialize() -> void:
	var fails := 0
	fails += _t_gait()
	fails += _t_determinism()
	fails += _t_ik()
	print("PHASE4_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

func _t_ik() -> int:
	# knee is thigh from hip and shin from foot; reachable + overextended both finite
	var hip := Vector2(0, 0)
	var target := Vector2(10, 18)
	var kn := VivIK.solve_two_bone(hip, target, 14.0, 14.0, 1.0)
	var d1 := hip.distance_to(kn)
	var d2 := kn.distance_to(target)
	var reach_ok: bool = absf(d1 - 14.0) < 0.5 and absf(d2 - 14.0) < 0.5
	var over := VivIK.solve_two_bone(hip, Vector2(100, 0), 14.0, 14.0, 1.0)  # unreachable
	var finite_ok := over.is_finite()
	var ok: bool = reach_ok and finite_ok
	print("[ik]           reachable bones exact:%s  overextend finite:%s" % [reach_ok, finite_ok])
	return 0 if ok else 1

func _t_gait() -> int:
	var terrain := _uneven()
	var r := VivCreatureRunner.new()
	r.terrain = terrain
	r.load_script(QUAD)
	r.spawn(1)
	var q: Variant = r.creature
	r.step(1)  # let legs self-init on the ground
	var body: VivChunk = q.body

	var n: int = q.limbs.size()
	var planted_prev := []
	var imin := []
	var imax := []
	var steps := []
	for i in n:
		var l0: VivLimb = q.limbs[i]
		planted_prev.append(l0.planted)
		imin.append(l0.foot.pos.x)
		imax.append(l0.foot.pos.x)
		steps.append(0)

	var slide_max := 0.0
	var pen_max := -1e30
	var hover_max := 0.0
	var body_err_max := 0.0
	var finite := true
	var start_x := body.pos.x

	for _t in TICKS:
		r.step(1)
		if not body.pos.is_finite():
			finite = false
		# body follows ground (after an initial settle)
		if _t > 200:
			var bgy := terrain.ground_y(body.pos.x, body.pos.y - 150.0)
			if bgy < INF:
				body_err_max = maxf(body_err_max, absf(body.pos.y - (bgy - 22.0)))
		for i in n:
			var lm: VivLimb = q.limbs[i]
			var fx: float = lm.foot.pos.x
			if not lm.foot.pos.is_finite():
				finite = false
			if lm.planted:
				if planted_prev[i]:
					imin[i] = minf(imin[i], fx); imax[i] = maxf(imax[i], fx)
				else:
					imin[i] = fx; imax[i] = fx  # just landed
			else:
				if planted_prev[i]:
					slide_max = maxf(slide_max, imax[i] - imin[i])  # close a stance interval
					steps[i] += 1
			# penetration / ground contact
			var gy := terrain.ground_y(fx, lm.foot.pos.y - 40.0)
			if gy < INF:
				pen_max = maxf(pen_max, lm.foot.pos.y - gy)  # +y down: >0 means below ground
				if lm.planted:
					hover_max = maxf(hover_max, absf(lm.foot.pos.y - gy))
			planted_prev[i] = lm.planted

	var advanced := body.pos.x - start_x
	var min_steps := 1000000
	for s in steps:
		min_steps = mini(min_steps, s)

	var slide_ok: bool = slide_max < 0.5
	var pen_ok: bool = pen_max < 1.5
	var hover_ok: bool = hover_max < 3.5
	var body_ok: bool = body_err_max < 9.0
	var moved_ok: bool = advanced > 300.0
	var stepped_ok: bool = min_steps >= 3
	var ok: bool = finite and slide_ok and pen_ok and hover_ok and body_ok and moved_ok and stepped_ok
	print("[gait]         slide %.4f(<0.5):%s pen %.3f(<1.5):%s hover %.3f(<3.5):%s"
		% [slide_max, slide_ok, pen_max, pen_ok, hover_max, hover_ok])
	print("               body_err %.3f(<9):%s advanced %.0f(>300):%s min_steps %d(>=3):%s finite:%s"
		% [body_err_max, body_ok, advanced, moved_ok, min_steps, stepped_ok, finite])
	return 0 if ok else 1

func _t_determinism() -> int:
	var h1 := _run(4)
	var h2 := _run(4)
	var ok: bool = h1 == h2
	print("[det-gait]     seed 4 x800 gait ticks  h1==h2: ", ok)
	return 0 if ok else 1

func _run(seed_value: int) -> String:
	var r := VivCreatureRunner.new()
	r.terrain = _uneven()
	r.load_script(QUAD); r.spawn(seed_value); r.step(800)
	return r.hash_state()

func _uneven() -> VivTerrain:
	var t := VivTerrain.new()
	t.friction = 0.6
	var pts := [
		Vector2(-120, 40), Vector2(70, 40), Vector2(140, 22), Vector2(210, 28),
		Vector2(280, 58), Vector2(360, 52), Vector2(430, 30), Vector2(520, 36),
		Vector2(640, 20), Vector2(760, 44), Vector2(900, 40), Vector2(1600, 40),
	]
	for i in pts.size() - 1:
		t.add_segment(pts[i], pts[i + 1])
	return t
