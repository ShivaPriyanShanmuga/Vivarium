extends SceneTree
## Renders the Vivarium workspace tab to test/out/ui_layout.png so the §5 layout can be
## reviewed without opening the editor GUI. Windowed only:
##   godot --path . --script res://test/render_ui.gd

const MainScreen := preload("res://addons/vivarium/ui/viv_main_screen.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var win := get_root()
	await process_frame
	DisplayServer.window_set_size(Vector2i(1180, 740))
	win.size = Vector2i(1180, 740)
	var ms: Control = MainScreen.new()
	win.add_child(ms)
	ms.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ms.size = Vector2(1180, 740)
	ms.set_active(true)
	await process_frame
	await process_frame
	# quadruped is selected first (alphabetical); walk it a few strides
	ms._play_btn.button_pressed = true
	for _i in 90:
		await process_frame
	ms._play_btn.button_pressed = false
	await RenderingServer.frame_post_draw
	await process_frame
	var img := win.get_texture().get_image()
	img.save_png("res://test/out/ui_layout.png")
	print("UI render saved res://test/out/ui_layout.png")
	quit(0)
