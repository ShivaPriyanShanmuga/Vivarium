@tool
extends Control
## Vivarium workspace tab. Phase 1 wired the code<->motion loop; Phase 3 adds the live
## viewport: creatures render into a low-res SubViewport (point-upscaled for the lo-fi look,
## §4.2) with selectable view modes (§4.3) and transport (§4.4). The full §5 layout
## (inspector, agent/console strip, terrain sketch) is Phase 5 — this stays deliberately lean.

const VivRenderer := preload("res://addons/vivarium/render/viv_renderer.gd")
const VivPalette := preload("res://addons/vivarium/ui/viv_palette.gd")
const CREATURES_DIR := "res://creatures"
const SCENARIOS_DIR := "user://scenarios"
const POLL_INTERVAL := 0.25

var _registry := VivCreatureRegistry.new()
var _watcher := VivFileWatcher.new()
var _runner := VivCreatureRunner.new()
var _ctx := VivDrawContext.new()

var _list: ItemList
var _status: RichTextLabel
var _play_btn: CheckButton
var _mode_btn: OptionButton
var _tunables_box: VBoxContainer
var _sub: SubViewport
var _bg: ColorRect
var _renderer: VivRenderer

var _entries: Array = []
var _current_path := ""
var _active := false
var _poll_accum := 0.0
var _last_respawn_ms := 0.0
var _validator_summary := "clean"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx.palette = VivPaletteRamps.default_creature()
	# A default room: gravity + a floor far below, so dropped creatures settle in view
	# while the pinned-root serpent still hangs freely above it.
	_runner.gravity = Vector2(0.0, 40.0)
	var floor := VivTerrain.new()
	floor.add_floor(90.0, -400.0, 400.0)
	floor.friction = 0.5
	_runner.terrain = floor
	_build_ui()
	_watcher.file_changed.connect(_on_file_changed)
	_watcher.file_added.connect(func(_p): _refresh_list())
	_watcher.file_removed.connect(func(_p): _refresh_list())
	_watcher.set_dir(CREATURES_DIR)
	_refresh_list()
	set_process(true)

func set_active(active: bool) -> void:
	_active = active

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = VivPalette.UI_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 1)
	add_child(root)

	# Left rail — creature list.
	var rail := VBoxContainer.new()
	rail.custom_minimum_size = Vector2(200, 0)
	root.add_child(rail)
	rail.add_child(_header("CREATURES"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_selected)
	rail.add_child(_list)

	# Centre — transport + live viewport.
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	main.add_child(bar)
	_play_btn = CheckButton.new()
	_play_btn.text = "Play"
	bar.add_child(_play_btn)
	_add_button(bar, "Step", func(): if _runner.creature: _runner.step(1))
	_add_button(bar, "Reload", _reload_current)
	_mode_btn = OptionButton.new()
	for name in ["Shaded", "Wireframe", "Chunks", "Skeleton", "Overdraw"]:
		_mode_btn.add_item(name)
	_mode_btn.item_selected.connect(func(i: int): if _renderer: _renderer.mode = i)
	bar.add_child(_mode_btn)

	# Low-res SubViewport, point-upscaled by the container (§4.2).
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.stretch_shrink = 3
	svc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(svc)
	_sub = SubViewport.new()
	_sub.transparent_bg = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(_sub)
	_bg = ColorRect.new()
	_bg.color = VivPalette.ROOM_STONE_LIGHT.darkened(0.55)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(_bg)
	_renderer = VivRenderer.new()
	_renderer.context = _ctx
	_sub.add_child(_renderer)

	_status = RichTextLabel.new()
	_status.custom_minimum_size = Vector2(0, 92)
	_status.bbcode_enabled = true
	_status.add_theme_color_override("default_color", VivPalette.UI_TEXT)
	main.add_child(_status)
	_update_status()

	# Right — inspector: live @export_range tunables (§5) + scenario persistence.
	var insp := VBoxContainer.new()
	insp.custom_minimum_size = Vector2(210, 0)
	insp.add_theme_constant_override("separation", 4)
	root.add_child(insp)
	insp.add_child(_header("INSPECTOR"))
	_tunables_box = VBoxContainer.new()
	_tunables_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	insp.add_child(_tunables_box)
	var scn_bar := HBoxContainer.new()
	insp.add_child(scn_bar)
	_add_button(scn_bar, "Save scn", _save_scenario)
	_add_button(scn_bar, "Load scn", func(): _apply_scenario(_current_path); _rebuild_inspector())

func _add_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", VivPalette.UI_TEXT_DIM)
	return l

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
	_apply_scenario(_current_path)  # restores saved terrain/gravity/tunables if present
	if _runner.load_script(_current_path, true):
		_runner.spawn(1)
	_rebuild_inspector()
	_update_status()

func _scenario_path(creature_path: String) -> String:
	return SCENARIOS_DIR + "/" + creature_path.get_file().get_basename() + ".json"

func _apply_scenario(creature_path: String) -> void:
	var p := _scenario_path(creature_path)
	if FileAccess.file_exists(p):
		VivScenario.apply(_runner, VivScenario.load_from(p))

func _save_scenario() -> void:
	if _current_path == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENARIOS_DIR))
	VivScenario.save(VivScenario.capture(_runner, _current_path), _scenario_path(_current_path))

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
		var lbl := Label.new()
		lbl.text = name
		lbl.add_theme_color_override("font_color", VivPalette.UI_TEXT_DIM)
		row.add_child(lbl)
		var sl := HSlider.new()
		sl.min_value = t["min"]; sl.max_value = t["max"]; sl.step = t["step"]
		sl.value = t["value"]
		var val := Label.new()
		val.text = "%.2f" % float(t["value"])
		sl.value_changed.connect(func(v: float):
			_runner.set_tunable(name, v)
			val.text = "%.2f" % v)
		row.add_child(sl)
		row.add_child(val)
		_tunables_box.add_child(row)

