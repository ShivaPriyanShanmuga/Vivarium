extends SceneTree
## Probe: can this environment render a SubViewport to a non-black image?
## Determines Phase 3's visual-verification strategy (real GPU render vs PIL rasterization
## of exported geometry). Run WITH and WITHOUT --headless to compare:
##   godot --headless --path . --script res://test/render_probe.gd
##   godot            --path . --script res://test/render_probe.gd

func _initialize() -> void:
	_run()

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var n := Node2D.new()
	n.draw.connect(func() -> void:
		RenderingServer.canvas_item_add_triangle_array(
			n.get_canvas_item(),
			PackedInt32Array([0, 1, 2]),
			PackedVector2Array([Vector2(5, 5), Vector2(60, 8), Vector2(32, 60)]),
			PackedColorArray([Color.RED, Color.GREEN, Color.BLUE]))
	)
	vp.add_child(n)
	get_root().add_child(vp)
	n.queue_redraw()

	# Let the render server produce a frame.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame

	var img := vp.get_texture().get_image()
	var non_black := 0
	var maxc := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var m: int = int(max(c.r, max(c.g, c.b)) * 255.0)
			maxc = max(maxc, m)
			if m > 8:
				non_black += 1
	print("RENDER_PROBE size=", img.get_size(), " non_black_px=", non_black, " maxchannel=", maxc)
	img.save_png("res://test/_render_probe.png")
	print("saved res://test/_render_probe.png")
	quit()
