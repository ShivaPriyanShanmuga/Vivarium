# Vivarium — UI & visual design reference

Derived from the reference video by frame extraction and numerical palette sampling
(master prompt Phase 0). Every visual claim below cites a frame. Cited frames live in
`ref/frames/cited/` (git-ignored; local design study only). Filenames encode an approximate
timestamp, e.g. `..._2216.png` ≈ 22:16.

> **Source:** "The Rain World Animation Process", GDC 2016 Animation Bootcamp — Joar
> Jakobsson & James Therrien. Video id `sVntwsrjNe4`, 1280×720, 29:17.
> Method: transcript keyword targeting + adaptive scene detection → dense frame extraction
> on the two tool-bearing windows (08:00–11:30, 15:30–24:30) + gameplay sampling; palettes
> quantized (median-cut) from cropped regions of interest, not eyeballed. See
> `docs/decisions.md` for the pipeline and the transcript density map.

---

## 0. Read this first — honest coverage

**This is an animation talk. It shows the game's *render viewport* and *debug
visualizations* in depth, and the *shipping creature look* clearly. It does NOT show a
panel-based IDE.** In every tool frame the capture is a **single full-screen render
viewport** with a PowerPoint slide-title overlaid — never an editor with a left rail,
inspector, code pane, or transport bar.

Consequences for the design:

- **What the reference DOES define** (use it, it is authoritative): the *viewport* look —
  the creature's rendered/shaded aesthetic, the debug overlay vocabulary (chunks, IK
  chains, targets), the test-environment palette, and the shipping-look palettes. These are
  §4 of the master prompt (the renderer) and they are well-covered here.
- **What the reference does NOT define** (marked `[GAP]` throughout): the IDE *chrome* —
  panel layout/proportions, borders, spacing, corner treatment, tool typography, control
  affordances. This is §5 of the master prompt (the interface). The reference is silent, so
  the fallback stands: Aseprite-adjacent (dark neutral greys, 1px hard borders, no rounded
  corners/shadows/gradients, dense, small type, keyboard-first), **to be confirmed with the
  user**. Do not claim reference support for chrome decisions.

The most important single observation (master prompt 0.6) is fully answered — see §4.

---

## 1. Panel layout & proportions

- **Tool = one full-bleed render viewport.** `tool_faking_weight_2216.png`,
  `tool_cosmetic_detail_2416.png`, `tool_moving_boxes_1610.png` all show the creature +
  environment filling the frame edge to edge (the black margins are the 16:9 slide
  letterbox, not tool chrome). No sub-panels are visible.
- **The comparison slide** `slide_cosmetics_vs_physics_0918.png` places two viewports side
  by side at ~equal size (physics-debug left, cosmetic-shaded right) — this is a *slide*
  composition, but it is a strong hint that a **debug view and a shaded view of the same
  creature side by side** is the natural way to present this material. Worth stealing for
  Vivarium's A/B and view-mode design.
- **Panel layout of the IDE itself: `[GAP]` not observable in reference.** The §5 layout
  (top bar / left rail / centre viewport / right inspector / bottom split) is not shown.
  What the reference *does* endorse unambiguously: the viewport is the dominant element —
  it is 100% of every tool frame. That aligns with §5's "centre viewport largest by a wide
  margin; a cramped viewport is wrong."

---

## 2. Sampled palette

All values median-cut quantized from cropped ROIs (see `scratchpad/sample_palette.py`,
`palette_montage.png`). Percentages are area share within the crop.

### 2a. Tool default environment — the "test room" the viewport rests in
From `tool_faking_weight_2216.png` and `tool_cosmetic_detail_2416.png`.

