@tool
class_name VivPaletteRamps
extends RefCounted
## A named set of color ramps the environment hands to creatures (§2 applyPalette; the
## `ctx.ramp(name, t)` lookup). Each ramp is a Gradient of luminance-sorted stops. Lives
## in the runtime (ships in the game), independent of the editor UI. Default ramps use the
## Phase-0 sampled colors (docs/ui-reference.md §2b), so the tool's palette is the real one.

var ramps: Dictionary = {}   # StringName -> Gradient

func set_ramp(name: StringName, colors: PackedColorArray) -> void:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var n := colors.size()
	for i in n:
		offs.append(float(i) / float(maxi(1, n - 1)))
	g.offsets = offs
	g.colors = colors
	ramps[name] = g

## Sample ramp `name` at t in [0,1]; MAGENTA if the ramp is unknown (obvious in-view).
func sample(name: StringName, t: float) -> Color:
	var g: Gradient = ramps.get(name, null)
	if g == null:
		return Color.MAGENTA
	return g.sample(clampf(t, 0.0, 1.0))

func has_ramp(name: StringName) -> bool:
	return ramps.has(name)

## The default creature/environment ramps sampled in Phase 0.
static func default_creature() -> VivPaletteRamps:
	var p := VivPaletteRamps.new()
	# Body: near-black silhouette -> dark wine -> brick-red lit core (reference §5:
	# near-black with dark-red interior). 4 stops for a smoother lit spine.
	p.set_ramp(&"body", PackedColorArray([
		Color("140a10"), Color("2b1223"), Color("46181a"), Color("6e2a22")]))
	# Belly: darker underside.
	p.set_ramp(&"belly", PackedColorArray([Color("140a12"), Color("22101c"), Color("3a2636")]))
	# Cool blue-grey test-room stone (environment).
	p.set_ramp(&"stone", PackedColorArray([Color("726c78"), Color("8c909d"), Color("9498a5")]))
	# Warm accent (eyes/lights).
	p.set_ramp(&"accent", PackedColorArray([Color("5c272a"), Color("be7754"), Color("f0a672")]))
	return p
