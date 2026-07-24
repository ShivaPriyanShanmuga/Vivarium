# Vivarium creature API reference

> **Generated** from the runtime type definitions by `tools/gen_api.py` — do not
> hand-edit; re-run to regenerate. This is the compact, exhaustive reference the agent
> receives (§6.1), plus the host/tool surface.

## `VivChunk`  
`runtime/viv_chunk.gd`

A point mass — the atom of the simulation (§2 Simulation primitives).  Verlet-friendly: keeps `last_pos` alongside `pos` both for integration (Phase 2) and for the render-clock interpolation the contract requires (§2). Allocated once at init() — never per tick (§10 per-tick allocation is a failure mode).

- `inv_mass() -> float` — Inverse mass for PBD constraint weighting: 0 for pinned/massless (immovable).
- `draw_pos(time_stacker: float) -> Vector2` — Render-time position: lerp(last_pos, pos, time_stacker). See VivSimClock.

## `VivConnection`  
`runtime/viv_connection.gd`

A distance constraint between two chunks (§2 Simulation primitives).  RIGID   — hold rest_length exactly (stiffness ~1): bones. SPRING  — soft pull toward rest_length (stiffness < 1): flesh, dangly bits. ELASTIC — resist stretch past rest_length only, free to compress: rope, tails.  Solved positionally (PBD) by VivSolver; stiffness in [0,1] is the fraction of the correction applied per iteration.

## `VivCreature`  
`runtime/viv_creature.gd`

The creature contract (§2). Every creature `extends VivCreature` and overrides the four contract methods. The runtime — not convention — enforces the rules:  init(world)                 build chunks, connections, limbs, mesh buffers tick(dt)                    ONE fixed sim step; never draws, never reads wall clock draw(ctx, time_stacker)     emit geometry; never mutates sim state apply_palette(palette)      rebind colors when the environment palette changes  Fixed tick + independent render clock: every animated quantity keeps a `last_*` alongside its current value; draw() interpolates lerp(last, cur, time_stacker). The base manages this for chunk positions (see store_last_positions); creatures do the same for any other animated quantity (angles, colors, alphas, thicknesses) and should include those in get_state_floats() so determinism + interpolation both cover them.

- `setup(w: VivWorld, seed_value: int) -> void` — Called by the host to bring a creature to life deterministically. Not overridden.
- `init(_w: VivWorld) -> void`
- `tick(dt: float) -> void` — Default tick IS the physics step. Creatures with behaviour override tick(), do their behaviour (limb targeting, etc.), then call simulate(dt) — or super() — to advance the body. A pure-physics creature needs no tick() override at all.
- `draw(_ctx: VivDrawContext, _time_stacker: float) -> void`
- `apply_palette(_palette) -> void`
- `add_chunk(pos: Vector2, radius: float = 1.0, mass: float = 1.0, drag: float = 0.0) -> VivChunk` — Register a chunk and return it (call from init()).
- `simulate(dt: float) -> void` — Advance the body one fixed step through the solver (§2 Phase 2).
- `capture_state() -> Dictionary` — Extra per-instance state beyond chunks/rng for snapshot & deterministic replay (§4.4). Override in creatures that keep animated quantities (limb phases, timers, etc.).
- `restore_state(_state: Dictionary) -> void`
- `store_last_positions() -> void` — Copy pos -> last_pos for every chunk. The host calls this immediately BEFORE tick(), so draw() can interpolate between the previous and current tick (§2).
- `get_state_floats() -> PackedFloat64Array` — Hashable state for the determinism harness (§2, §7). Base hashes chunk pos+vel; override, call super(), and append any extra animated quantities.

## `VivDrawContext`  
`runtime/viv_draw_context.gd`

The surface draw() emits geometry into (§2 Rendering primitives). Geometry is ACCUMULATED per named layer, then the renderer submits each layer in integer sort order (§2 "No depth buffer": ordering is an integer sort key within sequentially rendered layers, never a float z-test). `mesh` is THE primitive; quad/strip/tube are sugar over it. Buffers are cleared and re-filled each frame (capacity is reused).

- `declare_layer(name: StringName, sort_order: int) -> void` — Declare a layer and its integer draw order (lowest drawn first). Idempotent — cheap to call every draw(); only re-sorts when something actually changes.
- `clear() -> void` — Wipe all layer buffers for a fresh frame (keeps declared layers + capacity).
- `layer_names_sorted() -> Array`
- `layer_points(name: StringName) -> PackedVector2Array`
- `layer_indices(name: StringName) -> PackedInt32Array`
- `layer_colors(name: StringName) -> PackedColorArray`
- `mesh(layer: StringName, verts: PackedVector2Array, tris: PackedInt32Array, colors: PackedColorArray) -> void` — THE primitive: indexed triangle geometry with per-vertex colors.
- `quad(layer: StringName, center: Vector2, size: Vector2, rotation: float, color: Color = Color.WHITE) -> void` — Textured/solid quad centered at `center` (sugar over mesh; uv currently unused).
- `strip(layer: StringName, spline: PackedVector2Array, width_curve: PackedFloat32Array, color: Color) -> void` — Flat tapered stroke along a spline -> mesh (tails, antennae). Single color.
- `ramp(name: StringName, t: float) -> Color` — Palette ramp lookup by name at t in [0,1].
- `light(dir: Vector2) -> void` — Set the configured light direction (normalized).