| Role | Hex | RGB | Where used |
|---|---|---|---|
| Stone wall — light (dominant) | `#8c909d` | 140,144,157 | The largest area; cool blue-grey wall face |
| Stone wall — highlight | `#9498a5` | 148,152,165 | Raised/lit stone faces |
| Stone wall — shadow/mid | `#726c78` | 114,108,120 | Crevices, ambient occlusion, veins |
| Floating block / dark fixture | `#1e1426` | 30,20,38 | Near-black desaturated purple blocks |
| Machinery ramp (corner detail) | `#1a1023` → `#251b2c` → `#362d3e` → `#5a5666` | — | Pipe/circuit clusters in room corners |
| Pole / room frame edge | `#261d2c` / `#524e5d` | — | Thin vertical poles, room border |

> **Note the cast:** in every test-room swatch **blue ≥ green > red**. The tool's palette
> pass gives the resting environment a **cool purple/blue tint**. This is the "chrome" the
> viewport actually shows — a cool blue-grey, not a neutral grey.

### 2b. Creature — shaded / cosmetic (the "Daddy Long Legs", palette-applied)
From `slide_cosmetics_vs_physics_0918.png` (right panel).

| Role | Hex | RGB | Notes |
|---|---|---|---|
| Silhouette / outline edge | ≤ `#1a0e18` (near-black) | ~26,14,24 | The mesh *is* the outline — no separate stroke |
| Body — dark wine (dominant) | `#2b1223` | 43,18,35 | Main tentacle tone |
| Body — mid / mauve | `#533949` | 83,57,73 | Lit interior |
| Interior red highlight | ~`#7a2a20` **(approx — not cleanly isolable)** | — | Thin brighter-red streaks inside tentacles |

→ **2–3 tones per body** over a near-black silhouette. See §4–5.

### 2c. Debug-overlay vocabulary
From `tool_faking_weight_2216.png`, `tool_where_legs_go_1848.png`,
`tool_cosmetic_detail_2416.png`, and the left panel of `slide_cosmetics_vs_physics_0918.png`.

| Element | Hex | Form |
|---|---|---|
| Chunk / body mass | `#ff1700` | Filled, semi-transparent, overlapping **red circles** |
| IK leg chain | **full-hue rainbow ramp**, red root → blue tip | Stepped/segmented polyline along the limb |
| Joint node | vivid blue ~`#4a4ad0` (AA edge `#6a6ea6`, core `#120f56`) | Small **square** at segment joints |
| Foot / grip target | `#d7d52f` (≈`#e0dd30`) | Scattered **yellow dots** |
| Reach / target line | `#ff1700` | Thin red line from body to a target dot |
| Cosmetic mesh (in "cosmetic detail" view) | near-black `#0a0a0a` strokes **+** blue chunk dots | Mesh drawn **with** debug markers simultaneously |

### 2d. Shipping look — environment palettes (per-region, palette-swapped)
Rain World tints the *whole scene* to one region palette; creatures read as silhouettes
inside it.

**Cold region** `ship_cold_region_0520.png`:

| Role | Hex | RGB |
|---|---|---|
| Background murk (lightest thing on screen) | `#24241d` | 36,36,29 (dark olive-grey) |
| Structures | `#10100c` | 16,16,12 |
| Silhouettes / creatures | `#000000`–`#0b0b08` | near pure black |
| Accents | small saturated **orange** eye-points (bright, sub-pixel; not cleanly sampled) | — |

**Warm region** `ship_warm_region_1400.png`:

| Role | Hex | RGB |
|---|---|---|
| Background (bright, warm) | `#f0a672` | 240,166,114 (peach) |
| Mid warm | `#be7754` | 190,119,84 (tan) |
| Structure brick-red | `#5c272a` | 92,39,42 |
| Silhouettes / creatures | `#000000` | pure black |
| Creature accent | pale blue mask ~`#a8c4d0` **(approx)** | — |

> **Takeaway for the renderer (§4.2):** the look is **very high contrast, near-black
> silhouettes over a single dominant environment hue, whole-scene palette tint, and tiny
> highly-saturated accent points.** The lo-fi palette pass is doing the heavy lifting, as
> the master prompt predicts.

---

## 3. Typography

