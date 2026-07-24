extends RefCounted
# Minimal probe object for the smoke test's dynamic-load check.

var x := 0.0

func tick(dt: float) -> void:
	x += dt
