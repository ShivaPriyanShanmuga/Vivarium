@tool
class_name VivCreatureRunner
extends RefCounted
## Owns one live creature instance and the loop between code and motion (§1, §3):
## load the user's actual creature script, spawn it deterministically, step it at the
## fixed rate, and hot-reload from disk on edit under the 300 ms budget.

signal respawned(ms: float)

var creature_script_path := ""
var creature_script: GDScript
var creature: VivCreature
var world: VivWorld
var clock := VivSimClock.new()
var seed := 0

## Load (or reload) the creature script from disk. `fresh` compiles a standalone GDScript
## from the file text, bypassing Godot's ResourceLoader AND GDScript compile caches so an
## on-disk edit actually takes effect (CACHE_MODE_REPLACE alone returns the cached compile).
func load_script(path: String, fresh: bool = false) -> bool:
	creature_script_path = path
	if fresh:
		if not FileAccess.file_exists(path):
			return false
		var text := FileAccess.get_file_as_string(path)
		var gd := GDScript.new()
		gd.source_code = text
		var err := gd.reload()
		if err != OK:
			push_error("Vivarium: reload of %s failed (%d)" % [path, err])
			return false
		creature_script = gd
	else:
		creature_script = load(path)
	return creature_script != null

## Instantiate + init the creature deterministically for `seed_value`.
func spawn(seed_value: int) -> bool:
	if creature_script == null:
		return false
	seed = seed_value
	world = VivWorld.new(seed_value)
	var inst = creature_script.new()
	if not (inst is VivCreature):
		push_error("Vivarium: %s is not a VivCreature" % creature_script_path)
		return false
	creature = inst
	creature.setup(world, seed_value)
	clock.reset()
	return true

## Run exactly `n` fixed ticks. store_last BEFORE tick so draw() can interpolate (§2).
func step(n: int) -> void:
	for _i in n:
		creature.store_last_positions()
		creature.tick(VivSimClock.DT)

## Advance by real elapsed seconds (fixed-tick accumulator + render interpolation).
func advance(real_dt: float) -> int:
	var n := clock.advance(real_dt)
	step(n)
	return n

## Reload the edited script and respawn with the same seed. Returns elapsed milliseconds
## (Phase 1 acceptance: < 300 ms). This is the source-edit -> reload -> respawn loop (§5).
func reload_and_respawn() -> float:
	var t0 := Time.get_ticks_usec()
	load_script(creature_script_path, true)
	spawn(seed)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	respawned.emit(ms)
	return ms

func hash_state() -> String:
	return VivHasher.hash_creature(creature)

## Enforce §2: draw() must not mutate sim state. Snapshot the hash, draw into a stub
## context, and confirm the hash is unchanged. Returns true if pure.
func assert_draw_pure(ctx: VivDrawContext) -> bool:
	var before := hash_state()
	creature.draw(ctx, clock.time_stacker)
	return hash_state() == before
