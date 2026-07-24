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

var _seed: int = 0
var _initialized := false

## Called by the host to bring a creature to life deterministically. Not overridden.
func setup(w: VivWorld, seed_value: int) -> void:
	world = w
	_seed = seed_value
	rng = VivRng.new(seed_value)
	chunks.clear()
	init(w)
	# Establish last == cur so the first interpolated frame is stable.
	store_last_positions()
	_initialized = true

# ---------------------------------------------------------------- contract (override)

func init(_w: VivWorld) -> void:
	pass

func tick(_dt: float) -> void:
	pass

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
