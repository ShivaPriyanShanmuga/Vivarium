@tool
class_name VivDrawContext
extends RefCounted
## The surface draw() emits geometry into (§2 Rendering primitives). Geometry is
## ACCUMULATED per named layer, then the renderer submits each layer in integer sort
## order (§2 "No depth buffer": ordering is an integer sort key within sequentially
## rendered layers, never a float z-test). `mesh` is THE primitive; quad/strip/tube are
## sugar over it. Buffers are cleared and re-filled each frame (capacity is reused).

var light_dir: Vector2 = Vector2(0.0, -1.0)   ## configured light direction (default: up)
var palette: VivPaletteRamps = null            ## bound by the renderer for ramp() lookups

var _order: Dictionary = {}   # StringName -> int sort key
var _pts: Dictionary = {}     # StringName -> PackedVector2Array
var _idx: Dictionary = {}     # StringName -> PackedInt32Array
var _col: Dictionary = {}     # StringName -> PackedColorArray
var _sorted: Array = []       # layer names, ascending sort key

# ------------------------------------------------------------------ layers

## Declare a layer and its integer draw order (lowest drawn first). Idempotent — cheap to
## call every draw(); only re-sorts when something actually changes.
func declare_layer(name: StringName, sort_order: int) -> void:
	if _pts.has(name) and _order.get(name) == sort_order:
		return
	_order[name] = sort_order
	if not _pts.has(name):
		_pts[name] = PackedVector2Array()
		_idx[name] = PackedInt32Array()
		_col[name] = PackedColorArray()
	_resort()

func _resort() -> void:
	_sorted = _order.keys()
	_sorted.sort_custom(func(a, b): return _order[a] < _order[b])

## Wipe all layer buffers for a fresh frame (keeps declared layers + capacity).
func clear() -> void:
	for k in _pts:
		_pts[k].clear()
		_idx[k].clear()
		_col[k].clear()

func layer_names_sorted() -> Array: return _sorted
func layer_points(name: StringName) -> PackedVector2Array: return _pts.get(name, PackedVector2Array())
func layer_indices(name: StringName) -> PackedInt32Array: return _idx.get(name, PackedInt32Array())
func layer_colors(name: StringName) -> PackedColorArray: return _col.get(name, PackedColorArray())

# ------------------------------------------------------------------ primitives

## THE primitive: indexed triangle geometry with per-vertex colors.
func mesh(layer: StringName, verts: PackedVector2Array, tris: PackedInt32Array, colors: PackedColorArray) -> void:
	if not _pts.has(layer):
		declare_layer(layer, _order.size())
	var p: PackedVector2Array = _pts[layer]
	var idx: PackedInt32Array = _idx[layer]
	var col: PackedColorArray = _col[layer]
	var base := p.size()
	p.append_array(verts)
	if colors.size() == verts.size():
		col.append_array(colors)
	else:  # single-color fill
		var fill := colors[0] if colors.size() > 0 else Color.MAGENTA
		for _i in verts.size():
			col.append(fill)
	for t in tris:
		idx.append(base + t)
	_pts[layer] = p
	_idx[layer] = idx
	_col[layer] = col

## Textured/solid quad centered at `center` (sugar over mesh; uv currently unused).
func quad(layer: StringName, center: Vector2, size: Vector2, rotation: float, color: Color = Color.WHITE) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var c := cos(rotation)
	var s := sin(rotation)
	var corners := PackedVector2Array([
		center + Vector2(-hx * c - -hy * s, -hx * s + -hy * c),
		center + Vector2(hx * c - -hy * s, hx * s + -hy * c),
		center + Vector2(hx * c - hy * s, hx * s + hy * c),
		center + Vector2(-hx * c - hy * s, -hx * s + hy * c),
	])
	var cols := PackedColorArray([color, color, color, color])
	mesh(layer, corners, PackedInt32Array([0, 1, 2, 0, 2, 3]), cols)