## `VivFlex`  
`runtime/viv_flex.gd`

A flex constraint over a chain of three chunks a-b-c that resists folding at the joint b toward `target_angle` (§2). "Much of the alive feel" comes from this.  Implemented (VivSolver) as an angle-preserving distance constraint on the far pair (a,c): the rest a-c distance is derived from the current limb lengths and the target angle via the law of cosines, so it maintains the ANGLE regardless of limb length.

## `VivHasher`  
`runtime/viv_hasher.gd`

Deterministic state hashing (§2 Determinism, §7 gate for the AI loop).  SHA-256 over the IEEE-754 bytes of a creature's state floats — stable across runs and machines (unlike Variant hash()), so an outcome can be attributed to an edit. Full-precision Float64 bytes are used for the canonical hash; `hash_quantized` is available when tiny FP jitter should be tolerated in a comparison.

- `static hash_creature(c: VivCreature) -> String` — Deterministic state hashing (§2 Determinism, §7 gate for the AI loop).  SHA-256 over the IEEE-754 bytes of a creature's state floats — stable across runs and machines (unlike Variant hash()), so an outcome can be attributed to an edit. Full-precision Float64 bytes are used for the canonical hash; `hash_quantized` is available when tiny FP jitter should be tolerated in a comparison.
- `static hash_floats(f: PackedFloat64Array) -> String`
- `static hash_quantized(f: PackedFloat64Array, decimals: int = 6) -> String` — Hash after rounding to `decimals` — use only where sub-ulp determinism isn't required.

## `VivIK`  
`runtime/viv_ik.gd`

Two-bone inverse kinematics (§2 Limb). Given a root (hip), a target (foot), bone lengths l1 (thigh) and l2 (shin), and a bend sign (+1 / -1 = which side the knee bends), return the mid joint (knee) position. Law of cosines, clamped to the reachable range so an over- or under-extended target never produces NaN (the classic §7 failure mode).

- `static solve_two_bone(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2` — Two-bone inverse kinematics (§2 Limb). Given a root (hip), a target (foot), bone lengths l1 (thigh) and l2 (shin), and a bend sign (+1 / -1 = which side the knee bends), return the mid joint (knee) position. Law of cosines, clamped to the reachable range so an over- or under-extended target never produces NaN (the classic §7 failure mode).

## `VivLimb`  
`runtime/viv_limb.gd`

A phase-based gait leg (§2 Limb; §4.4 gaits). Drives a foot chunk kinematically:  STANCE — the foot is world-fixed (the body moves over it) → zero foot slide by construction, which is the whole point of the §7.2 foot-slide metric. SWING  — the foot arcs from its old grip to a ground-seeking landing ahead of the hip.  A central gait cycle in [0,1) plus a per-leg `phase` offset gives the gait pattern (diagonal pairs = trot, etc.). `swing_frac` is 1 - duty factor.

- `hip(body: Vector2) -> Vector2`
- `setup(body: Vector2, terrain: VivTerrain) -> void` — Place the foot on the ground under the hip (call once, or let update() self-init).
- `update(body: Vector2, walk_dir: Vector2, terrain: VivTerrain, cycle: float) -> void` — Advance one tick. `cycle` is the shared gait phase in [0,1); `walk_dir` is the unit travel direction. Mutates foot.pos; STANCE leaves it untouched (world-fixed).
- `knee(body: Vector2, ts: float = 1.0) -> Vector2` — Knee position from the current hip and foot (for drawing).

## `VivMetrics`  
`runtime/viv_metrics.gd`

Motion metrics (§7.2) — computed by the tool over a recorded scenario run and displayed beside the reference so the user sees *why* motion reads wrong, not just that it does. These are static functions over time series the host records; the agent (§6) reads the same numbers through `measure()`.

