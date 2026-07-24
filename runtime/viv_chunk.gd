@tool
class_name VivChunk
extends RefCounted
## A point mass — the atom of the simulation (§2 Simulation primitives).
##
## Verlet-friendly: keeps `last_pos` alongside `pos` both for integration (Phase 2)
## and for the render-clock interpolation the contract requires (§2). Allocated once
## at init() — never per tick (§10 per-tick allocation is a failure mode).

var pos: Vector2
var last_pos: Vector2   ## previous *tick's* position — draw() interpolates from here,
                        ## and the PBD solver derives velocity from it (§2, Phase 2)
var vel: Vector2
var radius: float
var mass: float
var drag: float         ## 0 = none, 1 = fully damped per tick
var pinned: bool = false ## a fixed anchor: never integrated, treated as infinite mass
var grounded: bool = false ## set by the solver when resting on terrain this tick

func _init(p: Vector2 = Vector2.ZERO, r: float = 1.0, m: float = 1.0, d: float = 0.0) -> void:
	pos = p
	last_pos = p
	vel = Vector2.ZERO
	radius = r
	mass = m
	drag = d

## Inverse mass for PBD constraint weighting: 0 for pinned/massless (immovable).
func inv_mass() -> float:
	if pinned or mass <= 0.0:
		return 0.0
	return 1.0 / mass

## Render-time position: lerp(last_pos, pos, time_stacker). See VivSimClock.
func draw_pos(time_stacker: float) -> Vector2:
	return last_pos.lerp(pos, time_stacker)
