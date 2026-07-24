@tool
class_name VivRenderer
extends Node2D
## Renders a creature's accumulated draw context (§4). Layers are submitted in integer
## sort order (no depth buffer). The node's own transform maps world units -> the low-res
## viewport, so geometry is emitted in world space. Debug view modes (§4.3) overlay on a
## dimmed shaded pass, mirroring how the reference tool shows debug over the shaded render.

const VivPalette := preload("res://addons/vivarium/ui/viv_palette.gd")

enum Mode { SHADED, WIREFRAME, CHUNKS, SKELETON, OVERDRAW }

var context: VivDrawContext = null
var creature: VivCreature = null
var mode: int = Mode.SHADED
var time_stacker: float = 0.0
var world_scale: float = 1.0   # for sizing debug strokes in world units

func _draw() -> void:
	if mode != Mode.OVERDRAW and material != null:
		material = null  # drop the additive material used by overdraw
	if mode == Mode.OVERDRAW:
		_draw_overdraw()
		return
	# Shaded pass (full for SHADED, dimmed under debug overlays).
	var dim := mode != Mode.SHADED
	_draw_shaded(dim)
	match mode:
		Mode.WIREFRAME: _draw_wireframe()
		Mode.CHUNKS: _draw_chunks()
		Mode.SKELETON: _draw_skeleton()

func _draw_shaded(dim: bool) -> void:
	if context == null:
		return
	var ci := get_canvas_item()
	for name in context.layer_names_sorted():
		var pts := context.layer_points(name)
		var idx := context.layer_indices(name)
		var col := context.layer_colors(name)
		if idx.size() == 0:
			continue
		if dim:
			var d := PackedColorArray()
			d.resize(col.size())
			for i in col.size():
				var c := col[i]
				d[i] = Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, c.a)
			RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, d)
		else:
			RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, col)

func _pen() -> float:
	return maxf(0.5, 1.5 / maxf(0.001, world_scale))  # ~1.5 screen px in world units

func _draw_wireframe() -> void:
	if context == null:
		return
	var w := _pen()
	var edge := Color(0.85, 0.9, 1.0, 0.9)
	var wind := Color(1.0, 0.8, 0.2, 0.9)
	for name in context.layer_names_sorted():
		var pts := context.layer_points(name)
		var idx := context.layer_indices(name)
		var tri := idx.size() / 3
		for t in tri:
			var a := pts[idx[t * 3]]
			var b := pts[idx[t * 3 + 1]]
			var c := pts[idx[t * 3 + 2]]
			draw_line(a, b, edge, w)
			draw_line(b, c, edge, w)
			draw_line(c, a, edge, w)
			# winding arrowhead: short mark along a->b at its midpoint
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			draw_line(mid, mid - dir.rotated(0.5) * w * 4.0, wind, w)

func _draw_chunks() -> void:
	if creature == null:
		return
	var w := _pen()
	# connections colored by tension (stretch vs rest)
	for con: VivConnection in creature.connections:
		var pa := con.a.draw_pos(time_stacker)
		var pb := con.b.draw_pos(time_stacker)
		var dist := pa.distance_to(pb)
		var stretch := 0.0
		if con.rest_length > 0.0001:
			stretch = clampf((dist - con.rest_length) / con.rest_length, -1.0, 1.0)
		var col := Color(0.4, 0.7, 1.0).lerp(VivPalette.DEBUG_CHUNK, absf(stretch))
		draw_line(pa, pb, col, w)
	# chunk circles
	for c: VivChunk in creature.chunks:
		var p := c.draw_pos(time_stacker)
		draw_circle(p, c.radius, Color(VivPalette.DEBUG_CHUNK, 0.35))
		draw_arc(p, c.radius, 0.0, TAU, 20, VivPalette.DEBUG_CHUNK, w)

func _draw_skeleton() -> void:
	if creature == null:
		return
	var w := _pen()
	for con: VivConnection in creature.connections:
		draw_line(con.a.draw_pos(time_stacker), con.b.draw_pos(time_stacker), Color(0.6, 0.9, 1.0, 0.9), w)
	for f: VivFlex in creature.flexes:
		var pb := f.b.draw_pos(time_stacker)
		draw_line(f.a.draw_pos(time_stacker), pb, Color(0.9, 0.6, 1.0, 0.7), w)
		draw_line(pb, f.c.draw_pos(time_stacker), Color(0.9, 0.6, 1.0, 0.7), w)
	for c: VivChunk in creature.chunks:
		var p := c.draw_pos(time_stacker)
		var col: Color = VivPalette.DEBUG_TARGET if c.grounded else VivPalette.DEBUG_NODE
		draw_rect(Rect2(p - Vector2(w, w) * 1.5, Vector2(w, w) * 3.0), col, true)

func _draw_overdraw() -> void:
	# Additive low-alpha fill per triangle: overlaps brighten -> layer-overlap heatmap.
	if context == null:
		return
	if material == null:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	var tint := Color(0.15, 0.28, 0.12, 1.0)
	for name in context.layer_names_sorted():
		var pts := context.layer_points(name)
		var idx := context.layer_indices(name)
		var tri := idx.size() / 3
		for t in tri:
			var poly := PackedVector2Array([pts[idx[t * 3]], pts[idx[t * 3 + 1]], pts[idx[t * 3 + 2]]])
			draw_colored_polygon(poly, tint)
