@tool
extends EditorPlugin
## Vivarium — Godot editor main-screen plugin (the IDE, §5). Registers a "Vivarium"
## workspace tab alongside 2D/3D/Script. Phase 1 wires the host loop into a minimal
## shell; the full §5 layout (viewport, inspector, agent/console) lands in Phase 5.

const MainScreen := preload("res://addons/vivarium/ui/viv_main_screen.gd")

var _main: Control

func _enter_tree() -> void:
	_main = MainScreen.new()
	_main.name = "Vivarium"
	EditorInterface.get_editor_main_screen().add_child(_main)
	_make_visible(false)

func _exit_tree() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
	_main = null

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Vivarium"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("AnimationPlayer", "EditorIcons")

func _make_visible(visible: bool) -> void:
	if is_instance_valid(_main):
		_main.visible = visible
		_main.set_active(visible)
