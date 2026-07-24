@tool
class_name VivDrawContext
extends RefCounted
## The surface draw() emits geometry into (§2 Rendering primitives).
##
## Phase 1 STUB: signatures are fixed now so the creature contract is stable and
## draw() compiles, but the methods are no-ops. Phase 3 implements real submission —
## `mesh` is the primitive; quad/strip/ramp/light are sugar over it. Ordering is an
## integer sort key within named, sequentially rendered layers (§2 "No depth buffer"):
## never sort by float, never rely on z-testing. Layers are declared at init.

## Declare a render layer and its integer order (called from init(), lowest drawn first).
func declare_layer(_name: StringName, _sort_order: int) -> void:
	pass

## THE primitive: generated triangle geometry. verts: PackedVector2Array,
## tris: PackedInt32Array (index buffer), colors: PackedColorArray (per-vertex).
func mesh(_layer: StringName, _verts: PackedVector2Array, _tris: PackedInt32Array, _colors: PackedColorArray) -> void:
	pass

## Textured sprite quad (sugar over mesh).
func quad(_layer: StringName, _center: Vector2, _size: Vector2, _rotation: float, _uv: Rect2) -> void:
	pass

## Tapered stroke along a spline -> mesh; tails, antennae, tentacles (sugar over mesh).
func strip(_layer: StringName, _spline: PackedVector2Array, _width_curve: PackedFloat32Array, _color: Color) -> void:
	pass

## Palette ramp lookup by name at parameter t in [0,1] (Phase 3 binds real ramps).
func ramp(_name: StringName, _t: float) -> Color:
	return Color.MAGENTA  # obvious placeholder until Phase 3 palette pass

## Configured light direction for the shading pass.
func light(_dir: Vector2) -> void:
	pass
