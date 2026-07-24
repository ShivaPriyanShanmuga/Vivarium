@tool
class_name VivWorld
extends RefCounted
## The environment a creature is init()'d into (§2 init(world)).
##
## Phase 1: just the deterministic context (gravity, per-instance seed). Phase 2 adds
## terrain (swept-circle collision) and the fixed-tick harness wiring. Units are
## world units; the renderer maps them to the low-res target in Phase 3.

## Downward acceleration, world units / s^2 (tuned against the reference in Phase 2).
var gravity := Vector2(0.0, 40.0)
## Per-instance seed handed to the creature's VivRng (§2 Determinism).
var seed: int = 0

## Terrain is added in Phase 2 (swept-circle collision). Kept as a nullable slot so
## the contract and host don't change shape when it lands.
var terrain = null

func _init(seed_value: int = 0, gravity_value: Vector2 = Vector2(0.0, 40.0)) -> void:
	seed = seed_value
	gravity = gravity_value
