@tool
extends Control
## The Vivarium workspace tab — the §5 layout: a top bar (creature path, view modes,
## transport, tick-rate), a left creature rail, the dominant centre viewport (low-res +
## point upscale, §4.2), a right inspector (live tunables + metrics scorecard + scenario /
## A-B / terrain-sketch controls), and a bottom split (validators | console). A full-height
## code overlay toggles on a keystroke. The visual sign-off vs the Phase-0 frames is still
## the user's call; everything here is wired and loads clean.

const VivRenderer := preload("res://addons/vivarium/render/viv_renderer.gd")
const VivPalette := preload("res://addons/vivarium/ui/viv_palette.gd")
const CREATURES_DIR := "res://creatures"
const SCENARIOS_DIR := "user://scenarios"
const POLL_INTERVAL := 0.25
const BUF_CAP := 600
const HISTORY_STEP := 5     # ticks between reverse snapshots

var _registry := VivCreatureRegistry.new()
var _watcher := VivFileWatcher.new()
var _runner := VivCreatureRunner.new()
var _ctx := VivDrawContext.new()

var _list: ItemList
var _status: RichTextLabel
var _metrics_lbl: RichTextLabel
var _validators_lbl: RichTextLabel
var _console: RichTextLabel
var _play_btn: CheckButton
var _mode_btn: OptionButton
var _speed: HSlider
var _tunables_box: VBoxContainer
var _sub: SubViewport
var _bg: ColorRect
var _renderer: VivRenderer
var _svc: SubViewportContainer
var _code_overlay: Panel
var _code_edit: TextEdit
var _sketch_btn: CheckButton

var _entries: Array = []
var _current_path := ""
var _active := false
var _poll_accum := 0.0
var _last_respawn_ms := 0.0
var _validator_summary := "clean"

# metrics rolling buffers
var _foot_x := PackedFloat64Array()
var _planted: Array = []
var _body_y := PackedFloat64Array()
# reverse history + A/B
var _history: Array = []
var _snap_a: Dictionary = {}
var _snap_b: Dictionary = {}
# terrain sketch
var _sketch_on := false
var _sketch_points: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx.palette = VivPaletteRamps.default_creature()
	_runner.gravity = Vector2(0.0, 40.0)
	_runner.terrain = _default_floor()
	_build_ui()
	_watcher.file_changed.connect(_on_file_changed)
	_watcher.file_added.connect(func(_p): _refresh_list())
	_watcher.file_removed.connect(func(_p): _refresh_list())
	_watcher.set_dir(CREATURES_DIR)
	_refresh_list()
	set_process(true)

func set_active(active: bool) -> void:
	_active = active

func _default_floor() -> VivTerrain:
	var t := VivTerrain.new()
	t.add_floor(90.0, -400.0, 400.0)
	t.friction = 0.5
	return t

# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = VivPalette.UI_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 1)
	add_child(outer)

	# --- top bar ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	outer.add_child(top)
	top.add_child(_dim_label(CREATURES_DIR))
	_play_btn = CheckButton.new(); _play_btn.text = "Play"; top.add_child(_play_btn)
	_add_button(top, "Step", _step_once)
	_add_button(top, "Reverse", _reverse_once)
	_add_button(top, "Reload", _reload_current)
	top.add_child(_dim_label("speed"))
	_speed = HSlider.new(); _speed.min_value = 0.1; _speed.max_value = 3.0; _speed.step = 0.1
	_speed.value = 1.0; _speed.custom_minimum_size = Vector2(90, 0); top.add_child(_speed)
	_mode_btn = OptionButton.new()
	for n in ["Shaded", "Wireframe", "Chunks", "Skeleton", "Overdraw"]:
		_mode_btn.add_item(n)
	_mode_btn.item_selected.connect(func(i: int): if _renderer: _renderer.mode = i)
	top.add_child(_mode_btn)
	_add_button(top, "Code", _toggle_code)

	# --- middle: rail | viewport | inspector ---
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 1)
	outer.add_child(mid)

	var rail := VBoxContainer.new()
	rail.custom_minimum_size = Vector2(170, 0)
	mid.add_child(rail)
	rail.add_child(_header("CREATURES"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_selected)
	rail.add_child(_list)

	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.stretch_shrink = 3
	_svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_svc.gui_input.connect(_on_viewport_input)
	mid.add_child(_svc)
	_sub = SubViewport.new()
	_sub.transparent_bg = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svc.add_child(_sub)
	_bg = ColorRect.new()
	_bg.color = VivPalette.ROOM_STONE_LIGHT.darkened(0.55)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(_bg)
	_renderer = VivRenderer.new()
	_renderer.context = _ctx
	_sub.add_child(_renderer)

	var insp := VBoxContainer.new()
	insp.custom_minimum_size = Vector2(220, 0)
	insp.add_theme_constant_override("separation", 4)
	mid.add_child(insp)
	insp.add_child(_header("TUNABLES"))
	_tunables_box = VBoxContainer.new()
	insp.add_child(_tunables_box)
	insp.add_child(_header("METRICS"))
	_metrics_lbl = _mono_label(); insp.add_child(_metrics_lbl)
	var b1 := HBoxContainer.new(); insp.add_child(b1)
	_add_button(b1, "Save scn", _save_scenario)
	_add_button(b1, "Load scn", func(): _apply_scenario(_current_path); _refresh_list())
	var b2 := HBoxContainer.new(); insp.add_child(b2)
	_add_button(b2, "Snap A", func(): _snap("a"))
	_add_button(b2, "Snap B", func(): _snap("b"))
	_add_button(b2, "Compare", _compare_ab)
	var b3 := HBoxContainer.new(); insp.add_child(b3)
	_sketch_btn = CheckButton.new(); _sketch_btn.text = "Sketch terrain"; b3.add_child(_sketch_btn)
	_add_button(b3, "Clear", _clear_terrain)

	# --- bottom: validators | console ---
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 116)
	bottom.add_theme_constant_override("separation", 1)
	outer.add_child(bottom)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_header("VALIDATORS"))
	_validators_lbl = _mono_label(); _validators_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_validators_lbl); bottom.add_child(vbox)
	var cbox := VBoxContainer.new()
	cbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cbox.add_child(_header("CONSOLE"))
	_console = _mono_label(); _console.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_console.scroll_active = true; cbox.add_child(_console); bottom.add_child(cbox)

	# --- code overlay (hidden) ---
	_code_overlay = Panel.new()
	_code_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_code_overlay.visible = false
	add_child(_code_overlay)
	var cov := VBoxContainer.new(); cov.set_anchors_preset(Control.PRESET_FULL_RECT)
	_code_overlay.add_child(cov)
	var cbar := HBoxContainer.new(); cov.add_child(cbar)
	cbar.add_child(_dim_label("CODE  (Tab to close)"))
	_add_button(cbar, "Apply + reload", _apply_code)
	_code_edit = TextEdit.new()
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cov.add_child(_code_edit)

	_log("Vivarium ready. Select a creature; press Play.")

func _header(text: String) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_color_override("font_color", VivPalette.UI_ACCENT)
	return l

func _dim_label(text: String) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_color_override("font_color", VivPalette.UI_TEXT_DIM)
	return l

func _mono_label() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.add_theme_color_override("default_color", VivPalette.UI_TEXT)
	r.custom_minimum_size = Vector2(0, 60)
	return r

func _add_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.pressed.connect(cb); parent.add_child(b)

func _log(msg: String) -> void:
	if _console:
		_console.text += msg + "\n"

# ------------------------------------------------------------------ selection / list

func _refresh_list() -> void:
	_entries = _registry.discover(CREATURES_DIR)
	if _list == null:
		return
	_list.clear()
	for e in _entries:
		_list.add_item(e["name"])
	var idx := _index_of(_current_path)
	if idx < 0 and _entries.size() > 0:
		idx = 0
	if idx >= 0:
		_list.select(idx)
		_select_entry(idx)

func _index_of(path: String) -> int:
	for i in _entries.size():
		if _entries[i]["path"] == path:
			return i
	return -1

func _on_list_selected(idx: int) -> void:
	_select_entry(idx)

func _select_entry(idx: int) -> void:
	if idx < 0 or idx >= _entries.size():
		return
	_current_path = _entries[idx]["path"]
	_apply_scenario(_current_path)
	if _runner.load_script(_current_path, true):
		_runner.spawn(1)
	_reset_buffers()
	_rebuild_inspector()
	if _code_edit:
		_code_edit.text = _read(_current_path)
	_log("selected %s" % _current_path.get_file())

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _reload_current() -> void:
	if _current_path == "":
		return
	_last_respawn_ms = _runner.reload_and_respawn()
	_reset_buffers()
	_rebuild_inspector()
	_log("reloaded (%.1f ms)" % _last_respawn_ms)

