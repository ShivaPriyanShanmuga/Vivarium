extends SceneTree
# Headless API smoke test — VERIFY Godot 4.7 primitives Phase 1 depends on.
# Run: godot --headless --path . --script res://test/smoke.gd

func _initialize() -> void:
	var ok := true
	print("Godot version: ", Engine.get_version_info())

	# 1) RandomNumberGenerator determinism (per-instance seeded PRNG).
	var a := RandomNumberGenerator.new(); a.seed = 12345
	var b := RandomNumberGenerator.new(); b.seed = 12345
	var seq_a := []; var seq_b := []
	for i in 5:
		seq_a.append(a.randf()); seq_b.append(b.randf())
	var det := seq_a == seq_b
	print("[rng] same seed -> same sequence: ", det, "  sample=", seq_a[0])
	# state save/restore (needed for snapshot/replay in §4.4)
	var c := RandomNumberGenerator.new(); c.seed = 999
	c.randf(); var st := c.state; var nxt := c.randf(); c.state = st
	var restored := is_equal_approx(c.randf(), nxt)
	print("[rng] state save/restore: ", restored)
	ok = ok and det and restored

	# 2) FileAccess.get_modified_time (mtime polling for the file watcher).
	var p := "res://test/smoke.gd"
	var abs := ProjectSettings.globalize_path(p)
	var mt := FileAccess.get_modified_time(abs)
	print("[file] get_modified_time(abs)=", mt, " has_method_ok=", mt > 0)
	ok = ok and mt > 0

	# 3) DirAccess listing (creature discovery).
	var count := 0
	var d := DirAccess.open("res://test")
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir(): count += 1
			f = d.get_next()
	print("[dir] files in res://test: ", count)
	ok = ok and count >= 1

	# 4) High-res timing (respawn budget measurement).
	var t0 := Time.get_ticks_usec()
	var acc := 0.0
	for i in 100000: acc += sqrt(float(i))
	var dt_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[time] 100k-iter loop ms=", dt_ms, " (acc=", acc, ")")

	# 5) Dynamic script load + instantiate (hot-reload mechanism).
	var scr := load("res://test/probe_creature.gd")
	if scr != null:
		var inst = scr.new()
		var has_tick: bool = inst.has_method("tick")
		print("[load] probe_creature loaded, has tick(): ", has_tick)
		ok = ok and has_tick
	else:
		print("[load] FAILED to load probe_creature.gd"); ok = false

	# 6) Deterministic byte hashing of floats (state hash) via HashingContext SHA-256.
	var buf := PackedFloat64Array([1.0, 2.5, -3.25, seq_a[0]])
	var h1 := _sha(buf.to_byte_array())
	var h2 := _sha(PackedFloat64Array([1.0, 2.5, -3.25, seq_a[0]]).to_byte_array())
	print("[hash] sha256 stable: ", h1 == h2, " h=", h1.substr(0, 16))
	# global hash() also available as a fast in-run hash:
	var gh: int = hash(buf)
	print("[hash] global hash(PackedFloat64Array)=", gh)
	ok = ok and (h1 == h2)

	print("SMOKE_RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