func _reload_current() -> void:
	if _current_path == "":
		return
	_last_respawn_ms = _runner.reload_and_respawn()
	_update_status()

func _on_file_changed(path: String) -> void:
	if path == _current_path:
		_last_respawn_ms = _runner.reload_and_respawn()
		_update_status()
	else:
		_refresh_list()

func _process(delta: float) -> void:
	if not _active:
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		_watcher.poll()
	if _play_btn and _play_btn.button_pressed and _runner.creature:
		_runner.advance(delta)
	_render_frame()

func _render_frame() -> void:
	if _renderer == null or _runner.creature == null:
		return
	var ts := _runner.clock.time_stacker
	_ctx.clear()
	_runner.creature.draw(_ctx, ts)
	_renderer.context = _ctx
	_renderer.creature = _runner.creature
	_renderer.time_stacker = ts
	# Fit creature bounds into the low-res viewport.
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
	# Geometry validators run every tick in the editor (§7.1) — surface a compact summary.
	_validator_summary = VivValidators.summarize(
		VivValidators.validate(_runner.creature.chunks, _ctx))
	_update_status()

func _bounds() -> Array:
	var mn := Vector2(1e30, 1e30)
	var mx := Vector2(-1e30, -1e30)
	for c: VivChunk in _runner.creature.chunks:
		var r := c.radius + 4.0
		mn = mn.min(c.draw_pos(_runner.clock.time_stacker) - Vector2(r, r))
		mx = mx.max(c.draw_pos(_runner.clock.time_stacker) + Vector2(r, r))
	return [mn, mx]

func _update_status() -> void:
	if _status == null:
		return
	if _runner.creature == null:
		_status.text = "[color=#7f8794]No creature selected.[/color]"
		return
	var name := _current_path.get_file()
	_status.text = "[b]%s[/b]  seed %d    chunks %d    tick %d\n" % [
		name, _runner.seed, _runner.creature.chunks.size(), _runner.clock.tick_count]
	_status.text += "hash [color=#d7d52f]%s[/color]    last respawn %.1f ms\n" % [
		_runner.hash_state().substr(0, 20), _last_respawn_ms]
	var clean := _validator_summary == "clean"
	var vcol := "#7fb069" if clean else "#ff6b57"
	_status.text += "validators: [color=%s]%s[/color]" % [vcol, _validator_summary]
