@tool
extends VivCreature
## Phase 3 exemplar — a tapered, self-shaded hanging tentacle in the reference lineage
## (docs/ui-reference.md §5: near-black silhouette, 2-3 tones, strong taper to a fine tip).
## Pinned at the root so it drapes under gravity; a spine of flex constraints keeps a soft
## curve. Exercises the whole renderer: tube shading, an outline layer behind the body
## layer (integer sort, no depth buffer), palette ramps, and render-clock interpolation.

const N := 12
const SEG := 7.0
const HEAD_W := 16.0
const TAIL_W := 2.5

func init(_w: VivWorld) -> void:
	var prev: VivChunk = null
	for i in N:
		var r := lerpf(HEAD_W * 0.5, TAIL_W * 0.5, float(i) / float(N - 1))
		# slight initial lean so the drape reads as a curve, not a plumb line
		var c := add_chunk(Vector2(float(i) * 1.5, -50.0 + float(i) * SEG), r, 1.0, 0.06)
		if i == 0:
			c.pinned = true
		if prev != null:
			add_connection(prev, c, VivConnection.Type.RIGID, 1.0)
		prev = c
	for i in range(1, N - 1):
		add_flex(chunks[i - 1], chunks[i], chunks[i + 1], PI * 0.9, 0.12)

func apply_palette(_palette) -> void:
	pass  # this creature reads ctx.ramp() live in draw()

func draw(ctx: VivDrawContext, ts: float) -> void:
	ctx.declare_layer(&"outline", 0)
	ctx.declare_layer(&"body", 10)
	ctx.light(Vector2(-0.4, -1.0))

	var spline := PackedVector2Array()
	for c in chunks:
		spline.append(c.draw_pos(ts))

	var width := PackedFloat32Array()
	var out_width := PackedFloat32Array()
	for i in N:
		var f := float(i) / float(N - 1)
		var w := lerpf(HEAD_W, TAIL_W, f)
		width.append(w)
		out_width.append(w + 3.0)

	# Outline behind: a near-black silhouette rim (the filled mesh edge IS the outline).
	ctx.strip(&"outline", spline, out_width, ctx.ramp(&"body", 0.0).darkened(0.35))
	# Body in front: rounded, light-shaded tube — near-black rim to a brick-red lit spine.
	ctx.tube(&"body", spline, width, ctx.ramp(&"body", 0.9), ctx.ramp(&"body", 0.1))
