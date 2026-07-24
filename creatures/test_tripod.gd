@tool
extends VivCreature
## Phase 2 exemplar — a rigid 3-chunk triangle to drop on terrain. Three mutually rigid
## connections make an exactly-rigid body (unambiguous rest state), the cleanest test that
## the solver settles without exploding, jittering, or drifting. No tick() override needed:
## the base tick() runs the physics step.
##
## Convention: +y is down (gravity), floor sits at y = 0, so the creature starts above it
## at negative y.

func init(_w: VivWorld) -> void:
	var a := add_chunk(Vector2(-6.0, -40.0), 3.0, 1.0, 0.02)
	var b := add_chunk(Vector2(6.0, -40.0), 3.0, 1.0, 0.02)
	var c := add_chunk(Vector2(0.0, -52.0), 3.0, 1.0, 0.02)
	add_connection(a, b, VivConnection.Type.RIGID, 1.0)
	add_connection(b, c, VivConnection.Type.RIGID, 1.0)
	add_connection(c, a, VivConnection.Type.RIGID, 1.0)

func draw(ctx: VivDrawContext, time_stacker: float) -> void:
	var poly := PackedVector2Array()
	for c in chunks:
		poly.append(c.draw_pos(time_stacker))
	ctx.strip(&"debug", poly, PackedFloat32Array([1.0, 1.0, 1.0]), Color.RED)
