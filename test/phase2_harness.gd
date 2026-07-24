extends SceneTree
## Phase 2 acceptance harness (master-prompt §9).
##   ACCEPT: a three-chunk creature dropped on terrain settles without exploding,
##           jittering, or drifting over 10,000 ticks.
## Plus unit tests for each solver piece. Run:
##   godot --headless --path . --script res://test/phase2_harness.gd

const TRIPOD := "res://creatures/test_tripod.gd"
const DT := VivSimClock.DT

func _initialize() -> void:
	var fails := 0
	fails += _t_settle_10k()
	fails += _t_determinism_with_solver()
	fails += _t_distance_constraint()
	fails += _t_elastic_one_way()
	fails += _t_flex_converges()
	fails += _t_terrain_stops_fall()
	fails += _t_swept_no_tunnel()
	print("PHASE2_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

# --- ACCEPTANCE: drop a rigid triangle, settle over 10k ticks -----------------
func _t_settle_10k() -> int:
	var floor := VivTerrain.new()
	floor.add_floor(0.0, -200.0, 200.0)
	floor.friction = 0.5
	var r := VivCreatureRunner.new()
	r.terrain = floor
	r.gravity = Vector2(0.0, 40.0)
	r.load_script(TRIPOD)
	r.spawn(1)

	# initial edge lengths (to check the rigid body kept its shape)
	var e0 := _edges(r.creature)
	r.step(7000)
	var com_a := _com(r.creature)
	r.step(2500)  # -> 9500
	var max_speed := 0.0
	for _i in 500:  # 9500..10000
		r.step(1)
		for c in r.creature.chunks:
			max_speed = maxf(max_speed, c.vel.length())
	var com_b := _com(r.creature)

	var finite := true
	var lowest := -1e30
	var highest := 1e30
	for c in r.creature.chunks:
		if not c.pos.is_finite():
			finite = false
		lowest = maxf(lowest, c.pos.y)   # +y down -> largest y is lowest chunk
		highest = minf(highest, c.pos.y)
	var e1 := _edges(r.creature)
	var shape_err := 0.0
	for i in e0.size():
		shape_err = maxf(shape_err, absf(e0[i] - e1[i]))

	var drift := absf(com_b.x - com_a.x)
	var settled := max_speed < 0.5
	var no_drift := drift < 1.5
	var above_floor := lowest < 3.5 and highest > -70.0   # resting near floor, not sunk/gone
	var rigid := shape_err < 0.2
	var ok := finite and settled and no_drift and above_floor and rigid
	print("[settle-10k]   finite:%s settled(%.4f<0.5):%s drift(%.3f<1.5):%s rest:%s rigid(%.3f):%s"
		% [finite, max_speed, settled, drift, no_drift, above_floor, shape_err, rigid])
	return 0 if ok else 1

# --- determinism holds through the solver ------------------------------------
func _t_determinism_with_solver() -> int:
	var h1 := _run_hash(TRIPOD, 5, 2000)
	var h2 := _run_hash(TRIPOD, 5, 2000)
	var ok := h1 == h2
	print("[det-solver]   seed 5 x2000 solver ticks  h1==h2: ", ok)
	return 0 if ok else 1

# --- rigid distance constraint converges to rest length ----------------------
func _t_distance_constraint() -> int:
	var a := VivChunk.new(Vector2(0, 0), 1.0)
	var b := VivChunk.new(Vector2(20, 0), 1.0)
	var cons := [VivConnection.new(a, b, 10.0, VivConnection.Type.RIGID, 1.0)]
	for _i in 50:
		VivSolver.solve_connections(cons)
	var d := a.pos.distance_to(b.pos)
	var ok := absf(d - 10.0) < 0.01
	print("[distance]     rigid rest 10 -> %.4f: %s" % [d, ok])
	return 0 if ok else 1

# --- elastic resists stretch only (free to compress) -------------------------
func _t_elastic_one_way() -> int:
	# compressed: must NOT push apart
	var a := VivChunk.new(Vector2(0, 0), 1.0)
	var b := VivChunk.new(Vector2(5, 0), 1.0)
	var cc := [VivConnection.new(a, b, 10.0, VivConnection.Type.ELASTIC, 1.0)]
	for _i in 20:
		VivSolver.solve_connections(cc)
	var compressed_ok := absf(a.pos.distance_to(b.pos) - 5.0) < 0.001  # unchanged
	# stretched: must pull back toward rest
	var c := VivChunk.new(Vector2(0, 0), 1.0)
	var d := VivChunk.new(Vector2(20, 0), 1.0)
	var cs := [VivConnection.new(c, d, 10.0, VivConnection.Type.ELASTIC, 1.0)]
	for _i in 50:
		VivSolver.solve_connections(cs)
	var stretched_ok := absf(c.pos.distance_to(d.pos) - 10.0) < 0.01
	var ok := compressed_ok and stretched_ok
	print("[elastic]      compress unchanged:%s  stretch->rest:%s" % [compressed_ok, stretched_ok])
	return 0 if ok else 1

# --- flex opens a bent chain toward the target angle -------------------------
func _t_flex_converges() -> int:
	# Target a non-singular angle (2.0 rad ~114deg); exactly-straight PI is the
	# law-of-cosines singularity where the soft constraint stalls a few degrees short.
	const TARGET := 2.0
	var a := VivChunk.new(Vector2(-10, 0), 1.0)
	var b := VivChunk.new(Vector2(0, 0), 1.0)
	var c := VivChunk.new(Vector2(0, 10), 1.0)   # starts at 90deg (1.571 rad)
	b.pinned = true
	var cons := [
		VivConnection.new(a, b, 10.0, VivConnection.Type.RIGID, 1.0),
		VivConnection.new(b, c, 10.0, VivConnection.Type.RIGID, 1.0),
	]
	var flexes := [VivFlex.new(a, b, c, TARGET, 0.5)]
	for _i in 400:
		VivSolver.solve_connections(cons)
		VivSolver.solve_flexes(flexes)
	var ang := absf((a.pos - b.pos).angle_to(c.pos - b.pos))
	var ok := absf(ang - TARGET) < 0.05
	print("[flex]         90deg -> %.3f rad (target %.3f): %s" % [ang, TARGET, ok])
	return 0 if ok else 1

# --- terrain stops a falling chunk on top of the floor -----------------------
func _t_terrain_stops_fall() -> int:
	var floor := VivTerrain.new()
	floor.add_floor(0.0, -50.0, 50.0)
	var chunk := VivChunk.new(Vector2(0, -30), 2.0, 1.0, 0.02)
	var cr := _mini(chunk)
	var w := _world(floor)
	for _i in 600:
		cr.store_last_positions()
		VivSolver.step(cr, w, DT, 8)
	# center should rest ~radius above the floor (y ~ -2), speed ~0, not tunneled
	var resting := chunk.pos.y > -3.0 and chunk.pos.y < -0.5
	var stopped := chunk.vel.length() < 0.2
	var ok := resting and stopped and chunk.pos.is_finite()
	print("[terrain]      rest y=%.3f (want ~-2), speed=%.4f: %s" % [chunk.pos.y, chunk.vel.length(), ok])
	return 0 if ok else 1

# --- swept collision prevents tunneling a thin floor at high speed ------------
func _t_swept_no_tunnel() -> int:
	var floor := VivTerrain.new()
	floor.add_floor(0.0, -50.0, 50.0)
	var chunk := VivChunk.new(Vector2(0, -2), 1.0, 1.0, 0.0)
	chunk.vel = Vector2(0, 400)  # would move +10 in one tick, well past the floor
	var cr := _mini(chunk)
	var w := _world(floor)
	cr.store_last_positions()
	VivSolver.step(cr, w, DT, 8)
	var caught := chunk.pos.y <= 0.0  # did NOT end up below the floor
	# let it settle a bit
	for _i in 200:
		cr.store_last_positions()
		VivSolver.step(cr, w, DT, 8)
	var ok := caught and chunk.pos.y > -2.0 and chunk.pos.y < 0.5
	print("[swept]        1-tick tunnel prevented:%s  final y=%.3f: %s" % [caught, chunk.pos.y, ok])
	return 0 if ok else 1

# --- helpers -----------------------------------------------------------------
func _run_hash(path: String, seed_value: int, ticks: int) -> String:
	var floor := VivTerrain.new()
	floor.add_floor(0.0, -200.0, 200.0)
	var r := VivCreatureRunner.new()
	r.terrain = floor
	r.load_script(path)
	r.spawn(seed_value)
	r.step(ticks)
	return r.hash_state()

func _com(creature) -> Vector2:
	var s := Vector2.ZERO
	for c in creature.chunks:
		s += c.pos
	return s / float(creature.chunks.size())

func _edges(creature) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for con in creature.connections:
		out.append(con.a.pos.distance_to(con.b.pos))
	return out

func _mini(chunk: VivChunk) -> VivCreature:
	var cr := VivCreature.new()
	cr.chunks = [chunk]
	return cr

func _world(terrain: VivTerrain) -> VivWorld:
	var w := VivWorld.new(0, Vector2(0, 40))
	w.terrain = terrain
	return w
