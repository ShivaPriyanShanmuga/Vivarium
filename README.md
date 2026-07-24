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
| `docs/` | `tutorial.md` (empty file → walker), `creature-api.md` (generated), `ui-reference.md`, `decisions.md`. |

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

No desktop app needed — Godot 4.7 is installed as a CLI (on your PATH via winget). Run
**all** headless harnesses with one command:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1   # PowerShell
```
```bash
bash tools/run_tests.sh                                        # Git Bash
```

Expected: `ALL PASS` (phases 1, 2, 3, 4, 6, 7). Each harness exits 0 on success.
Override the binary with `GODOT=/path/to/godot` (env var) if it isn't on PATH.

To run one phase directly:

```bash
godot --headless --import                                      # build the class cache once
godot --headless --path . --script res://test/phase4_harness.gd
```

**Visual checks** (Godot can't rasterize headless here, so these open a brief window):

```bash
godot --path . --script res://test/render_creature.gd          # serpent, all view modes
godot --path . --script res://test/render_gait.gd              # quadruped walk cycle
```

They write PNGs to `test/out/`; sample renders are committed in [docs/images/](docs/images/).

## Status

- **Phase 0** — reference extraction ✅
- **Phase 1** — host + determinism/hot-reload harness ✅
- **Phase 2** — simulation: PBD/Verlet, distance + flex constraints, swept-circle terrain ✅
- **Phase 3** — renderer: mesh/layers, low-res + point upscale, view modes, replay ✅
- **Phase 4** — limbs & gaits: two-bone IK, phase-based gait, ground-seeking grips ✅
- **Phase 6** — validators (§7.1) + motion metrics (§7.2), caught-and-localized ✅
- **Phase 5 (substance)** — live tunables inspector, scenario save/load, multi-instance ✅
- **Phase 7 (tool surface)** — agent operations: read/write+diff, run/validate/measure, diff_runs ✅
- **Phase 5 (polish)** — full layout, terrain-sketch tool, A/B panel, side-by-side sign-off — pending user
- **Phase 7 (LLM loop)** + **Phase 8** (polish) — pending

_(Phases 5's visual approval and 7's LLM critique loop are best done with the user; the
verifiable substance of both is in place. See [docs/decisions.md](docs/decisions.md).)_

The agent's context reference is generated from the runtime types:

```bash
python tools/gen_api.py .    # -> docs/creature-api.md
```

Rendering is verified by saving PNGs (Godot can't rasterize headless in this env):

```bash
godot --path . --script res://test/render_creature.gd   # -> test/out/*.png
```

Sample shaded + wireframe renders live in [docs/images/](docs/images/).

See [`docs/decisions.md`](docs/decisions.md) for the full phase log.
