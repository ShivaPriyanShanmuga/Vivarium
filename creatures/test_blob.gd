@tool
extends VivCreature
## Phase 1 exemplar — a deterministic 3-chunk blob.
##
## No real physics yet (Phase 2 adds Verlet + swept-circle terrain collision). This
## exists to exercise the contract, the seeded RNG, the fixed timestep, and the
## determinism + hot-reload harness. Its motion depends on the per-instance seed, so
## same seed -> same state hash, different seed -> different hash.

const CHUNK_COUNT := 3
const JITTER := 3.0

func init(w: VivWorld) -> void:
	for i in CHUNK_COUNT:
		add_chunk(Vector2(0.0, float(i) * 6.0), 4.0, 1.0, 0.02)

func tick(dt: float) -> void:
	for c in chunks:
		# Seeded per-tick jitter: makes the trace seed-dependent (determinism test).
		var jitter := Vector2(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)) * JITTER
		c.vel += (world.gravity + jitter) * dt
		c.vel *= (1.0 - c.drag)          # simple damping -> bounded velocity
		c.pos += c.vel * dt

func draw(ctx: VivDrawContext, time_stacker: float) -> void:
	# Phase 3 renders for real. This proves draw() runs and, crucially, does NOT mutate
	# sim state — it only reads interpolated positions into a local spline.
	var spline := PackedVector2Array()
	for c in chunks:
		spline.append(c.draw_pos(time_stacker))
	ctx.strip(&"debug", spline, PackedFloat32Array([1.0, 0.5]), Color.RED)

func apply_palette(_palette) -> void:
	pass