## Flat tapered stroke along a spline -> mesh (tails, antennae). Single color.
func strip(layer: StringName, spline: PackedVector2Array, width_curve: PackedFloat32Array, color: Color) -> void:
	var built := _build_strip(spline, width_curve, 0.0)
	var cols := PackedColorArray()
	cols.resize(built[0].size())
	cols.fill(color)
	mesh(layer, built[0], built[1], cols)

## Shaded tube: a tapered stroke rendered as a rounded body — one rim lit, one shaded by
## light_dir, core between. This is the reference creature look (dark silhouette, 2-3 tones).
func tube(layer: StringName, spline: PackedVector2Array, width_curve: PackedFloat32Array,
		core: Color, edge: Color) -> void:
	var n := spline.size()
	if n < 2:
		return
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var tris := PackedInt32Array()
	for i in n:
		var tangent := _tangent(spline, i)
		var perp := tangent.orthogonal()
		var w := _sample_width(width_curve, i, n) * 0.5
		var lp := spline[i] + perp * w
		var rp := spline[i] - perp * w
		# Lighting: rim whose outward normal faces the light is lighter.
		var ll := clampf(perp.dot(-light_dir) * 0.5 + 0.5, 0.0, 1.0)
		var rl := clampf((-perp).dot(-light_dir) * 0.5 + 0.5, 0.0, 1.0)
		verts.append(lp); cols.append(edge.lerp(core, ll))
		verts.append(spline[i]); cols.append(core)
		verts.append(rp); cols.append(edge.lerp(core, rl))
	# Stitch consecutive 3-rail sections (l,c,r) into 4 tris each.
	for i in n - 1:
		var a := i * 3
		var b := (i + 1) * 3
		# left quad (l,c)
		tris.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
		# right quad (c,r)
		tris.append_array(PackedInt32Array([a + 1, b + 1, a + 2, a + 2, b + 1, b + 2]))
	mesh(layer, verts, tris, cols)

## Palette ramp lookup by name at t in [0,1].
func ramp(name: StringName, t: float) -> Color:
	if palette != null:
		return palette.sample(name, t)
	return Color.MAGENTA

## Set the configured light direction (normalized).
func light(dir: Vector2) -> void:
	light_dir = dir.normalized() if dir.length() > 0.0001 else Vector2(0.0, -1.0)

# ------------------------------------------------------------------ helpers

func _tangent(spline: PackedVector2Array, i: int) -> Vector2:
	var n := spline.size()
	var t: Vector2
	if i == 0:
		t = spline[1] - spline[0]
	elif i == n - 1:
		t = spline[n - 1] - spline[n - 2]
	else:
		t = spline[i + 1] - spline[i - 1]
	return t.normalized() if t.length() > 0.0001 else Vector2.RIGHT

func _sample_width(width_curve: PackedFloat32Array, i: int, n: int) -> float:
	var m := width_curve.size()
	if m == 0:
		return 1.0
	if m == n:
		return width_curve[i]
	if m == 1:
		return width_curve[0]
	# resample by normalized position
	var f := float(i) / float(maxi(1, n - 1)) * float(m - 1)
	var lo := int(floor(f))
	var hi := mini(lo + 1, m - 1)
	return lerpf(width_curve[lo], width_curve[hi], f - float(lo))

# Returns [points, tris] for a 2-rail flat strip.
func _build_strip(spline: PackedVector2Array, width_curve: PackedFloat32Array, _pad: float) -> Array:
	var n := spline.size()
	var verts := PackedVector2Array()
	var tris := PackedInt32Array()
	if n < 2:
		return [verts, tris]
	for i in n:
		var perp := _tangent(spline, i).orthogonal()
		var w := _sample_width(width_curve, i, n) * 0.5
		verts.append(spline[i] + perp * w)
		verts.append(spline[i] - perp * w)
	for i in n - 1:
		var a := i * 2
		var b := (i + 1) * 2
		tris.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	return [verts, tris]