- `static foot_slide(x_series: PackedFloat64Array, planted: Array) -> float` — Motion metrics (§7.2) — computed by the tool over a recorded scenario run and displayed beside the reference so the user sees *why* motion reads wrong, not just that it does. These are static functions over time series the host records; the agent (§6) reads the same numbers through `measure()`. Foot slide: the largest horizontal drift of a contact point while it is planted. Near zero is the goal — it catches most bad gaits by itself (§7.2).
- `static duty_factor(planted: Array) -> float` — Duty factor: fraction of the cycle a foot is planted (stance). Walk > 0.5, run < 0.5.
- `static step_count(planted: Array) -> int` — Number of steps (stance -> swing transitions) in the series.
- `static stride_frequency(planted: Array, dt: float) -> float` — Stride frequency in steps/second for this foot.
- `static stride_length(x_series: PackedFloat64Array, planted: Array) -> float` — Stride length: mean forward distance between successive touch-downs.
- `static com_oscillation(y_series: PackedFloat64Array, window: int = 40) -> float` — Centre-of-mass vertical oscillation amplitude about a moving-average trend — this is what makes weight read correctly (§7.2). `window` ~ one gait cycle in ticks.
- `static envelope(series: PackedFloat64Array) -> Vector2` — Min/max of a series (e.g., a limb's hip->foot extension envelope).

## `VivPaletteRamps`  
`runtime/viv_palette_ramps.gd`

A named set of color ramps the environment hands to creatures (§2 applyPalette; the `ctx.ramp(name, t)` lookup). Each ramp is a Gradient of luminance-sorted stops. Lives in the runtime (ships in the game), independent of the editor UI. Default ramps use the Phase-0 sampled colors (docs/ui-reference.md §2b), so the tool's palette is the real one.

- `set_ramp(name: StringName, colors: PackedColorArray) -> void`
- `sample(name: StringName, t: float) -> Color` — Sample ramp `name` at t in [0,1]; MAGENTA if the ramp is unknown (obvious in-view).
- `has_ramp(name: StringName) -> bool`
- `static default_creature() -> VivPaletteRamps` — The default creature/environment ramps sampled in Phase 0.

## `VivRng`  
`runtime/viv_rng.gd`

Deterministic per-instance PRNG (§2 Determinism).  Wraps Godot's PCG32 RandomNumberGenerator with an explicit seed so that "same seed + same input trace -> identical state hash" holds. Never reads the wall clock. `state` is save/restorable for snapshot + deterministic replay (§4.4).

- `randf() -> float`
- `randf_range(from: float, to: float) -> float`
- `randfn(mean: float = 0.0, deviation: float = 1.0) -> float`
- `randi() -> int`
- `randi_range(from: int, to: int) -> int`
- `rand_unit() -> Vector2` — Uniform unit-ish vector; deterministic given state.
- `snapshot() -> int`
- `restore(s: int) -> void`

## `VivSimClock`  
`runtime/viv_sim_clock.gd`

Fixed-tick accumulator with an independent render clock (§2, master-prompt §10).  Rain World simulates at 40 TPS (one tick every 25 ms) and renders on a separate clock, interpolating between the two most recent ticks. `advance(real_dt)` consumes real elapsed seconds and reports how many fixed sim ticks are due; `time_stacker` is the render-time interpolation alpha in [0,1) that draw() feeds to lerp(last, cur).

- `advance(real_dt: float, max_ticks: int = 8) -> int` — Consume `real_dt` seconds; return the number of fixed ticks to run now. `max_ticks` clamps the spiral-of-death after a stall (long pause / breakpoint).
- `reset() -> void` — Reset for a fresh spawn / deterministic replay.

## `VivSolver`  
`runtime/viv_solver.gd`

The simulation step (§2, Phase 2). Position-Based Dynamics in the Verlet family:  1. integrate         semi-implicit Euler; momentum carried in chunk.vel 2. iterate:          distance constraints, flex constraints, swept-circle terrain 3. reconcile_velocity  vel = (pos - last_pos)/dt  — the key to stable settling: constraint/terrain corrections are folded back into velocity, so a resting chunk's pos stops changing and its velocity decays to zero (no explode/jitter).  last_pos is set by the host BEFORE tick() (VivCreature.store_last_positions), so it is both the render-interpolation anchor and the Verlet "previous position". Determinism: fixed dt, no wall-clock, iteration over ordered arrays only.

- `static step(creature, world: VivWorld, dt: float, iterations: int = 8) -> void`
- `static integrate(chunks: Array, gravity: Vector2, dt: float) -> void`
- `static solve_connections(connections: Array) -> void`
- `static solve_flexes(flexes: Array) -> void`
- `static resolve_terrain(chunks: Array, terrain: VivTerrain) -> void`
- `static reconcile_velocity(chunks: Array, dt: float) -> void`

## `VivTerrain`  
`runtime/viv_terrain.gd`

Segment-soup terrain for swept-circle collision (§2, §4.5): ground profiles, gaps, ceilings, poles — anything expressible as line segments. Static: built once, never mutated per tick. Collision (VivSolver.resolve_terrain) is two-sided closest-point plus a swept crossing test so fast chunks can't tunnel through thin geometry.

- `clear() -> void`
- `size() -> int`
- `add_segment(a: Vector2, b: Vector2) -> void`
- `add_floor(y: float, x0: float, x1: float) -> void` — Horizontal floor (or ceiling) between x0 and x1 at height y.
- `add_pole(x: float, y0: float, y1: float) -> void` — Vertical pole / wall between y0 and y1 at x.
- `ground_y(x: float, from_y: float = -1.0e6) -> float` — Ground surface y directly under x, searching downward from `from_y` (+y is down). Returns the highest surface at or below from_y, or INF if the ray hits nothing. Used by legs (grip selection) and kinematic bodies to follow the ground (§4 gaits).
- `add_box(rect: Rect2) -> void` — Four walls of an axis-aligned box (chunks collide on the outside).

## `VivValidators`  
`runtime/viv_validators.gd`

Geometry validators (§7.1) — the characteristic failure modes of machine-written mesh code. Run over a creature's accumulated draw context (+ its chunks for detachment). Each finding is localized: { kind, layer, index, detail }. Cheap enough for debug builds every tick; the per-vertex detachment scan is O(verts·chunks) so it is opt-in via `detach_dist > 0`.

- `static finding(kind: String, layer: String, index: int, detail: String) -> Dictionary`
- `static summarize(findings: Array) -> String` — Summarize findings by kind for a compact UI line.

## `VivWorld`  
`runtime/viv_world.gd`

The environment a creature is init()'d into (§2 init(world)).  Phase 1: just the deterministic context (gravity, per-instance seed). Phase 2 adds terrain (swept-circle collision) and the fixed-tick harness wiring. Units are world units; the renderer maps them to the low-res target in Phase 3.

## `VivTools`  
`addons/vivarium/agent/viv_tools.gd`

The agent / tool surface (§6.2) — the deterministic operations the AI (or a human) drives the code<->motion loop with. Everything here is headless-friendly except capture() which needs a GPU. Order matters and saves cost (§6.3): compile -> validate -> measure -> capture -> VLM. write_creature returns a diff for review and never touches disk until accept_write() (§6: the agent never writes project files without the diff being accepted).

- `read_creature(path: String) -> String`
- `write_creature(path: String, source: String) -> Dictionary` — Stage a write and return a review diff. Nothing is written until accept_write().
- `accept_write(path: String) -> bool`
- `discard_write(path: String) -> void`
- `run_scenario(scenario: Dictionary, ticks: int) -> int` — Run a scenario and record series for metrics. Returns a run_id (or -1 on failure). scenario keys: creature (path), seed, terrain (VivTerrain|null), gravity (Vector2).
- `compile_creature(path: String) -> Dictionary`
- `validate(run_id: int) -> Array`
- `measure(run_id: int, names: Array) -> Dictionary`
- `diff_runs(a: int, b: int, names: Array) -> Dictionary` — Metric deltas b - a for the numeric metrics both runs report.
- `snapshot_run(run_id: int) -> Dictionary`
- `restore_run(run_id: int, snap: Dictionary) -> void`
- `run_hash(run_id: int) -> String`

## `VivCreatureRunner`  
`addons/vivarium/host/viv_creature_runner.gd`

Owns one live creature instance and the loop between code and motion (§1, §3): load the user's actual creature script, spawn it deterministically, step it at the fixed rate, and hot-reload from disk on edit under the 300 ms budget.

- `load_script(path: String, fresh: bool = false) -> bool` — Load (or reload) the creature script from disk. `fresh` compiles a standalone GDScript from the file text, bypassing Godot's ResourceLoader AND GDScript compile caches so an on-disk edit actually takes effect (CACHE_MODE_REPLACE alone returns the cached compile).
- `spawn(seed_value: int) -> bool` — Instantiate + init the creature deterministically for `seed_value`.
- `step(n: int) -> void` — Run exactly `n` fixed ticks. store_last BEFORE tick so draw() can interpolate (§2).
- `advance(real_dt: float) -> int` — Advance by real elapsed seconds (fixed-tick accumulator + render interpolation).
- `reload_and_respawn() -> float` — Reload the edited script and respawn with the same seed. Returns elapsed milliseconds (Phase 1 acceptance: < 300 ms). This is the source-edit -> reload -> respawn loop (§5).
- `hash_state() -> String`
- `snapshot() -> Dictionary` — Capture full instance state for A/B and deterministic reverse-replay (§4.4).
- `restore(s: Dictionary) -> void`
- `replay_from(s: Dictionary, ticks: int) -> void` — Deterministic reverse: restore a snapshot and replay forward `back` fewer ticks than it was taken-plus-elapsed. Caller supplies the snapshot and how many ticks to re-run.
- `assert_draw_pure(ctx: VivDrawContext) -> bool` — Enforce §2: draw() must not mutate sim state. Snapshot the hash, draw into a stub context, and confirm the hash is unchanged. Returns true if pure.
