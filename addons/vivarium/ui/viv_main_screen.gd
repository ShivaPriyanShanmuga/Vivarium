@tool
extends Control
## Phase 1 shell for the Vivarium workspace tab. Proves the code<->motion loop in-editor:
## discover creatures in the watched dir, select one, run it at the fixed tick rate, and
## hot-reload on save. The real §5 layout (large viewport, inspector, agent/console strip,
## view modes, transport) is Phase 5 — this is deliberately minimal but functional.

const VivPalette := preload("res://addons/vivarium/ui/viv_palette.gd")
const CREATURES_DIR := "res://creatures"
const POLL_INTERVAL := 0.25  # seconds between watcher polls

var _registry := VivCreatureRegistry.new()
var _watcher := VivFileWatcher.new()
var _runner := VivCreatureRunner.new()

var _list: ItemList
var _status: RichTextLabel
var _play_btn: CheckButton
var _entries: Array = []
var _current_path := ""
var _active := false
var _poll_accum := 0.0
var _last_respawn_ms := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_watcher.file_changed.connect(_on_file_changed)
	_watcher.file_added.connect(func(_p): _refresh_list())
	_watcher.file_removed.connect(func(_p): _refresh_list())
	_watcher.set_dir(CREATURES_DIR)
	_refresh_list()
	set_process(true)

## Called by the plugin when the tab is shown/hidden — gate work to when visible.
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

	# Left rail — creature list (selection is global state, §5).
	var rail := VBoxContainer.new()
	rail.custom_minimum_size = Vector2(220, 0)
	root.add_child(rail)
	rail.add_child(_header("CREATURES"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_list_selected)
	rail.add_child(_list)

	# Centre/right — transport + status (viewport placeholder until Phase 3).
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	main.add_child(bar)
	_play_btn = CheckButton.new()
	_play_btn.text = "Play"
	bar.add_child(_play_btn)
	var reload_btn := Button.new()
	reload_btn.text = "Reload"
	reload_btn.pressed.connect(_reload_current)
	bar.add_child(reload_btn)
	var step_btn := Button.new()
	step_btn.text = "Step"
	step_btn.pressed.connect(func(): if _runner.creature: _runner.step(1); _update_status())
	bar.add_child(step_btn)

	var viewport_placeholder := ColorRect.new()
	viewport_placeholder.color = VivPalette.ROOM_STONE_LIGHT.darkened(0.55)
	viewport_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(viewport_placeholder)
	var vp_label := Label.new()
	vp_label.text = "  viewport — Phase 3"
	vp_label.modulate = VivPalette.UI_TEXT_DIM
	viewport_placeholder.add_child(vp_label)

	_status = RichTextLabel.new()
	_status.custom_minimum_size = Vector2(0, 110)
	_status.bbcode_enabled = true
	_status.add_theme_color_override("default_color", VivPalette.UI_TEXT)
	main.add_child(_status)
	_update_status()

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
	# Keep current selection alive, else select the first.
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
	if _runner.load_script(_current_path, true):
		_runner.spawn(1)
	_update_status()

func _reload_current() -> void:
	if _current_path == "":
		return
	_last_respawn_ms = _runner.reload_and_respawn()
	_update_status()

func _on_file_changed(path: String) -> void:
	# Any change to a creature refreshes discovery; a change to the live one respawns it.
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
		_update_status()

func _update_status() -> void:
	if _status == null:
		return
	if _runner.creature == null:
		_status.text = "[color=#7f8794]No creature selected.[/color]"
		return
	var name := _current_path.get_file()
	_status.text = "[b]%s[/b]  seed %d\n" % [name, _runner.seed]
	_status.text += "chunks: %d    tick: %d    t_stack: %.2f\n" % [
		_runner.creature.chunks.size(), _runner.clock.tick_count, _runner.clock.time_stacker]
	_status.text += "hash: [color=#d7d52f]%s[/color]\n" % _runner.hash_state().substr(0, 24)
	_status.text += "last respawn: %.1f ms" % _last_respawn_ms
