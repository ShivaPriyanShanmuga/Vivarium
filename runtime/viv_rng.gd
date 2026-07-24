@tool
class_name VivRng
extends RefCounted
## Deterministic per-instance PRNG (§2 Determinism).
##
## Wraps Godot's PCG32 RandomNumberGenerator with an explicit seed so that
## "same seed + same input trace -> identical state hash" holds. Never reads the
## wall clock. `state` is save/restorable for snapshot + deterministic replay (§4.4).

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

var seed: int:
	get: return _rng.seed
	set(v): _rng.seed = v

## Opaque PRNG state — capture with `snapshot`, restore into `restore` for replay.
var state: int:
	get: return _rng.state
	set(v): _rng.state = v

func randf() -> float: return _rng.randf()
func randf_range(from: float, to: float) -> float: return _rng.randf_range(from, to)
func randfn(mean: float = 0.0, deviation: float = 1.0) -> float: return _rng.randfn(mean, deviation)
func randi() -> int: return _rng.randi()
func randi_range(from: int, to: int) -> int: return _rng.randi_range(from, to)

## Uniform unit-ish vector; deterministic given state.
func rand_unit() -> Vector2:
	var a := _rng.randf() * TAU
	return Vector2(cos(a), sin(a))

func snapshot() -> int: return _rng.state
func restore(s: int) -> void: _rng.state = s
