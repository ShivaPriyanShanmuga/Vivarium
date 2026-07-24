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
