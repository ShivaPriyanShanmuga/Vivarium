@tool
class_name VivHasher
extends RefCounted
## Deterministic state hashing (§2 Determinism, §7 gate for the AI loop).
##
## SHA-256 over the IEEE-754 bytes of a creature's state floats — stable across runs
## and machines (unlike Variant hash()), so an outcome can be attributed to an edit.
## Full-precision Float64 bytes are used for the canonical hash; `hash_quantized` is
## available when tiny FP jitter should be tolerated in a comparison.

static func hash_creature(c: VivCreature) -> String:
	return hash_floats(c.get_state_floats())

static func hash_floats(f: PackedFloat64Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(f.to_byte_array())
	return ctx.finish().hex_encode()

## Hash after rounding to `decimals` — use only where sub-ulp determinism isn't required.
static func hash_quantized(f: PackedFloat64Array, decimals: int = 6) -> String:
	var scale := pow(10.0, decimals)
	var q := PackedFloat64Array()
	q.resize(f.size())
	for i in f.size():
		q[i] = round(f[i] * scale) / scale
	return hash_floats(q)
