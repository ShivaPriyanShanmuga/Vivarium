extends SceneTree
## Windowed render harness (§4). Renders a settled creature to low-res, point-upscales, and
## saves a PNG per view mode into test/out/ for visual review. Headless can't rasterize, so
## run WITHOUT --headless:
##   godot --path . --script res://test/render_creature.gd
## Optional args after --: creature path, settle ticks. Default: serpent, 500.

const VivRenderer := preload("res://addons/vivarium/render/viv_renderer.gd")

const LOW := Vector2i(240, 320)   # low-res internal target
const UPSCALE := 3                # point-sample upscale factor for the saved PNG
const OUT := "res://test/out"

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var creature_path := args[0] if args.size() > 0 else "res://creatures/serpent.gd"
	var settle := int(args[1]) if args.size() > 1 else 500

	# Spawn + settle the creature (pinned root drapes under gravity).
	var runner := VivCreatureRunner.new()
	runner.gravity = Vector2(0.0, 40.0)
	if not runner.load_script(creature_path) or not runner.spawn(1):
		print("RENDER: failed to load/spawn ", creature_path); quit(1); return
	runner.step(settle)

	# Draw context bound to the default palette ramps.
	var ctx := VivDrawContext.new()
	ctx.palette = VivPaletteRamps.default_creature()
	ctx.clear()
	runner.creature.draw(ctx, 0.0)

	# Scene: low-res SubViewport, stone background, renderer fitted to the creature.
	var vp := SubViewport.new()
	vp.size = LOW
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("8c909d").darkened(0.55)  # cool blue-grey test-room tone
	bg.size = Vector2(LOW)
	vp.add_child(bg)
	var renderer := VivRenderer.new()
	renderer.context = ctx
	renderer.creature = runner.creature
	renderer.time_stacker = 0.0
	vp.add_child(renderer)
	get_root().add_child(vp)

	# Fit the creature bounds into the viewport.
	var bounds := _bounds(runner.creature)
	var bmin: Vector2 = bounds[0]
	var bmax: Vector2 = bounds[1]
	var span := (bmax - bmin).max(Vector2(1, 1))
	var scale := minf(float(LOW.x) / span.x, float(LOW.y) / span.y) * 0.82
	var wcenter := (bmin + bmax) * 0.5
	var vpc := Vector2(LOW) * 0.5
	renderer.transform = Transform2D(Vector2(scale, 0), Vector2(0, scale), vpc - wcenter * scale)
	renderer.world_scale = scale

	var dir := DirAccess.open("res://test")
	if dir and not dir.dir_exists("out"):
		dir.make_dir("out")

	var modes := {
		"shaded": VivRenderer.Mode.SHADED,
		"wireframe": VivRenderer.Mode.WIREFRAME,
		"chunks": VivRenderer.Mode.CHUNKS,
		"skeleton": VivRenderer.Mode.SKELETON,
		"overdraw": VivRenderer.Mode.OVERDRAW,
	}
	var base := creature_path.get_file().get_basename()
	for key in modes:
		renderer.mode = modes[key]
		renderer.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		var img := vp.get_texture().get_image()
		img.resize(LOW.x * UPSCALE, LOW.y * UPSCALE, Image.INTERPOLATE_NEAREST)
		var path := "%s/%s_%s.png" % [OUT, base, key]
		img.save_png(path)
		print("RENDER saved ", path)
	quit(0)

func _bounds(creature) -> Array:
	var mn := Vector2(1e30, 1e30)
	var mx := Vector2(-1e30, -1e30)
	for c: VivChunk in creature.chunks:
		var r := c.radius + 4.0
		mn = mn.min(c.pos - Vector2(r, r))
		mx = mx.max(c.pos + Vector2(r, r))
	return [mn, mx]
