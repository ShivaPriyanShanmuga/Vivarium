@tool
class_name VivFlex
extends RefCounted
## A flex constraint over a chain of three chunks a-b-c that resists folding at the
## joint b toward `target_angle` (§2). "Much of the alive feel" comes from this.
##
## Implemented (VivSolver) as an angle-preserving distance constraint on the far pair
## (a,c): the rest a-c distance is derived from the current limb lengths and the target
## angle via the law of cosines, so it maintains the ANGLE regardless of limb length.

var a: VivChunk
var b: VivChunk   ## the joint
var c: VivChunk
var target_angle: float  ## radians, the angle a-b-c is pulled toward
var stiffness: float

func _init(a_: VivChunk = null, b_: VivChunk = null, c_: VivChunk = null,
		target: float = PI, stiffness_: float = 0.5) -> void:
	a = a_
	b = b_
	c = c_
	target_angle = target
	stiffness = clampf(stiffness_, 0.0, 1.0)