func _on_file_changed(path: String) -> void:
	if path == _current_path:
		_reload_current()
	else:
		_refresh_list()

# ------------------------------------------------------------------ scenario / tunables

func _scenario_path(creature_path: String) -> String:
	return SCENARIOS_DIR + "/" + creature_path.get_file().get_basename() + ".json"

func _apply_scenario(creature_path: String) -> void:
	var p := _scenario_path(creature_path)
	if FileAccess.file_exists(p):
		VivScenario.apply(_runner, VivScenario.load_from(p))
		_log("loaded scenario %s" % p.get_file())

func _save_scenario() -> void:
	if _current_path == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENARIOS_DIR))
	VivScenario.save(VivScenario.capture(_runner, _current_path), _scenario_path(_current_path))
	_log("saved scenario for %s" % _current_path.get_file())

func _rebuild_inspector() -> void:
	if _tunables_box == null:
		return
	for c in _tunables_box.get_children():
		c.queue_free()
	if _runner.creature == null:
		return
	for t in VivInspector.list_tunables(_runner.creature):
		var name: String = t["name"]
		var row := VBoxContainer.new()
		row.add_child(_dim_label(name))
		var sl := HSlider.new()
		sl.min_value = t["min"]; sl.max_value = t["max"]; sl.step = t["step"]; sl.value = t["value"]
		var val := Label.new(); val.text = "%.2f" % float(t["value"])
		sl.value_changed.connect(func(v: float):
			_runner.set_tunable(name, v); val.text = "%.2f" % v)
		row.add_child(sl); row.add_child(val)
		_tunables_box.add_child(row)

# ------------------------------------------------------------------ transport / loop

func _step_once() -> void:
	if _runner.creature:
		_runner.step(1); _record_sample(); _maybe_history()

func _reverse_once() -> void:
	if _runner.creature == null or _history.is_empty():
		return
	var target := _runner.clock.tick_count - 1
	var best := -1
	for i in _history.size():
		if int(_history[i][0]) <= target:
			best = i
	if best < 0:
		return
	_runner.restore(_history[best][1])
	_runner.step(target - int(_history[best][0]))
	_log("reverse -> tick %d" % _runner.clock.tick_count)

func _process(delta: float) -> void:
	if not _active:
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		_watcher.poll()
	if _play_btn and _play_btn.button_pressed and _runner.creature:
		var n := _runner.clock.advance(delta * _speed.value)
		for _i in n:
			_runner.step(1); _record_sample(); _maybe_history()
	_render_frame()
	_update_panels()

func _maybe_history() -> void:
	if _runner.clock.tick_count % HISTORY_STEP == 0:
		_history.append([_runner.clock.tick_count, _runner.snapshot()])
		if _history.size() > 240:
			_history.pop_front()

func _reset_buffers() -> void:
	_foot_x = PackedFloat64Array(); _planted = []; _body_y = PackedFloat64Array()
	_history = []

func _record_sample() -> void:
	if _runner.creature == null:
		return
	var q: Variant = _runner.creature
	var limbs = q.get("limbs")
	var body = q.get("body")
	var chunks: Array = _runner.creature.chunks
	var fx := 0.0
	var pl := true
	if limbs != null and limbs.size() > 0:
		var lm: VivLimb = limbs[0]
		fx = lm.foot.pos.x; pl = lm.planted
	elif chunks.size() > 0:
		fx = chunks[0].pos.x
	var by := 0.0
	if body != null:
		by = body.pos.y
	elif chunks.size() > 0:
		by = chunks[0].pos.y
	_foot_x.append(fx); _planted.append(pl); _body_y.append(by)
	if _foot_x.size() > BUF_CAP:
		_foot_x = _foot_x.slice(1); _planted = _planted.slice(1); _body_y = _body_y.slice(1)

# ------------------------------------------------------------------ render + panels

func _render_frame() -> void:
	if _renderer == null or _runner.creature == null:
		return
	var ts := _runner.clock.time_stacker
	_ctx.clear()
	_runner.creature.draw(_ctx, ts)
	_renderer.context = _ctx
	_renderer.creature = _runner.creature
	_renderer.time_stacker = ts
	var b := _bounds()
	var bmin: Vector2 = b[0]
	var bmax: Vector2 = b[1]
	var span := (bmax - bmin).max(Vector2(1, 1))
	var vp := Vector2(_sub.size)
	var scale := minf(vp.x / span.x, vp.y / span.y) * 0.82
	var wc := (bmin + bmax) * 0.5
	_renderer.transform = Transform2D(Vector2(scale, 0), Vector2(0, scale), vp * 0.5 - wc * scale)
	_renderer.world_scale = scale
	_renderer.queue_redraw()
	_validator_summary = VivValidators.summarize(VivValidators.validate(_runner.creature.chunks, _ctx))

