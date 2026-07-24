# Tutorial — a walking creature from an empty file

This builds a four-legged walker step by step. Every snippet is real, tested code; the
finished creature is [`creatures/quadruped.gd`](../creatures/quadruped.gd), exercised by
`test/phase4_harness.gd`. Drop your file in `creatures/` — the tool discovers and hot-reloads
it. Run visual checks with `godot --path . --script res://test/render_gait.gd`.

> Prereqs: read the contract in [creature-api.md](creature-api.md). The four methods are
> `init(world)`, `tick(dt)`, `draw(ctx, time_stacker)`, `apply_palette(palette)`. The runtime
> enforces the rules: `tick` never draws, `draw` never mutates, fixed 40 TPS tick with an
> independent render clock, seeded RNG, integer-sorted layers (no depth buffer).

## 1. The empty creature

```gdscript
@tool
extends VivCreature

func init(_w: VivWorld) -> void:
	pass
```

That compiles and appears in the creature list, but draws nothing. `extends VivCreature`
gives you `add_chunk`, `add_connection`, `add_flex`, `simulate`, the seeded `rng`, and the
render-interpolation plumbing for free.

## 2. A body that falls and rests

Add one chunk. The base `tick()` already runs the physics solver, so a chunk you add just
*works* — drop it on terrain and it settles (Phase 2):

```gdscript
func init(_w: VivWorld) -> void:
	add_chunk(Vector2(0, -40), 10.0)   # pos, radius
```

Select it, press **Play**. With the default room (a floor) it falls and rests. That is the
whole simulation contract: you describe point masses and constraints; the solver integrates
them deterministically.

## 3. Drive it forward, ride the ground

A walker's body is *kinematic* — you place it each tick rather than letting gravity own it.
Override `tick()`, advance in the walk direction, and track the terrain so it never sinks or
floats. Pin the chunk so the solver leaves it alone:

```gdscript
@export_range(0.0, 80.0, 0.5) var walk_speed := 26.0
@export_range(6.0, 40.0, 0.5) var ride_height := 22.0
var body: VivChunk

func init(_w: VivWorld) -> void:
	body = add_chunk(Vector2(0, -40), 10.0)
	body.pinned = true

func tick(dt: float) -> void:
	body.pos.x += walk_speed * dt
	var g := world.terrain.ground_y(body.pos.x, body.pos.y - 120.0) if world.terrain else INF
	if g < INF:
		body.pos.y = lerpf(body.pos.y, g - ride_height, 0.25)
```

`@export_range` vars become **live tunables** — the inspector shows sliders that retune the
running creature with no reload. `VivTerrain.ground_y` raycasts down for the surface height.

## 4. One leg with two-bone IK

A leg is a `VivLimb`: it owns a foot chunk, plants it world-fixed during stance (zero foot
slide), and swings it to a ground-seeking grip ahead of the hip. Add one and draw the
hip→knee→foot as a shaded tube (`VivIK.solve_two_bone` finds the knee):

```gdscript
var legs: Array[VivLimb] = []
var cycle := 0.0

func init(_w: VivWorld) -> void:
	body = add_chunk(Vector2(0, -40), 10.0); body.pinned = true
	var foot := add_chunk(Vector2.ZERO, 2.0); foot.pinned = true
	var leg := VivLimb.new()
	leg.foot = foot; leg.hip_offset = Vector2(0, 0); leg.thigh = 15; leg.shin = 15
	legs.append(leg)

func tick(dt: float) -> void:
	# ... body drive from step 3 ...
	cycle = fposmod(cycle + walk_speed * dt / 30.0, 1.0)  # gait cycle per distance
	for leg in legs:
		leg.update(body.pos, Vector2.RIGHT, world.terrain, cycle)

func draw(ctx: VivDrawContext, ts: float) -> void:
	ctx.declare_layer(&"leg", 0)
	for leg in legs:
		var hip := body.draw_pos(ts) + leg.hip_offset
		var foot := leg.foot.draw_pos(ts)
		var knee := VivIK.solve_two_bone(hip, foot, leg.thigh, leg.shin, 1.0)
		ctx.tube(&"leg", PackedVector2Array([hip, knee, foot]),
			PackedFloat32Array([5, 4, 2]), ctx.ramp(&"body", 0.45), ctx.ramp(&"body", 0.05))
```

`draw_pos(ts)` interpolates `lerp(last, current, time_stacker)` so motion is smooth at any
frame rate. Everything drawn reads *interpolated* positions and never writes them.

## 5. Four legs, a trot, and a body

Give each leg a `phase` in `[0,1)`; diagonal pairs sharing a phase produce a trot. Draw
near-side legs in front of the body and far-side behind using integer layer sort keys. The
complete result — body tube with an outline layer, an eye accent, and four phase-offset legs
— is [`creatures/quadruped.gd`](../creatures/quadruped.gd). Its acceptance run:

```
foot slide 0.000px · no penetration · no hovering · crosses uneven terrain · deterministic
```

## 6. Debug, validate, tune

- **View modes** (top bar): Shaded is the default; Wireframe shows triangles + winding,
  Chunks/Skeleton show the physics + IK, Overdraw flags layer overlap.
- **Validators** (status line) run every tick — NaN vertices, mixed winding, degenerate
  triangles, detached geometry, over-budget, out-of-range indices — each localized.
- **Tunables** (inspector) retune live; **Save scn** persists the terrain + tunables so the
  setup returns next session.

---

## Honest limits (read before shipping a creature)

- **Gaits are kinematic**, not physically driven. Feet plant world-fixed (great foot slide)
  and the body rides the terrain height — but the body is not *held up* by leg forces, so it
  won't stumble, get knocked over, or interact dynamically the way a physics-coupled body
  would. That coupling is future work.
- **The flex constraint** stalls a few degrees short of a target of exactly π (the straight
  singularity). Aim spine/limb targets a little off straight.
- **Rendering needs a GPU** — the tool renders in the Godot editor; headless CI can run every
  simulation/validator/metric test but not the visual render harnesses.
- **Metrics** cover foot slide, duty factor, stride, and COM bob; **silhouette IoU** and
  contact-phase-timing are not implemented yet (they need rendered vs reference masks).
- **Determinism** holds for fixed dt + seeded RNG only. Don't read the wall clock in `tick`,
  don't iterate a `Dictionary` whose order matters, and keep per-instance state in `chunks`
  or in `capture_state()` so snapshots/replay stay exact.
- **Per-tick allocation** in `draw`/`tick` is invisible until the herd test, then fatal —
  build geometry into reused buffers and allocate chunks/limbs once in `init`.
