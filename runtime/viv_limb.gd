@tool
class_name VivLimb
extends RefCounted
## A phase-based gait leg (§2 Limb; §4.4 gaits). Drives a foot chunk kinematically:
##
##   STANCE — the foot is world-fixed (the body moves over it) → zero foot slide by
##            construction, which is the whole point of the §7.2 foot-slide metric.
##   SWING  — the foot arcs from its old grip to a ground-seeking landing ahead of the hip.
##
## A central gait cycle in [0,1) plus a per-leg `phase` offset gives the gait pattern
## (diagonal pairs = trot, etc.). `swing_frac` is 1 - duty factor.

var foot: VivChunk            ## the (pinned) foot chunk this limb positions
var hip_offset: Vector2       ## hip position relative to the body origin
var thigh: float = 14.0
var shin: float = 14.0
var bend: float = 1.0         ## knee side (+1 / -1)
var phase: float = 0.0        ## gait phase offset [0,1)
var swing_frac: float = 0.35  ## fraction of the cycle spent swinging (1 - duty)
var step_reach: float = 16.0  ## forward landing distance from the hip
var step_height: float = 9.0  ## peak of the swing arc

var planted := true
var _grip_from: Vector2
var _grip_to: Vector2
var _started := false

func hip(body: Vector2) -> Vector2:
	return body + hip_offset

## Place the foot on the ground under the hip (call once, or let update() self-init).
func setup(body: Vector2, terrain: VivTerrain) -> void:
	foot.pos = _ground_under(hip(body).x, body.y, terrain)
	foot.last_pos = foot.pos
	planted = true
	_started = true

## Advance one tick. `cycle` is the shared gait phase in [0,1); `walk_dir` is the unit
## travel direction. Mutates foot.pos; STANCE leaves it untouched (world-fixed).
func update(body: Vector2, walk_dir: Vector2, terrain: VivTerrain, cycle: float) -> void:
	if not _started:
		setup(body, terrain)
	var lp := fposmod(cycle + phase, 1.0)
	if lp < swing_frac:
		if planted:
			# lift-off: freeze the landing target for the whole swing
			_grip_from = foot.pos
			var lx := hip(body).x + walk_dir.x * step_reach
			_grip_to = _ground_under(lx, body.y, terrain)
			planted = false
		var s := lp / swing_frac
		var p := _grip_from.lerp(_grip_to, s)
		p.y -= sin(s * PI) * step_height  # arc up and over
		# Keep the swinging foot clear of the ground beneath it (step over bumps).
		if terrain != null:
			var gy := terrain.ground_y(p.x, p.y - 40.0)
			if gy < INF:
				p.y = minf(p.y, gy - 1.5)
		foot.pos = p
	else:
		if not planted:
			foot.pos = _grip_to  # touch down
			planted = true
		# STANCE: foot.pos left unchanged -> zero slide

## Knee position from the current hip and foot (for drawing).
func knee(body: Vector2, ts: float = 1.0) -> Vector2:
	return VivIK.solve_two_bone(hip(body), foot.draw_pos(ts), thigh, shin, bend)

func _ground_under(x: float, body_y: float, terrain: VivTerrain) -> Vector2:
	var gy := body_y + (thigh + shin) * 0.9  # fallback if no terrain / no hit
	if terrain != null:
		var g := terrain.ground_y(x, body_y - 5.0)
		if g < INF:
			gy = g
	return Vector2(x, gy)