func _bounds() -> Array:
	var mn := Vector2(1e30, 1e30)
	var mx := Vector2(-1e30, -1e30)
	var ts := _runner.clock.time_stacker
	for c: VivChunk in _runner.creature.chunks:
		var r := c.radius + 6.0
		mn = mn.min(c.draw_pos(ts) - Vector2(r, r))
		mx = mx.max(c.draw_pos(ts) + Vector2(r, r))
	return [mn, mx]

func _update_panels() -> void:
	if _runner.creature == null:
		return
	# metrics
	if _metrics_lbl and _planted.size() > 8:
		var slide := VivMetrics.foot_slide(_foot_x, _planted)
		var duty := VivMetrics.duty_factor(_planted)
		var stride := VivMetrics.stride_length(_foot_x, _planted)
		var bob := VivMetrics.com_oscillation(_body_y, 40)
		_metrics_lbl.text = "foot slide %.3f\nduty %.2f  stride %.1f\nCOM bob %.2f  tick %d" % [
			slide, duty, stride, bob, _runner.clock.tick_count]
	# validators
	if _validators_lbl:
		var clean := _validator_summary == "clean"
		var col := "#7fb069" if clean else "#ff6b57"
		_validators_lbl.text = "[color=%s]%s[/color]\nhash %s" % [
			col, _validator_summary, _runner.hash_state().substr(0, 16)]

# ------------------------------------------------------------------ A/B

func _snap(slot: String) -> void:
	var d := {"snap": _runner.snapshot(),
		"foot_slide": VivMetrics.foot_slide(_foot_x, _planted),
		"duty": VivMetrics.duty_factor(_planted),
		"tick": _runner.clock.tick_count}
	if slot == "a":
		_snap_a = d
	else:
		_snap_b = d
	_log("snapshot %s @ tick %d" % [slot.to_upper(), d["tick"]])

func _compare_ab() -> void:
	if _snap_a.is_empty() or _snap_b.is_empty():
		_log("need both Snap A and Snap B"); return
	_log("A/B  foot_slide %.3f -> %.3f (%+.3f)  duty %.2f -> %.2f" % [
		_snap_a["foot_slide"], _snap_b["foot_slide"],
		_snap_b["foot_slide"] - _snap_a["foot_slide"], _snap_a["duty"], _snap_b["duty"]])

# ------------------------------------------------------------------ terrain sketch

func _on_viewport_input(event: InputEvent) -> void:
	if not (_sketch_btn and _sketch_btn.button_pressed):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp_pos: Vector2 = event.position * float(_svc.stretch_shrink)
		var world := _renderer.transform.affine_inverse() * vp_pos
		_sketch_points.append(world)
		_rebuild_sketch_terrain()
		_log("sketch point (%.0f, %.0f)  [%d]" % [world.x, world.y, _sketch_points.size()])

func _rebuild_sketch_terrain() -> void:
	if _sketch_points.size() < 2:
		return
	var pts := _sketch_points.duplicate()
	pts.sort_custom(func(a, b): return a.x < b.x)
	var t := VivTerrain.new(); t.friction = 0.5
	for i in range(1, pts.size()):
		t.add_segment(pts[i - 1], pts[i])
	_runner.terrain = t
	_runner.spawn(_runner.seed)  # respawn onto the new ground
	_reset_buffers()

func _clear_terrain() -> void:
	_sketch_points = []
	_runner.terrain = _default_floor()
	_runner.spawn(_runner.seed)
	_reset_buffers()
	_log("terrain reset to default floor")

# ------------------------------------------------------------------ code overlay

func _toggle_code() -> void:
	if _code_overlay == null:
		return
	_code_overlay.visible = not _code_overlay.visible
	if _code_overlay.visible and _code_edit:
		_code_edit.text = _read(_current_path)

func _apply_code() -> void:
	if _current_path == "" or _code_edit == null:
		return
	var f := FileAccess.open(_current_path, FileAccess.WRITE)
	if f:
		f.store_string(_code_edit.text); f.close()
		_reload_current()
		_log("applied code edit")

func _input(event: InputEvent) -> void:
	if _active and event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_toggle_code()
		get_viewport().set_input_as_handled()
