@tool
extends VivCreature
## Phase 4 exemplar — a four-legged walker (§4 gaits). The body is a kinematic chunk that
## rides `RIDE_HEIGHT` above the terrain and advances at WALK_SPEED; four legs (VivLimb) run
## a phase-based trot (diagonal pairs), planting world-fixed feet (zero foot slide) and
## swinging to ground-seeking grips ahead. Overrides tick() to drive kinematically instead
## of running the physics solver. All chunks pinned so the solver never disturbs them; feet
## + body are in `chunks`, so determinism-hashing and render interpolation cover the gait.

const WALK_SPEED := 26.0
const RIDE_HEIGHT := 22.0
const STRIDE := 30.0        # body distance per gait cycle
const THIGH := 15.0
const SHIN := 15.0

var body: VivChunk
var limbs: Array[VivLimb] = []
var cycle := 0.0
var walk_dir := Vector2(1.0, 0.0)

func init(_w: VivWorld) -> void:
	body = add_chunk(Vector2(0.0, -40.0), 10.0)
	body.pinned = true
	# hips (fore/aft, near/far), gait phase, knee bend. Trot: diagonal pairs share phase.
	var specs := [
		{"hip": Vector2(-12, -1), "phase": 0.0, "bend": -1.0},  # 0 rear-far  (back layer)
		{"hip": Vector2(-10, 2),  "phase": 0.5, "bend": -1.0},  # 1 rear-near (front layer)
		{"hip": Vector2(12, -1),  "phase": 0.5, "bend": 1.0},   # 2 fore-far  (back layer)
		{"hip": Vector2(10, 2),   "phase": 0.0, "bend": 1.0},   # 3 fore-near (front layer)
	]
	for s in specs:
		var f := add_chunk(Vector2.ZERO, 2.0)
		f.pinned = true
		var limb := VivLimb.new()
		limb.foot = f
		limb.hip_offset = s["hip"]
		limb.thigh = THIGH
		limb.shin = SHIN
		limb.bend = s["bend"]
		limb.phase = s["phase"]
		limb.step_reach = 15.0
		limb.step_height = 9.0
		limb.swing_frac = 0.35
		limbs.append(limb)

func tick(dt: float) -> void:
	var terr := world.terrain
	body.pos.x += walk_dir.x * WALK_SPEED * dt
	var g: float = terr.ground_y(body.pos.x, body.pos.y - 120.0) if terr != null else INF
	var target_y: float = (g - RIDE_HEIGHT) if g < INF else body.pos.y
	body.pos.y = lerpf(body.pos.y, target_y, 0.25)
	cycle = fposmod(cycle + (WALK_SPEED * dt) / STRIDE, 1.0)
	for limb in limbs:
		limb.update(body.pos, walk_dir, terr, cycle)

func draw(ctx: VivDrawContext, ts: float) -> void:
	ctx.declare_layer(&"leg_back", 0)
	ctx.declare_layer(&"body_outline", 5)
	ctx.declare_layer(&"body", 10)
	ctx.declare_layer(&"leg_front", 20)
	ctx.light(Vector2(-0.4, -1.0))
	var bp := body.draw_pos(ts)

	for i in limbs.size():
		var limb := limbs[i]
		var hip := bp + limb.hip_offset
		var ft := limb.foot.draw_pos(ts)
		var kn := VivIK.solve_two_bone(hip, ft, limb.thigh, limb.shin, limb.bend)
		var layer: StringName = &"leg_front" if (i % 2 == 1) else &"leg_back"
		var spline := PackedVector2Array([hip, kn, ft])
		var w := PackedFloat32Array([5.5, 4.0, 2.2])
		ctx.tube(layer, spline, w, ctx.ramp(&"body", 0.45), ctx.ramp(&"body", 0.05))

	# Body: tail -> torso -> head as a shaded tube, with a near-black outline behind it.
	var tail := bp + Vector2(-18, 1)
	var head := bp + Vector2(21, -3)
	var body_spline := PackedVector2Array([tail, bp, head])
	ctx.strip(&"body_outline", body_spline, PackedFloat32Array([12, 25, 15]), ctx.ramp(&"body", 0.0).darkened(0.4))
	ctx.tube(&"body", body_spline, PackedFloat32Array([9, 22, 12]), ctx.ramp(&"body", 0.62), ctx.ramp(&"body", 0.05))
	# Warm eye accent.
	ctx.quad(&"body", head + Vector2(3, -1), Vector2(2.5, 2.5), 0.0, ctx.ramp(&"accent", 0.9))

func capture_state() -> Dictionary:
	var legs := []
	for limb in limbs:
		legs.append([limb.planted, limb._grip_from, limb._grip_to, limb._started])
	return {"cycle": cycle, "legs": legs}

func restore_state(state: Dictionary) -> void:
	cycle = state["cycle"]
	var legs: Array = state["legs"]
	for i in limbs.size():
		var d: Array = legs[i]
		limbs[i].planted = d[0]
		limbs[i]._grip_from = d[1]
		limbs[i]._grip_to = d[2]
		limbs[i]._started = d[3]
