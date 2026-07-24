@tool
class_name VivCreature
extends RefCounted
## The creature contract (§2). Every creature `extends VivCreature` and overrides the
## four contract methods. The runtime — not convention — enforces the rules:
##
##   init(world)                 build chunks, connections, limbs, mesh buffers
##   tick(dt)                    ONE fixed sim step; never draws, never reads wall clock
##   draw(ctx, time_stacker)     emit geometry; never mutates sim state
##   apply_palette(palette)      rebind colors when the environment palette changes
##
## Fixed tick + independent render clock: every animated quantity keeps a `last_*`
## alongside its current value; draw() interpolates lerp(last, cur, time_stacker).
## The base manages this for chunk positions (see store_last_positions); creatures do
## the same for any other animated quantity (angles, colors, alphas, thicknesses) and
## should include those in get_state_floats() so determinism + interpolation both cover
## them.

var world: VivWorld
var rng: VivRng
var chunks: Array[VivChunk] = []
var connections: Array[VivConnection] = []
var flexes: Array[VivFlex] = []

var _seed: int = 0
var _initialized := false

## Called by the host to bring a creature to life deterministically. Not overridden.
func setup(w: VivWorld, seed_value: int) -> void:
	world = w
	_seed = seed_value
	rng = VivRng.new(seed_value)
	chunks.clear()
	connections.clear()
	flexes.clear()
	init(w)
	# Establish last == cur so the first interpolated frame is stable.
	store_last_positions()
	_initialized = true

# ---------------------------------------------------------------- contract (override)

func init(_w: VivWorld) -> void:
	pass

## Default tick IS the physics step. Creatures with behaviour override tick(), do their
## behaviour (limb targeting, etc.), then call simulate(dt) — or super() — to advance the
## body. A pure-physics creature needs no tick() override at all.
func tick(dt: float) -> void:
	simulate(dt)

func draw(_ctx: VivDrawContext, _time_stacker: float) -> void:
	pass

func apply_palette(_palette) -> void:
	pass

# ---------------------------------------------------------------- base helpers

## Register a chunk and return it (call from init()).
func add_chunk(pos: Vector2, radius: float = 1.0, mass: float = 1.0, drag: float = 0.0) -> VivChunk:
	var c := VivChunk.new(pos, radius, mass, drag)
	chunks.append(c)
	return c

## Connect two chunks. rest_length < 0 uses the current distance between them.
func add_connection(a: VivChunk, b: VivChunk, type: int = VivConnection.Type.RIGID,
		stiffness: float = 1.0, rest_length: float = -1.0) -> VivConnection:
	var rest := rest_length if rest_length >= 0.0 else a.pos.distance_to(b.pos)
	var con := VivConnection.new(a, b, rest, type, stiffness)
	connections.append(con)
	return con

## Add a flex (anti-fold) constraint over a-b-c. target_angle < 0 uses the current angle.
func add_flex(a: VivChunk, b: VivChunk, c: VivChunk, target_angle: float = -1.0,
		stiffness: float = 0.5) -> VivFlex:
	var target := target_angle
	if target < 0.0:
		target = (a.pos - b.pos).angle_to(c.pos - b.pos)
		target = absf(target)
	var fx := VivFlex.new(a, b, c, target, stiffness)
	flexes.append(fx)
	return fx

## Advance the body one fixed step through the solver (§2 Phase 2).
func simulate(dt: float) -> void:
	var iters := world.solver_iterations if world != null else 8
	VivSolver.step(self, world, dt, iters)

## Extra per-instance state beyond chunks/rng for snapshot & deterministic replay (§4.4).
## Override in creatures that keep animated quantities (limb phases, timers, etc.).
func capture_state() -> Dictionary:
	return {}

func restore_state(_state: Dictionary) -> void:
	pass

## Copy pos -> last_pos for every chunk. The host calls this immediately BEFORE tick(),
## so draw() can interpolate between the previous and current tick (§2).
func store_last_positions() -> void:
	for c in chunks:
		c.last_pos = c.pos

## Hashable state for the determinism harness (§2, §7). Base hashes chunk pos+vel;
## override, call super(), and append any extra animated quantities.
func get_state_floats() -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(chunks.size() * 4)
	var i := 0
	for c in chunks:
		out[i] = c.pos.x; out[i + 1] = c.pos.y
		out[i + 2] = c.vel.x; out[i + 3] = c.vel.y
		i += 4
	return out
