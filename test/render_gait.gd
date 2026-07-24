extends SceneTree
## Renders the quadruped's walk cycle (body-locked camera) to a strip of shaded frames in
## test/out/, for visual review of the gait + IK legs. Windowed only:
##   godot --path . --script res://test/render_gait.gd

const VivRenderer := preload("res://addons/vivarium/render/viv_renderer.gd")
const LOW := Vector2i(300, 190)
const UPSCALE := 2
const FRAMES := 8
const TICKS_BETWEEN := 6

func _initialize() -> void:
	_run()

func _run() -> void:
	var terrain := VivTerrain.new()
	terrain.friction = 0.6
	var tpts := [
		Vector2(-200, 40), Vector2(60, 40), Vector2(130, 24), Vector2(210, 30),
		Vector2(300, 54), Vector2(400, 48), Vector2(480, 28), Vector2(1600, 40),
	]
	for i in tpts.size() - 1:
		terrain.add_segment(tpts[i], tpts[i + 1])

	var runner := VivCreatureRunner.new()
	runner.terrain = terrain
	runner.load_script("res://creatures/quadruped.gd")
	runner.spawn(1)
	runner.step(120)  # walk out onto the terrain and settle the ride height

	var ctx := VivDrawContext.new()
	ctx.palette = VivPaletteRamps.default_creature()

	var vp := SubViewport.new()
	vp.size = LOW
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("8c909d").darkened(0.55)
	bg.size = Vector2(LOW)
	vp.add_child(bg)
	# Terrain line.
	var ground := Node2D.new()
	ground.draw.connect(func() -> void:
		for i in terrain.size():
			ground.draw_line(terrain.seg_a[i], terrain.seg_b[i], Color("2b2431"), 2.0)
	)
	vp.add_child(ground)
	var renderer := VivRenderer.new()
	renderer.context = ctx
	renderer.creature = runner.creature
	vp.add_child(renderer)
	get_root().add_child(vp)

	var scale := 2.4
	var q: Variant = runner.creature

	for f in FRAMES:
		runner.step(TICKS_BETWEEN)
		var body: VivChunk = q.body
		# Body-locked camera: keep the walker centred, ground visible below.
		var focus := body.pos + Vector2(0.0, 12.0)
		var xform := Transform2D(Vector2(scale, 0), Vector2(0, scale), Vector2(LOW) * 0.5 - focus * scale)
		renderer.transform = xform
		renderer.world_scale = scale
		ground.transform = xform
		renderer.time_stacker = 0.0
		ctx.clear()
		runner.creature.draw(ctx, 0.0)
		renderer.queue_redraw()
		ground.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		var img := vp.get_texture().get_image()
		img.resize(LOW.x * UPSCALE, LOW.y * UPSCALE, Image.INTERPOLATE_NEAREST)
		img.save_png("res://test/out/gait_%02d.png" % f)
		print("GAIT saved frame ", f)
	quit(0)