- **Only slide typography is observable**, and it is PowerPoint, not the tool: thin,
  antialiased, humanist sans (Calibri/Segoe-like), white on black, generous tracking —
  `slide_cosmetics_vs_physics_0918.png` ("Separation of cosmetics and physics"),
  `ship_warm_region_1400.png` ("AI/behaviour == animation"), and every `tool_*` frame's
  title overlay. This is the *presenter's* type; **do not adopt it for the tool.**
- **Tool typography: `[GAP]` not observable.** No labels, numbers, menus, or field text
  appear anywhere in the captured tool footage. The §5 fallback (small, dense, pixel-or-
  crisp UI type) stands, pending the user.

---

## 4. How the creature is rendered in the tool (the key observation)

**Both a debug view and a shaded/cosmetic view exist, and the tool shows the cosmetic mesh
*with* debug markers overlaid — not purely one or the other.** Evidence, in the order the
talk builds a creature:

1. `tool_moving_boxes_1610.png` ("A few moving boxes") — chunks only: red point-masses
   drifting in the shaded test room.
2. `tool_putting_legs_1658.png` ("Putting legs on it") — IK legs added as **rainbow debug
   splines**, root-red to tip-blue, over the same room.
3. `tool_where_legs_go_1848.png` ("Where do all the legs go?") — leg targeting shown on a
   darkened room: red limb curves + a yellow target dot.
4. `tool_faking_weight_2216.png` ("Faking weight and balance") — the full debug creature:
   red filled chunk-circles (body mass), rainbow IK chains with blue square joint nodes,
   scattered yellow foot targets, a red reach line, and a tiny white slugcat for scale.
5. `tool_cosmetic_detail_2416.png` ("Cosmetic detail") — the **cosmetic mesh** appears:
   near-black tapered tentacle strokes radiating from a central body blob, **with blue
   chunk-dots still overlaid**. This is the decisive frame: cosmetic geometry + debug
   markers rendered *at the same time*.

And the fully shaded, palette-applied result (no debug) is shown on the comparison slide,
right panel: `slide_cosmetics_vs_physics_0918.png`.

**Design implication:** Vivarium's default view is the shaded shipping look (§4.1), but the
reference strongly supports **debug overlays composited on top of the shaded render**
(chunks-as-red-circles, IK-as-rainbow-chains, targets-as-yellow-dots, joints-as-blue-
squares) rather than a separate wireframe-only mode. Adopt this exact debug vocabulary in
§4.3's Chunks/Skeleton view modes — it is proven and legible.

---

## 5. Creature aesthetic

From `slide_cosmetics_vs_physics_0918.png` (right), `ship_warm_region_1400.png`,
`ship_cold_region_0520.png`:

- **Silhouette weight:** heavy and dark. Creatures read as **near-black filled masses**,
  palette-tinted (dark wine `#2b1223` in the grey room; pure black in the warm/cold
  regions). The silhouette carries the read; interior detail is minimal.
- **Outline treatment:** **no separate outline stroke** — the dark filled mesh edge is the
  outline. Contrast against the lighter environment does the work.
- **Tones per body:** **2–3.** A near-black base, one mid tone, and a thin brighter interior
  accent (dark-red streaks on the long-legs; a pale-blue mask on the warm-region creature).
- **Taper:** strong. Tentacles/limbs taper from a thick root to **fine, near-single-pixel
  points** (`slide_cosmetics_vs_physics_0918.png` right — "hundreds of points per tentacle"
  yields smooth continuous tapering, vs the 8-point physics chain on the left).
- **Limbs vs body mass:** limbs read as distinct dark strokes leaving a denser central body
  blob (`tool_cosmetic_detail_2416.png`); against the lighter environment they separate
  cleanly.
- **Accents:** tiny, saturated, sparse — glowing orange eyes (cold region), pale-blue mask
  (warm region). Everything else is desaturated dark.

---

## 6. Environment / viewport aesthetic

- **Resting test environment** (`tool_*` frames): a Rain World "room" — cool light-grey
  stone walls (`#8c909d`) with fine white/grey organic **vein/topographic texture**,
  near-black rounded-rectangular **floating blocks** (`#1e1426`) casting soft shadows, thin
  vertical **poles**, and intricate dark blue-grey **machinery clusters** in the corners.
  Slight cool/purple cast overall.
