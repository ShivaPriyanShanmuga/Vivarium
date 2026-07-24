@tool
class_name VivValidators
extends RefCounted
## Geometry validators (§7.1) — the characteristic failure modes of machine-written mesh
## code. Run over a creature's accumulated draw context (+ its chunks for detachment).
## Each finding is localized: { kind, layer, index, detail }. Cheap enough for debug builds
## every tick; the per-vertex detachment scan is O(verts·chunks) so it is opt-in via
## `detach_dist > 0`.

const DEFAULT_BUDGET := 6000
const DETACH_DIST := 70.0
const DEGEN_AREA := 1.0e-4

static func finding(kind: String, layer: String, index: int, detail: String) -> Dictionary:
	return {"kind": kind, "layer": layer, "index": index, "detail": detail}

static func validate(chunks: Array, ctx: VivDrawContext, budget: int = DEFAULT_BUDGET,
		detach_dist: float = DETACH_DIST) -> Array:
	var out: Array = []
	var total_verts := 0
	for name_sn in ctx.layer_names_sorted():
		var layer := String(name_sn)
		var pts := ctx.layer_points(name_sn)
		var idx := ctx.layer_indices(name_sn)
		var cols := ctx.layer_colors(name_sn)
		total_verts += pts.size()

		# Non-finite vertices (usually normalizing a zero-length vector).
		for i in pts.size():
			if not pts[i].is_finite():
				out.append(finding("nan_vertex", layer, i, "non-finite vertex %v" % pts[i]))

		# Per-vertex colors present, in range, finite (Colors outside declared ramps).
		if cols.size() != pts.size():
			out.append(finding("color_count", layer, -1,
				"colors %d != vertices %d" % [cols.size(), pts.size()]))
		for i in cols.size():
			if not _color_ok(cols[i]):
				out.append(finding("bad_color", layer, i, "color out of [0,1] or non-finite: %s" % cols[i]))

		# Index buffer: multiple of 3, all in range.
		if idx.size() % 3 != 0:
			out.append(finding("index_count", layer, idx.size(), "index count not a multiple of 3"))
		for k in idx.size():
			if idx[k] < 0 or idx[k] >= pts.size():
				out.append(finding("index_range", layer, k,
					"index %d out of range [0,%d)" % [idx[k], pts.size()]))

		# Triangles: degenerate + winding consistency within the layer.
		var tcount := idx.size() / 3
		var pos_n := 0
		var neg_n := 0
		var crosses := PackedFloat64Array()
		for t in tcount:
			var i0 := idx[t * 3]
			var i1 := idx[t * 3 + 1]
			var i2 := idx[t * 3 + 2]
			if i0 >= pts.size() or i1 >= pts.size() or i2 >= pts.size() or i0 < 0 or i1 < 0 or i2 < 0:
				crosses.append(0.0)
				continue
			var a := pts[i0]
			var b := pts[i1]
			var c := pts[i2]
			var cross := (b - a).cross(c - a)
			crosses.append(cross)
			if absf(cross) < DEGEN_AREA:
				out.append(finding("degenerate", layer, t, "zero-area / degenerate triangle"))
			elif cross > 0.0:
				pos_n += 1
			else:
				neg_n += 1
		if pos_n > 0 and neg_n > 0:
			var majority_pos := pos_n >= neg_n
			for t in crosses.size():
				var cr := crosses[t]
				if absf(cr) >= DEGEN_AREA and ((cr > 0.0) != majority_pos):
					out.append(finding("winding", layer, t, "triangle winding differs from layer majority"))

		# Detached geometry: vertices far from every owning chunk.
		if detach_dist > 0.0 and chunks.size() > 0:
			for i in pts.size():
				var mind := 1.0e30
				for ch: VivChunk in chunks:
					mind = minf(mind, pts[i].distance_to(ch.pos))
				if mind > detach_dist:
					out.append(finding("detached", layer, i,
						"vertex %.0f px from nearest chunk (> %.0f)" % [mind, detach_dist]))

	if total_verts > budget:
		out.append(finding("budget", "", total_verts,
			"vertex count %d exceeds budget %d" % [total_verts, budget]))
	return out

## Summarize findings by kind for a compact UI line.
static func summarize(findings: Array) -> String:
	if findings.is_empty():
		return "clean"
	var counts := {}
	for f in findings:
		counts[f["kind"]] = counts.get(f["kind"], 0) + 1
	var parts := PackedStringArray()
	for k in counts:
		parts.append("%s×%d" % [k, counts[k]])
	return ", ".join(parts)

static func _color_ok(c: Color) -> bool:
	for v in [c.r, c.g, c.b, c.a]:
		if not is_finite(v) or v < -0.001 or v > 1.001:
			return false
	return true
