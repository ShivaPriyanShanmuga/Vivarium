# Decisions log

Running record of decisions made while building Vivarium. Where the master prompt says
VERIFY, findings from live source/docs are recorded here rather than trusted to memory.

---

## Phase 0 — Reference extraction

### Environment (verified 2026-07-23)

| Tool | Status | Version |
|---|---|---|
| Python | ✅ | 3.14.2 |
| pip | ✅ | 25.3 |
| ffmpeg | ✅ | 7.1.1-essentials (gyan.dev) |
| node | ✅ | 24.12.0 |
| git | ✅ | 2.51.0.windows |
| yt-dlp | ✅ (installed) | 2026.07.04 |
| opencv-python | ✅ (installed) | 5.0.0 |
| scenedetect | ✅ (installed) | 0.7.1 |
| youtube-transcript-api | ✅ (installed) | current |
| numpy | ✅ (installed) | 2.5.1 |
| pillow | ✅ (installed) | 12.3.0 |

Platform: Windows 11, PowerShell primary shell. The `youtube_transcript_api` and
`scenedetect` console scripts are installed to a Scripts dir not on PATH; invoke via
`python -m scenedetect` / the library API instead.

### Reference material handling

`ref/` is git-ignored. The GDC talk video, extracted frames, and transcript are for local
design study only and are not redistributed or committed (per master prompt Phase 0.2).

### Reference

- Video: https://www.youtube.com/watch?v=sVntwsrjNe4 — "The Rain World Animation Process",
  GDC 2016 Animation Bootcamp, Joar Jakobsson & James Therrien, ~29 min. Video id `sVntwsrjNe4`.

### Video properties (verified via ffprobe)

- Resolution: **1280×720** (720p is the highest this GDC upload offers, not 1080p).
- Duration: **1756.96 s (~29:17)**, 30 fps, 52708 frames.
- Transcript: 644 timestamped entries, `ref/transcript.json`.

### Transcript targeting — where the tool/rendering discussion lives

Keyword density (buckets of 30 s) and phrasing localize the material that matters:

- **~15:30–24:30 — live tool demonstration (the prize).** James (the programmer) builds a
  creature from scratch on screen: "at this point it's very simple" (16:13), "we put some
  legs on it" (16:36), "I have drawn three dots" (18:16), random foot targeting per frame
  (19:33), "rope physics simulations on all" (21:59), "every single frame I count" (22:15).
  This is the region most likely to show actual editor chrome + the creature rendering.
- **~8:00–11:30 — physics-simulation explanation.** Point masses "connected by sticks"
  (9:23), "2D float vector physics" (9:25), "dangly bits" (10:37). Likely diagram / tool
  footage of chunks + connections.
