@tool
class_name VivIK
extends RefCounted
## Two-bone inverse kinematics (§2 Limb). Given a root (hip), a target (foot), bone lengths
## l1 (thigh) and l2 (shin), and a bend sign (+1 / -1 = which side the knee bends), return
## the mid joint (knee) position. Law of cosines, clamped to the reachable range so an
## over- or under-extended target never produces NaN (the classic §7 failure mode).

static func solve_two_bone(root: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var to := target - root
	var dist := to.length()
	if dist < 0.00001:
		return root + Vector2(0, l1)  # degenerate: target on root
	var dir := to / dist
	# Clamp reach into (|l1-l2|, l1+l2) so the triangle is always solvable.
	var d := clampf(dist, absf(l1 - l2) + 0.0001, l1 + l2 - 0.0001)
	# Distance from root to the knee's projection onto the root->target line.
	var a := (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var base := root + dir * a
	return base + dir.orthogonal() * (h * signf(bend))
