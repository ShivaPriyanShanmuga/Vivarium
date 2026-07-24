@tool
class_name VivMetrics
extends RefCounted
## Motion metrics (§7.2) — computed by the tool over a recorded scenario run and displayed
## beside the reference so the user sees *why* motion reads wrong, not just that it does.
## These are static functions over time series the host records; the agent (§6) reads the
## same numbers through `measure()`.

## Foot slide: the largest horizontal drift of a contact point while it is planted. Near
## zero is the goal — it catches most bad gaits by itself (§7.2).
static func foot_slide(x_series: PackedFloat64Array, planted: Array) -> float:
	var worst := 0.0
	var lo := INF
	var hi := -INF
	var in_stance := false
	for i in planted.size():
		if planted[i]:
			if not in_stance:
				lo = x_series[i]; hi = x_series[i]; in_stance = true
			else:
				lo = minf(lo, x_series[i]); hi = maxf(hi, x_series[i])
		elif in_stance:
			worst = maxf(worst, hi - lo)
			in_stance = false
	if in_stance:
		worst = maxf(worst, hi - lo)
	return worst

## Duty factor: fraction of the cycle a foot is planted (stance). Walk > 0.5, run < 0.5.
static func duty_factor(planted: Array) -> float:
	if planted.is_empty():
		return 0.0
	var n := 0
	for p in planted:
		if p:
			n += 1
	return float(n) / float(planted.size())

## Number of steps (stance -> swing transitions) in the series.
static func step_count(planted: Array) -> int:
	var steps := 0
	for i in range(1, planted.size()):
		if planted[i - 1] and not planted[i]:
			steps += 1
	return steps

## Stride frequency in steps/second for this foot.
static func stride_frequency(planted: Array, dt: float) -> float:
	var secs := float(planted.size()) * dt
	if secs <= 0.0:
		return 0.0
	return float(step_count(planted)) / secs

## Stride length: mean forward distance between successive touch-downs.
static func stride_length(x_series: PackedFloat64Array, planted: Array) -> float:
	var lands := PackedFloat64Array()
	for i in range(1, planted.size()):
		if not planted[i - 1] and planted[i]:
			lands.append(x_series[i])
	if lands.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(1, lands.size()):
		total += absf(lands[i] - lands[i - 1])
	return total / float(lands.size() - 1)

## Centre-of-mass vertical oscillation amplitude about a moving-average trend — this is what
## makes weight read correctly (§7.2). `window` ~ one gait cycle in ticks.
static func com_oscillation(y_series: PackedFloat64Array, window: int = 40) -> float:
	var n := y_series.size()
	if n == 0:
		return 0.0
	var hi := -INF
	var lo := INF
	for i in n:
		var a := maxi(0, i - window / 2)
		var b := mini(n - 1, i + window / 2)
		var sum := 0.0
		for j in range(a, b + 1):
			sum += y_series[j]
		var trend := sum / float(b - a + 1)
		var d := y_series[i] - trend
		hi = maxf(hi, d); lo = minf(lo, d)
	return (hi - lo) * 0.5  # amplitude

## Min/max of a series (e.g., a limb's hip->foot extension envelope).
static func envelope(series: PackedFloat64Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for v in series:
		lo = minf(lo, v); hi = maxf(hi, v)
	return Vector2(lo, hi)
