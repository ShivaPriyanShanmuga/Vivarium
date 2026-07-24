@tool
class_name VivChunk
extends RefCounted
## A point mass — the atom of the simulation (§2 Simulation primitives).
##
## Verlet-friendly: keeps `last_pos` alongside `pos` both for integration (Phase 2)
## and for the render-clock interpolation the contract requires (§2). Allocated once
## at init() — never per tick (§10 per-tick allocation is a failure mode).

var pos: Vector2
var last_pos: Vector2   ## previous *tick's* position — draw() interpolates from here
var vel: Vector2
var radius: float
var mass: float
var drag: float         ## 0 = none, 1 = fully damped per tick

func _init(p: Vector2 = Vector2.ZERO, r: float = 1.0, m: float = 1.0, d: float = 0.0) -> void:
	pos = p
	last_pos = p
	vel = Vector2.ZERO
	radius = r
	mass = m
	drag = d

## Render-time position: lerp(last_pos, pos, time_stacker). See VivSimClock.
func draw_pos(time_stacker: float) -> Vector2:
	return last_pos.lerp(pos, time_stacker)
