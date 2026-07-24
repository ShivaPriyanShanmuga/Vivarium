# Vivarium

An AI-native IDE for authoring procedurally animated creatures as **code**, in the
[Rain World](https://en.wikipedia.org/wiki/Rain_World) lineage: a simulated skeleton of
point masses and constraints, with a per-frame generated triangle mesh drawn over it. The
tool writes, runs, and renders creatures live; the AI agent is the primary author, the
human directs and judges.

Built as a **Godot 4.7 editor plugin** (a "Vivarium" workspace tab). Creature code is
**GDScript**; the simulation solver may drop to **GDExtension** only if it needs the
performance. The runtime (`runtime/`) is designed to ship in the game as well as the tool —
there is no export step; the tool is a viewer into your project.

> The visual design is derived from the GDC 2016 "Rain World Animation Process" talk, not
> from imagination — see [`docs/ui-reference.md`](docs/ui-reference.md). Reference material
> lives under `ref/` and is **git-ignored** (local design study only).

## Layout

| Path | What |
|---|---|
| `runtime/` | **vivarium-runtime** — creature contract, sim primitives, seeded RNG, fixed-tick clock, state hasher. Ships in the game too. |
| `addons/vivarium/` | The editor plugin: host (discovery, file watcher, hot-reload runner) + UI shell. |
| `creatures/` | Watched creature programs (GDScript). `test_blob.gd` is the Phase 1 exemplar. |
| `test/` | Headless harnesses (`smoke.gd`, `phase1_harness.gd`). |
| `docs/` | `ui-reference.md`, `decisions.md` (decisions + VERIFY log). |

## The creature contract (§2)

```gdscript
extends VivCreature

func init(world):                  # build chunks/connections/limbs/mesh buffers
func tick(dt):                     # ONE fixed sim step (40 TPS); never draws
func draw(ctx, time_stacker):      # emit geometry; never mutates sim state
func apply_palette(palette):       # rebind colors on palette change
```

Enforced by the runtime, not convention: `tick` never draws, `draw` never mutates
(asserted), fixed tick with an independent render clock (`lerp(last, cur, time_stacker)`),
seeded per-instance RNG for determinism, integer sort keys (no depth buffer).

## Running the tests

```bash
godot --headless --import                                   # build the class cache once
godot --headless --path . --script res://test/phase1_harness.gd
```

Phase 1 acceptance: identical seeds hash identically, and a source edit respawns the
creature in under 300 ms (measured ~5 ms).

## Status

- **Phase 0** — reference extraction ✅
- **Phase 1** — host + determinism/hot-reload harness ✅
- **Phase 2** — simulation: PBD/Verlet, distance + flex constraints, swept-circle terrain ✅
- **Phase 3** — renderer: mesh/layers, low-res + point upscale, view modes, replay ✅
- **Phase 4** — limbs & gaits (two-bone IK, grip, step triggering) — next

Rendering is verified by saving PNGs (Godot can't rasterize headless in this env):

```bash
godot --path . --script res://test/render_creature.gd   # -> test/out/*.png
```

Sample shaded + wireframe renders live in [docs/images/](docs/images/).

See [`docs/decisions.md`](docs/decisions.md) for the full phase log.