- **Shipping environments** (`ship_*` frames): same structural grammar (blocks, poles,
  chains, brick, industrial machinery) but tinted to a **single region palette** and far
  darker/higher-contrast than the test room.
- **Resolution feel:** lo-fi. Edges are chunky, texture is coarse, upscaling is evidently
  point-sampled — consistent with §4.2's low-res-target + palette-pass + point-upscale
  pipeline. (Exact internal render resolution `[GAP]` — not measurable from a 720p capture.)

---

## 7. Borders, spacing, corners

- **`[GAP]` for tool chrome** — no panels/borders/gutters are shown, so nothing can be
  measured. Fallback: 1px hard borders, no rounded corners, no shadows (§5), pending user.
- **In-world** (not chrome, but observed): environment blocks have *slightly rounded*
  corners and soft drop shadows (`tool_cosmetic_detail_2416.png`); the debug chunk markers
  are hard-edged circles/squares. These inform how *creatures/debug* are drawn, not how the
  *UI frame* is drawn.

---

## 8. Visible controls / playback

- **`[GAP]` not observable.** No transport bar, no view-mode toggles, no parameter fields,
  no tick-rate control appear in any captured frame — the demo is narrated over a running
  viewport. Playback clearly *happens* (chunks move, gaits cycle across frames) but its
  controls are off-capture. §4.4's transport (play/pause/step/scrub/reverse) has no
  reference support and must be designed from the master prompt + user input.

---

## 9. What this means for Vivarium (summary of design directives)

**Authoritative from reference — build to these:**
1. Default view = shaded, palette-applied shipping look; low-res target + palette pass +
   point upscale (§4.2). Very high contrast, near-black silhouettes, whole-scene tint.
2. Debug overlays composited on the shaded render, using the exact observed vocabulary:
   red filled chunk circles, rainbow root→tip IK chains, blue square joints, yellow grip
   targets, red reach lines (§4.3, §2c).
3. Creature drawing: dark filled mesh (no outline stroke), 2–3 palette tones, strong taper
   to fine points, sparse saturated accents (§5).
4. Ship at least one **cool blue-grey stone "test room"** as the default viewport
   environment; palette `#8c909d` stone / `#1e1426` blocks / cool cast (§2a). Support
   palette swaps to warm/cold shipping regions (§2d).
5. Viewport dominates the layout — never let it get cramped (§1).

**Gaps — need the user (do not invent, per Phase 0.6):**
- **A.** IDE panel layout, proportions, borders, spacing, corners (§1, §7).
- **B.** Tool typography — font, size, pixel vs antialiased (§3).
- **C.** Control affordances: transport, view toggles, inspector fields, tick-rate UI (§8).
- **D.** Whether to lean fully into the Aseprite-adjacent fallback for A–C, or pull chrome
  cues from a *different* reference (e.g. the user has a specific IDE/tool aesthetic in
  mind). The GDC talk cannot answer this.

---

## 10. Open questions for the user (Phase 0 acceptance)

1. The reference gives a strong **viewport/creature/debug** language but **no IDE chrome**.
   Confirm: proceed with the Aseprite-adjacent fallback (dark greys, 1px borders, no
   rounding/shadows, dense, keyboard-first) for panels, typography, and controls? Or do you
   have a second reference for the *chrome*?
2. Default viewport environment: adopt the sampled **cool blue-grey test room**
   (`#8c909d` stone, cool cast) as Vivarium's resting scene, matching the tool footage?
3. Debug overlay colors: adopt the exact observed set (chunk `#ff1700`, target `#d7d52f`,
   joint `~#4a4ad0`, rainbow IK ramp)? These are legible and proven, but they must sit well
   on top of the shaded view.
4. Creature palette in examples: the reference "Daddy Long Legs" is dark-wine `#2b1223`.
   Fine as the first exemplar's palette, or do you have a target creature/palette in mind?
