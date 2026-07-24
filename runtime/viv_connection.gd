@tool
class_name VivConnection
extends RefCounted
## A distance constraint between two chunks (§2 Simulation primitives).
##
##   RIGID   — hold rest_length exactly (stiffness ~1): bones.
##   SPRING  — soft pull toward rest_length (stiffness < 1): flesh, dangly bits.
##   ELASTIC — resist stretch past rest_length only, free to compress: rope, tails.
##
## Solved positionally (PBD) by VivSolver; stiffness in [0,1] is the fraction of the
## correction applied per iteration.

enum Type { RIGID, SPRING, ELASTIC }

var a: VivChunk
var b: VivChunk
var rest_length: float
var type: int
var stiffness: float

func _init(a_: VivChunk = null, b_: VivChunk = null, rest: float = 0.0,
		type_: int = Type.RIGID, stiffness_: float = 1.0) -> void:
	a = a_
	b = b_
	rest_length = rest
	type = type_
	stiffness = clampf(stiffness_, 0.0, 1.0)
