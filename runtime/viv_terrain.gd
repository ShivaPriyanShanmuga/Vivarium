@tool
class_name VivTerrain
extends RefCounted
## Segment-soup terrain for swept-circle collision (§2, §4.5): ground profiles, gaps,
## ceilings, poles — anything expressible as line segments. Static: built once, never
## mutated per tick. Collision (VivSolver.resolve_terrain) is two-sided closest-point
## plus a swept crossing test so fast chunks can't tunnel through thin geometry.

var seg_a: PackedVector2Array = PackedVector2Array()
var seg_b: PackedVector2Array = PackedVector2Array()
var friction: float = 0.5   ## 0 slippery .. 1 static (cancels tangential slide)
var bounce: float = 0.0      ## reserved for restitution (Phase 2 keeps it inelastic)

func clear() -> void:
	seg_a.clear()
	seg_b.clear()

func size() -> int:
	return seg_a.size()

func add_segment(a: Vector2, b: Vector2) -> void:
	seg_a.append(a)
	seg_b.append(b)

## Horizontal floor (or ceiling) between x0 and x1 at height y.
func add_floor(y: float, x0: float, x1: float) -> void:
	add_segment(Vector2(x0, y), Vector2(x1, y))

## Vertical pole / wall between y0 and y1 at x.
func add_pole(x: float, y0: float, y1: float) -> void:
	add_segment(Vector2(x, y0), Vector2(x, y1))

## Ground surface y directly under x, searching downward from `from_y` (+y is down).
## Returns the highest surface at or below from_y, or INF if the ray hits nothing.
## Used by legs (grip selection) and kinematic bodies to follow the ground (§4 gaits).
func ground_y(x: float, from_y: float = -1.0e6) -> float:
	var best := INF
	var ray_from := Vector2(x, from_y)
	var ray_to := Vector2(x, 1.0e6)
	for i in size():
		var hit = Geometry2D.segment_intersects_segment(ray_from, ray_to, seg_a[i], seg_b[i])
		if hit is Vector2 and hit.y >= from_y and hit.y < best:
			best = hit.y
	return best

## Four walls of an axis-aligned box (chunks collide on the outside).
func add_box(rect: Rect2) -> void:
	var p := rect.position
	var e := rect.end
	add_segment(Vector2(p.x, p.y), Vector2(e.x, p.y))
	add_segment(Vector2(e.x, p.y), Vector2(e.x, e.y))
	add_segment(Vector2(e.x, e.y), Vector2(p.x, e.y))
	add_segment(Vector2(p.x, e.y), Vector2(p.x, p.y))
