extends SceneTree
## Phase 5 (substance) harness — the testable core of the UI features (§5): live tunables,
## scenario persistence, and multi-instance. The full layout + user-approved side-by-side
## acceptance is separate. Run: godot --headless --path . --script res://test/phase5_harness.gd

const QUAD := "res://creatures/quadruped.gd"
const BLOB := "res://creatures/test_blob.gd"
const SCN := "user://_viv_scenario_test.json"

func _initialize() -> void:
	var fails := 0
	fails += _t_tunables()
	fails += _t_scenario_roundtrip()
	fails += _t_herd()
	print("PHASE5_RESULT: ", "PASS" if fails == 0 else "FAIL(%d)" % fails)
	quit(fails)

# --- live tunables: listed, change behaviour, persist across respawn ----------
func _t_tunables() -> int:
	var terrain := VivTerrain.new()
	terrain.add_floor(40.0, -400.0, 4000.0)
	# default speed
	var r1 := _quad(terrain)
	r1.step(400)
	var dist1: float = (r1.creature.get("body") as VivChunk).pos.x
	# faster speed via a live tunable
	var r2 := _quad(terrain)
	r2.set_tunable("walk_speed", 55.0)
	r2.step(400)
	var dist2: float = (r2.creature.get("body") as VivChunk).pos.x

	var names := VivInspector.list_tunables(r2.creature)
	var listed := _names(names)
	var has_all: bool = listed.has("walk_speed") and listed.has("ride_height") and listed.has("stride")
	var faster: bool = dist2 > dist1 * 1.5
	# persists across respawn (hot reload re-applies overrides)
	r2.reload_and_respawn()
	var persisted: bool = absf(float(r2.creature.get("walk_speed")) - 55.0) < 0.001
	var ok: bool = has_all and faster and persisted
	print("[tunables]     listed %s  faster(%.0f>%.0f):%s  persisted:%s"
		% [listed, dist2, dist1, faster, persisted])
	return 0 if ok else 1

# --- scenario capture -> save -> load -> apply round-trips --------------------
func _t_scenario_roundtrip() -> int:
	var terrain := VivTerrain.new()
	terrain.friction = 0.7
	terrain.add_segment(Vector2(-10, 40), Vector2(200, 30))
	terrain.add_segment(Vector2(200, 30), Vector2(400, 55))
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 50); r.terrain = terrain
	r.load_script(QUAD); r.spawn(3)
	r.set_tunable("walk_speed", 40.0)

	var sc := VivScenario.capture(r, QUAD)
	var saved := VivScenario.save(sc, SCN)
	var loaded := VivScenario.load_from(SCN)
	var r2 := VivCreatureRunner.new()
	VivScenario.apply(r2, loaded)

	var grav_ok: bool = r2.gravity.is_equal_approx(Vector2(0, 50))
	var terr_ok: bool = r2.terrain != null and r2.terrain.size() == 2 and absf(r2.terrain.friction - 0.7) < 0.001
	var tun_ok: bool = absf(float(r2.tunables.get("walk_speed", 0.0)) - 40.0) < 0.001
	var creature_ok: bool = loaded.get("creature", "") == QUAD
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCN))
	var ok: bool = saved and grav_ok and terr_ok and tun_ok and creature_ok
	print("[scenario]     save:%s gravity:%s terrain:%s tunables:%s creature:%s"
		% [saved, grav_ok, terr_ok, tun_ok, creature_ok])
	return 0 if ok else 1

# --- multi-instance: variation across seeds, determinism per seed ------------
func _t_herd() -> int:
	var herd := VivHerd.spawn(BLOB, 5, 100, Vector2(0, 40), null)
	VivHerd.step_all(herd, 200)
	var hashes: Array = []
	var finite := true
	for r: VivCreatureRunner in herd:
		hashes.append(r.hash_state())
		for c: VivChunk in r.creature.chunks:
			if not c.pos.is_finite():
				finite = false
	# all distinct (per-seed variation)
	var distinct := true
	for i in hashes.size():
		for j in range(i + 1, hashes.size()):
			if hashes[i] == hashes[j]:
				distinct = false
	# determinism: a second identical herd matches instance-for-instance
	var herd2 := VivHerd.spawn(BLOB, 5, 100, Vector2(0, 40), null)
	VivHerd.step_all(herd2, 200)
	var deterministic := true
	for i in herd2.size():
		if (herd2[i] as VivCreatureRunner).hash_state() != hashes[i]:
			deterministic = false
	var ok: bool = herd.size() == 5 and finite and distinct and deterministic
	print("[herd]         n:%d finite:%s distinct(variation):%s deterministic:%s"
		% [herd.size(), finite, distinct, deterministic])
	return 0 if ok else 1

# --- helpers -----------------------------------------------------------------
func _quad(terrain: VivTerrain) -> VivCreatureRunner:
	var r := VivCreatureRunner.new()
	r.gravity = Vector2(0, 40); r.terrain = terrain
	r.load_script(QUAD); r.spawn(1)
	return r

func _names(tunables: Array) -> Array:
	var out: Array = []
	for t in tunables:
		out.append(t["name"])
	return out
