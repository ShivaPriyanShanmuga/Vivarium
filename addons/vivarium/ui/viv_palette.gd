@tool
class_name VivPalette
extends RefCounted
## Palette constants sampled from the GDC reference (Phase 0 — docs/ui-reference.md §2).
## Consumed by the renderer (Phase 3 palette pass) and the UI theme (Phase 5). Keeping
## the numbers in one typed place means the tool's real palette, not an approximation.

# --- Tool default "test room" environment (cool blue-grey cast) ---------------
const ROOM_STONE_LIGHT := Color("8c909d")   # dominant wall face
const ROOM_STONE_HI := Color("9498a5")
const ROOM_STONE_SHADOW := Color("726c78")
const ROOM_BLOCK := Color("1e1426")         # near-black floating blocks
const ROOM_MACHINE_LO := Color("1a1023")
const ROOM_MACHINE_HI := Color("362d3e")
const ROOM_FRAME := Color("261d2c")

# --- Creature, shaded/cosmetic (the reference long-legs) ----------------------
const CREATURE_OUTLINE := Color("1a0e18")   # near-black filled-mesh edge (no stroke)
const CREATURE_WINE := Color("2b1223")      # dominant body tone
const CREATURE_MAUVE := Color("533949")     # lit interior

# --- Debug overlay vocabulary (§2c) -------------------------------------------
const DEBUG_CHUNK := Color("ff1700")        # filled chunk circles / body mass
const DEBUG_TARGET := Color("d7d52f")       # grip / foot targets
const DEBUG_NODE := Color("4a4ad0")         # IK joint squares
# IK chains use a full-hue root->tip ramp; sample via debug_ik_ramp(t).

# --- Shipping-look region accents ---------------------------------------------
const SHIP_COLD_MURK := Color("24241d")
const SHIP_WARM_PEACH := Color("f0a672")
const SHIP_BRICK := Color("5c272a")

# --- Aseprite-adjacent UI chrome (fallback, §5; user-approved 2026-07-24) ------
const UI_BG := Color("21232b")
const UI_PANEL := Color("2b2e38")
const UI_BORDER := Color("15161c")
const UI_TEXT := Color("c8ccd4")
const UI_TEXT_DIM := Color("7f8794")
const UI_ACCENT := Color("d7d52f")

## Debug IK chain color at t in [0,1], root(red) -> tip(blue). Matches the reference.
static func debug_ik_ramp(t: float) -> Color:
	# Hue 0 (red) -> ~0.66 (blue) as t goes 0 -> 1.
	return Color.from_hsv(clampf(t, 0.0, 1.0) * 0.66, 0.9, 1.0)