- **~2:45–3:15 — definition of procedural animation** ("not drawing frame by frame, not
  rigging… interactive code informing how the visuals move").
- **~13:30–15:00 — AI-as-animation**, vulture example (gameplay footage).
- **~25:30–28:00 — art/programmer workflow** (talking heads, advice; low tool value).

Prime dense-extraction windows: **8:00–11:30** and **15:30–24:30**. Scene detection
(running) will refine exact shot boundaries so dense fps extraction targets only
tool/screen-capture scenes rather than talking-head/slide filler.

### Scene detection outcome

`detect-adaptive` found 60 scenes (180 thumbnails in `ref/scenes/`). Boundaries confirm the
targeting: one long static slide **08:18→10:40** (cosmetics-vs-physics), one continuous
screen-capture **15:33→21:08** (the ~5.5-min tool demo), then **21:08→23:50** and
**23:50→25:02** (cosmetic detail + wrap). The rest is intro / talking-head / gameplay /
Q&A. Dense extraction targeted 08:00–11:30 and 15:30–24:30 at 0.5 fps (survey) plus
gameplay probes at ~05:20 (cold region) and ~14:00 (warm region).

### Key finding — the reference has no IDE chrome

Every tool frame is a **full-screen render viewport** with a slide title overlaid; there is
**no panel-based IDE** (no rail/inspector/code/transport) anywhere in the capture. So the
reference authoritatively defines the **viewport, creature, debug, and palette** (§4 work)
but is **silent on IDE chrome** (§5 work), which is deferred to the Aseprite-adjacent
fallback + user confirmation. Full write-up with frame citations and numerically-sampled
palette: `docs/ui-reference.md`. Sampling scripts: `scratchpad/sample_palette.py` etc.

### Palette headline (median-cut sampled)

- Tool test-room stone `#8c909d` (cool blue-grey, dominant), blocks `#1e1426`, cool cast.
- Creature shaded: near-black silhouette + dark wine `#2b1223` + mauve `#533949`, 2–3 tones.
- Debug: chunk `#ff1700`, grip target `#d7d52f`, joint `~#4a4ad0`, rainbow root→tip IK ramp.
- Shipping: near-black silhouettes over one region hue (cold murk `#24241d`; warm peach
  `#f0a672` / brick `#5c272a`), very high contrast, tiny saturated accents.

**Phase 0 status:** reference written, palette sampled, gaps marked. Open questions in
`docs/ui-reference.md` §10.

### User decisions (2026-07-23)

- **Engine / host:** **Godot 4**, creature code in **GDScript**, **GDExtension held in
  reserve for the solver** (i.e. drop to native only if the Verlet/constraint solver needs
  the performance). → Host adapter is the Godot path from §3: an EditorPlugin/SubViewport
  viewer into the user's project. GDScript hot-reload is native.
- **IDE chrome (§5 `[GAP]`):** **Aseprite-adjacent fallback** — dark neutral greys, 1px
  hard borders, no rounded corners/shadows/gradients, dense small type, keyboard-first.
  Mock up before building the Phase 5 UI.

### Phase 1 — open items still to confirm with user

- Where the creature **source directory** lives inside their repo (the watched path).
- Exact **Godot 4.x** version to target (VERIFY current stable + EditorPlugin/SubViewport
  APIs against live docs before writing host code).
- Whether Vivarium is a **Godot editor main-screen plugin** (custom workspace tab inside
  the Godot editor) vs a **standalone Godot app** that watches the project — leaning
  editor-plugin per §3, to confirm.

### User decisions (2026-07-24) — resolved

- **Tool form:** **Godot editor main-screen plugin** (`EditorPlugin` with a custom
  workspace tab; creature rendered in a `SubViewport`). Aseprite chrome applied within the
  editor via a theme on our own controls.
- **Project setup:** **Greenfield** — this repo is the Godot 4.7 project; creatures live in
  a watched `creatures/` dir (path configurable to point at a game repo later).

### VERIFIED — Godot 4.7 API smoke test (`test/smoke.gd`, headless)

Target engine **4.7.stable.official** (installed, on PATH). Confirmed by running
`godot --headless --path . --script res://test/smoke.gd`:

- `RandomNumberGenerator`: same `seed` → identical `randf()` sequence; `state` get/set
  save-restores mid-stream → determinism + snapshot/replay both viable.
- `FileAccess.get_modified_time(path)` returns a unix mtime **but needs an absolute path**
  (`ProjectSettings.globalize_path(res://…)`), not a `res://` path → file watcher polls
  globalized paths.
- `DirAccess.open` + `list_dir_begin/get_next` for discovery.
- `Time.get_ticks_usec()` for the <300 ms respawn budget.
- `load(path).new()` + `has_method` for dynamic creature loading (hot reload).
- **`PackedByteArray` has no `.hash()`** → state hasher uses `HashingContext` **SHA-256**
  (stable across runs), hex-encoded. Global `hash(Variant)` exists as a fast in-run hash.

---

## Phase 1 — Host and harness (done)

**Structure** (greenfield Godot 4.7 project, editor-plugin form):

- `runtime/` — **vivarium-runtime** (ships in the game too, §11): the creature contract
  `VivCreature` (init/tick/draw/apply_palette), `VivChunk`, `VivWorld`, `VivRng` (seeded
  PCG32), `VivSimClock` (40 TPS fixed tick + `time_stacker` interpolation alpha),
  `VivDrawContext` (Phase-3 stub with fixed signatures), `VivHasher` (SHA-256 state hash).
- `addons/vivarium/host/` — `VivCreatureRegistry` (discovers scripts whose base chain is
  VivCreature), `VivFileWatcher` (mtime polling → added/changed/removed), `VivCreatureRunner`
  (spawn / fixed-step / timed hot reload / `assert_draw_pure`).
- `addons/vivarium/` — `plugin.gd` main-screen EditorPlugin + `ui/viv_main_screen.gd`
  minimal shell + `ui/viv_palette.gd` (Phase-0 sampled colors as typed constants).
- `creatures/test_blob.gd` — Phase 1 exemplar (deterministic 3-chunk blob).
- `test/` — `smoke.gd` (API verify), `phase1_harness.gd` (acceptance).

**Design notes / gotchas found:**

- `var script` collides with `Object.script` (reserved) → runner member is `creature_script`.
- **Hot reload:** `ResourceLoader.load(path, CACHE_MODE_REPLACE)` returns the *cached* GDScript
  compile, so on-disk edits don't show. Robust fix: read file text →
  `GDScript.new(); gd.source_code = text; gd.reload()` — bypasses both the resource and the
  GDScript compile caches. Probes use path-based `extends "res://runtime/viv_creature.gd"`
  so they compile without the global class cache.
- **Headless class_name resolution** needs the global class cache: run `godot --headless
  --import` once before `--script` harnesses.
- `store_last_positions()` is called by the runner *before* each `tick()` so `draw()` can
  `lerp(last_pos, pos, time_stacker)` — tick/render separation is built in from the start.
- `ref/.gdignore` added so Godot's importer skips the reference frames.

**Acceptance — PASS** (`godot --headless --path . --script res://test/phase1_harness.gd`):

| Check | Result |
|---|---|
| Same seed → same hash (500 ticks) | ✅ |
| Different seed → different hash | ✅ |
| 300-tick per-tick trace identical across runs | ✅ |
| `draw()` leaves sim state unchanged (§2) | ✅ |
| On-disk edit (2→4 chunks) reflected on reload | ✅ |
| Respawn time | ✅ **5.1 ms** (budget 300 ms) |
| Watcher detects changed file | ✅ |
| Registry discovers creatures / rejects non-creatures | ✅ |

Editor loads the plugin with no script errors (`--headless --editor`).

---

## Phase 2 — Simulation (done)

**Approach:** Position-Based Dynamics (Verlet family), in `runtime/viv_solver.gd`:

1. **integrate** — semi-implicit Euler; momentum carried in `chunk.vel`, air drag `(1-drag)`.
2. **iterate** `world.solver_iterations` (default 8) times: distance constraints
   (`VivConnection` rigid/spring/elastic), flex constraints (`VivFlex`), swept-circle
   terrain (`VivTerrain`).
3. **reconcile_velocity** — `vel = (pos - last_pos)/dt`. This is what makes settling
   stable: constraint/terrain position corrections fold back into velocity, so a resting
   chunk stops moving and its velocity decays to zero. No explosion, no jitter.

`last_pos` (set by the host before `tick()`) doubles as the Verlet previous position and
the render-interpolation anchor — tick/render separation and the solver share one field.
Base `VivCreature.tick()` now calls `simulate(dt)`, so a pure-physics creature needs no
`tick()` override; behaviour creatures override and call `simulate()` after their logic.

**Primitives / design choices:**

- **Terrain = segment soup** (`seg_a`/`seg_b` parallel `PackedVector2Array`), not a
  heightfield — expresses gaps, ceilings, poles (§4.5). Collision is two-sided
  closest-point (`Geometry2D.get_closest_point_to_segment`) plus a swept crossing test
  (`Geometry2D.segment_intersects_segment`) so fast chunks can't tunnel thin geometry.
- **Position-based friction:** on contact, cancel the tangential slide since `last_pos`
  scaled by `terrain.friction` — gives Coulomb-ish grip and kills resting drift.
- **Flex = angle-as-distance:** the a-c rest distance is derived from current limb lengths
  and the target angle via the law of cosines, so it holds the ANGLE at any limb length.
  **Known limit:** near the straight singularity (target = π) the soft constraint stalls a
  few degrees short (converges to ~172° for a 180° target); non-singular targets converge
  exactly. Fine for "resists folding"; noted so it isn't mistaken for a bug.
- **PBD gotcha:** untyped `for x in array` makes `x.member` a `Variant` and breaks `:=`
  type inference across the solver → use **typed loop vars** `for c: VivChunk in chunks:`.

**Acceptance — PASS** (`godot --headless --path . --script res://test/phase2_harness.gd`):

| Check | Result |
|---|---|
| **Rigid triangle dropped on floor, 10,000 ticks** | ✅ finite; max speed **0.005** (<0.5, settled); COM drift **0.38** over last 3000 ticks (<1.5); rests on floor; shape error **0.000** (rigid held) |
| Determinism through the solver (seed 5 ×2000) | ✅ |
| Rigid distance constraint → rest length | ✅ (10.0000) |
| Elastic resists stretch only (free to compress) | ✅ |
| Flex converges to target angle (non-singular) | ✅ |
| Terrain stops a falling chunk on the surface | ✅ (rests at −radius, speed 0) |
| Swept collision prevents 1-tick tunneling at high speed | ✅ |

Editor still loads the plugin with no script errors.

---

## Phase 3 — Renderer (done; some view modes deferred)

**Render capability (VERIFIED):** this environment **cannot rasterize headless** (dummy
RenderingDevice) but **renders fine windowed**. So visual verification runs windowed
(`godot --path . --script res://test/render_creature.gd`) and saves PNGs to `test/out/`
(git-ignored) for review; logic/geometry is tested headless.

**Pieces built:**

- `runtime/viv_draw_context.gd` — real geometry accumulation. `mesh(layer, verts, tris,
  colors)` is THE primitive (per-vertex colors); `quad`, `strip` (flat tapered stroke),
  `tube` (rounded, light-shaded tapered body), `ramp`, `light` are sugar. Named layers with
  **integer sort keys** (`declare_layer`), submitted low→high — no depth buffer (§2).
- `runtime/viv_palette_ramps.gd` — named `Gradient` ramps (`ctx.ramp`), defaults from the
  Phase-0 sampled palette; body ramp = near-black → wine → brick-red (reference §5).
- `addons/vivarium/render/viv_renderer.gd` — `Node2D`; submits layers via
  `RenderingServer.canvas_item_add_triangle_array` under a world→viewport transform. View
  modes: **shaded, wireframe** (edges + winding arrowheads), **chunks** (tension-colored),
  **skeleton** (joints/flexes), **overdraw** (additive heatmap).
- Low-res target + **point upscale**: harness renders to a small `SubViewport` and
  `INTERPOLATE_NEAREST`-upscales; the editor uses a `SubViewportContainer`
  (`stretch_shrink`, `TEXTURE_FILTER_NEAREST`). This is the lo-fi cohesion (§4.2).
- `creatures/serpent.gd` — shaded exemplar: pinned-root tapered tentacle, outline layer
  behind a shaded body layer. Rendered result: `docs/images/phase3_serpent_{shaded,wireframe}.png`.
- Transport: `VivCreatureRunner.snapshot/restore/replay_from` + `VivCreature.capture_state/
  restore_state` → deterministic reverse-replay; single-tick `step` already present.
- Live viewport + view-mode selector wired into the editor tab (`viv_main_screen.gd`).

**Deferred (honest gaps, revisit later):** the **palette-indices** and **vertex-IDs**
(hover) view modes from §4.3 — vertex-IDs needs editor hover interactivity, palette-indices
needs ramp-index tagging. Transport UI surfaces play/pause/step/mode; **tick-rate scrub and
a reverse scrubber** are runner-capable but not yet in the UI (Phase 5/8). No dedicated
posterize post-shader — the lo-fi look comes from low-res + palette ramps + point upscale.

**Gotcha:** logical-operator results (`a and b`) infer as **Variant** under this project's
strict warnings — annotate `var ok: bool = a and b`, never `:=`. (Same class of fix as the
`min()`→`mini()` Variant issue.)

**Acceptance — PASS.** Shaded view renders correctly and is visually in the family of the
Phase-0 reference creature (tapered near-black→dark-red self-shaded body, lo-fi upscale on
the cool test-room ground) — a subjective gate for the user to confirm. Headless
`test/phase3_harness.gd`: interpolation endpoints/midpoint + store_last discipline ✅;
integer layer sort ✅; generated geometry valid (66 tris, finite, indices in range, colors
match, 0 degenerate) ✅; `draw()` non-mutating on a real mesh creature ✅; deterministic
snapshot + reverse-replay ✅. Phases 1–2 harnesses still green (no regression). Editor loads
clean.

---

## Phase 4 — Limbs and gaits (done)

**Approach: kinematic phase-based gait** (deterministic, and it makes the §7.2 foot-slide
metric ~0 by construction). A physics-coupled leg is a later refinement.

- `runtime/viv_ik.gd` — two-bone IK (law of cosines), clamped to the reachable range so an
  over/under-extended target never NaNs.
- `runtime/viv_limb.gd` — a leg with STANCE (foot world-fixed → the body moves over it, zero
  slide) / SWING (foot arcs to a ground-seeking grip ahead of the hip). A central gait cycle
  in [0,1) + per-leg `phase` gives the pattern; `swing_frac` = 1 − duty factor. The swing
  foot is clamped above the ground beneath it so it steps *over* bumps (no penetration).
- `runtime/viv_terrain.gd` — `ground_y(x, from_y)` vertical raycast for grip selection and
  body ride-height.
- `creatures/quadruped.gd` — kinematic body rides `RIDE_HEIGHT` above terrain, advances at
  `WALK_SPEED`, four legs in a trot (diagonal pairs). Overrides `tick()` to drive
  kinematically (no solver); all chunks pinned; feet+body live in `chunks` so determinism
  hashing + render interpolation cover the gait. `capture/restore_state` snapshot the cycle
  + per-leg swing state. Render: `docs/images/phase4_gait.png`.

**Gotchas:** a member named `_init` collides with the GDScript constructor → renamed
`_started`. To read creature-specific members (`limbs`, `body`) in a harness, hold the
creature as `Variant` and assign into typed locals (`var lm: VivLimb = q.limbs[i]`).

**Acceptance — PASS** (`test/phase4_harness.gd`, quadruped over an uneven ground profile):

| Check | Result |
|---|---|
| **Foot slide** (planted foot horizontal drift) | ✅ **0.000 px** (< 0.5) |
| **No penetration** (foot below ground) | ✅ **0.000 px** (< 1.5) after swing-clamp |
| **No hovering** (planted feet on the ground) | ✅ **0.000** |
| Body follows terrain | ✅ err 3.31 (< 9) |
| Crossed uneven terrain | ✅ advanced 1560 units |
| Gait active | ✅ ≥ 52 steps per foot |
| Determinism through the gait | ✅ |
| IK exact when reachable / finite when overextended | ✅ |

Visual: `docs/images/phase4_gait.png` — trot with knee-bending IK legs, body tilting over
slopes. Phases 1–3 still green.

---

## Phase 6 — Validators and metrics (done, before the full Phase 5 UI)

**Order note:** Phase 6 was built before completing Phase 5. Phase 5's acceptance is a
*user-approved* visual side-by-side (can't be met unattended); Phase 6 is fully testable and
is the gate/infrastructure the Phase 7 agent needs. Phase 5's UI substance follows.

- `runtime/viv_validators.gd` (§7.1) — geometry validators over a draw context (+chunks),
  each finding localized `{kind, layer, index, detail}`: `nan_vertex`, `winding` (mixed
  within a layer), `degenerate` (zero-area), `index_count`/`index_range`, `bad_color`
  (outside [0,1]/non-finite), `detached` (vertex far from every chunk), `budget` (over a
  vertex ceiling). `summarize()` for a compact UI line. The `draw()`-mutation assertion
  (§7.1) is `VivCreatureRunner.assert_draw_pure`.
- `runtime/viv_metrics.gd` (§7.2) — motion metrics over recorded series: `foot_slide`,
  `duty_factor`, `step_count`, `stride_frequency`, `stride_length`, `com_oscillation`
  (moving-average detrend), `envelope`. (Silhouette IoU + contact-phase-timing deferred —
  IoU needs rendered vs reference masks.)
- Wired a live validator summary into the editor status line (green "clean" / red counts).

**Acceptance — PASS** (`test/phase6_harness.gd`): the clean serpent produces **zero**
findings (the tube/strip generator winds consistently — no false positives); every injected
defect is **caught and localized** — NaN@body:2, mixed winding, detached@b:2, out-of-range
index, degenerate, bad color, over-budget; `draw()` mutation detected (clean pure ✓, mutating
creature caught ✓); metrics compute on a real gait (foot slide 0.000, duty 0.64, 19 steps,
0.84 steps/s, stride 30.0, COM bob finite). All prior harnesses still green; editor clean.

---

## Phase 7 (part 1) — Agent tool surface (done; LLM loop deferred)

The deterministic operations the AI (or a human) drives the loop with — built and tested
without an LLM. The critique loop (§6.3: VLM contact-sheet critique) is **deferred**: it
needs API keys and is best validated with the user watching, and per policy agent wiring
should be set up with the user, not unattended overnight.

- `addons/vivarium/agent/viv_tools.gd` (§6.2): `read_creature`, `write_creature` (returns a
  review **diff**, writes nothing until `accept_write`/`discard_write` — §6 never writes
  project files without an accepted diff), `compile_creature` (cheapest gate, §6.3),
  `run_scenario` → run_id (records series), `validate` (VivValidators), `measure`
  (VivMetrics), `diff_runs` (metric deltas), `snapshot_run`/`restore_run`, `run_hash`.
- `docs/creature-api.md` — **generated** from the runtime types by `tools/gen_api.py`
  (§6.1, §11): class docs + public signatures for all 18 runtime/host/agent classes, so the
  agent's context can't go stale. Re-run `python tools/gen_api.py .` to regenerate.

**Acceptance — PASS** (`test/phase7_harness.gd`): staged write touches nothing until accept;
accept writes; a change yields a hunk diff; discard reverts; compile gate accepts good /
rejects broken; run→validate(clean)→measure (foot slide 0.000, moved 455); determinism
through the surface; `diff_runs` surfaces a +260 distance delta. All prior harnesses green.

---

## Phase 5 (substance) — live tunables, scenarios, multi-instance (done)

The testable core of the §5 UI features (full layout polish + the user-approved side-by-side
gate still pending):

- **Live tunables** — creatures expose `@export_range` vars (quadruped: `walk_speed`,
  `ride_height`, `stride`). `VivInspector.list_tunables/set_tunable` reads/writes them;
  `VivCreatureRunner.tunables` overrides are **re-applied after every respawn** so a tweak
  survives hot reload. Inspector sliders wired into the editor's right panel — editing
  retunes the running instance with no reload.
- **Scenarios** — `VivScenario.capture/apply/save/load_from` persists
  creature+seed+gravity+terrain+tunables as JSON (editor: Save/Load buttons →
  `user://scenarios/<creature>.json`, auto-restored on select → survives restarts).
- **Multi-instance** — `VivHerd.spawn(path,count,base_seed,…)` + `step_all[_timed]`.

**Acceptance (substance) — PASS** (`test/phase5_harness.gd`): tunables listed
[walk_speed, ride_height, stride], a live change speeds the gait (550 vs 260 over 400 ticks)
and **persists across respawn**; scenario save→load round-trips gravity/terrain/tunables/
creature; a 5-instance herd is finite, **varies per seed**, and is **deterministic per seed**.
All 7 harnesses green; editor clean.

## Phase 5 (UI layout) — done (the full §5 workspace)

`viv_main_screen.gd` now implements the full §5 layout, rendered to
`docs/images/phase5_ui_layout.png`:

- **Top bar:** creatures path, Play / Step / **Reverse** (deterministic replay from the
  reverse-history ring) / Reload, **tick-rate scrub** (0.1×–3×), view-mode dropdown, Code.
- **Left rail:** creature list. **Centre:** the dominant low-res + point-upscale viewport;
  the renderer now also draws the terrain line.
- **Right inspector:** live tunable sliders + a **metrics scorecard** (§7.2, from rolling
  recorded series) + Save/Load scenario + **A/B snapshot compare** + **terrain-sketch**
  toggle (click the viewport to lay ground points) + Clear.
- **Bottom split:** VALIDATORS (live §7.1 summary + hash) | CONSOLE log.
- **Code overlay:** full-screen editor toggled by **Tab**, with Apply+reload.

Verified by a headless **UI smoke test** (`test/ui_smoke.gd`) that instantiates the whole
screen and drives every control's logic (select/play/step/reverse/snap A-B/scenario/sketch/
code/reload) — PASS, no script errors; and a windowed layout render. `run_tests.{sh,ps1}`
run all 7 phase harnesses + ui_smoke → ALL PASS. Editor loads clean.

### UI theme (2026-07-24, user feedback)

First pass looked amateur (raw Godot controls + a few color overrides). Replaced with a
proper **`VivTheme`** (`addons/vivarium/ui/viv_theme.gd`): a code-built dark editor Theme —
StyleBoxFlat for panels/buttons (normal/hover/pressed/focus)/inputs/lists, styled sliders
with generated circular grabber textures, a blue selection accent, 1px borders, consistent
padding — applied to the workspace root so all controls inherit it. The layout is re-paneled
into `PanelContainer` cards with `MarginContainer` padding and dim uppercase section headers.
This supersedes the raw "Aseprite-adjacent" first cut toward a polished Godot-editor/Unity
flavour (still dark/flat/dense, just properly themed). Rendered: `docs/images/phase5_ui_layout.png`.
(Note: the render harness must force window size + `set_anchors_and_offsets_preset` so the
panel fills; the real editor sizes the main-screen tab itself.)

## Still pending (needs the user)

- **Phase 5 sign-off:** the polished editor theme is in; the **user-approved side-by-side vs
  the Phase-0 reference frames** is still your call.
- **Phase 7 LLM/VLM critique loop** (§6.3–6.4) — needs API keys, set up together.
- **Phase 8 polish**; deferred silhouette-IoU metric + palette-index/vertex-id view modes.
- **Phase 7 (agent):** the LLM/VLM critique loop (§6.3–6.4), exemplar-library packaging, edit
  log UI, and end-to-end acceptance (IoU > 0.75 / contact timing within 8% unaided).
- **Phase 8 (polish):** snapshot A/B UI, replay scrubbing UI, perf budgets surfaced,
  templates, the empty-file→quadruped tutorial, honest-limits doc.
- **Deferred metrics/views:** silhouette IoU + contact-phase-timing (§7.2); palette-index &
  vertex-id view modes (§4.3).
