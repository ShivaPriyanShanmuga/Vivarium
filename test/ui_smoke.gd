extends SceneTree
## Headless UI smoke test — instantiate the Vivarium main screen and drive its logic
## (select, play/step/reverse, tunables, scenario, A/B, terrain sketch, code overlay) so a
## runtime error surfaces in CI even though the viewport itself can't rasterize headless.
## Run: godot --headless --path . --script res://test/ui_smoke.gd
## PASS = no SCRIPT ERROR in the output and it reaches UI_SMOKE_RESULT: PASS.

const MainScreen := preload("res://addons/vivarium/ui/viv_main_screen.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var ms: Control = MainScreen.new()
	get_root().add_child(ms)          # triggers _ready -> builds the whole UI
	ms.set_active(true)
	for _i in 3:
		await process_frame

	# transport
	ms._step_once()
	ms._reverse_once()

	# play a bit so metrics buffers fill
	ms._play_btn.button_pressed = true
	for _i in 25:
		await process_frame
	ms._play_btn.button_pressed = false

	# A/B
	ms._snap("a")
	ms._step_once()
	ms._snap("b")
	ms._compare_ab()

	# scenario round-trip through the UI
	ms._save_scenario()
	ms._apply_scenario(ms._current_path)

	# terrain sketch (drive the data path directly)
	ms._sketch_points = [Vector2(-20, 60), Vector2(120, 40), Vector2(260, 70)]
	ms._rebuild_sketch_terrain()
	ms._clear_terrain()

	# tunables + code overlay + reload
	ms._rebuild_inspector()
	ms._toggle_code()
	ms._toggle_code()
	ms._reload_current()

	var ok := ms.is_inside_tree() and ms._runner.creature != null
	print("UI_SMOKE_RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
