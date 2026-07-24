@tool
class_name VivSimClock
extends RefCounted
## Fixed-tick accumulator with an independent render clock (§2, master-prompt §10).
##
## Rain World simulates at 40 TPS (one tick every 25 ms) and renders on a separate
## clock, interpolating between the two most recent ticks. `advance(real_dt)` consumes
## real elapsed seconds and reports how many fixed sim ticks are due; `time_stacker`
## is the render-time interpolation alpha in [0,1) that draw() feeds to lerp(last, cur).

const TPS := 40
const DT := 1.0 / 40.0  # 0.025 s fixed timestep

var _accum := 0.0
## Interpolation alpha for draw(): 0 == at previous tick, ->1 == approaching current tick.
var time_stacker := 0.0
## Total fixed ticks advanced since construction.
var tick_count := 0

## Consume `real_dt` seconds; return the number of fixed ticks to run now.
## `max_ticks` clamps the spiral-of-death after a stall (long pause / breakpoint).
func advance(real_dt: float, max_ticks: int = 8) -> int:
	_accum += real_dt
	var n := 0
	while _accum >= DT and n < max_ticks:
		_accum -= DT
		n += 1
	tick_count += n
	if _accum > DT:  # clamp leftover after hitting max_ticks so alpha stays in range
		_accum = fmod(_accum, DT)
	time_stacker = clampf(_accum / DT, 0.0, 1.0)
	return n

## Reset for a fresh spawn / deterministic replay.
func reset() -> void:
	_accum = 0.0
	time_stacker = 0.0
	tick_count = 0
