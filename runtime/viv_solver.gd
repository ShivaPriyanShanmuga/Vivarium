@tool
class_name VivSolver
extends RefCounted
## The simulation step (§2, Phase 2). Position-Based Dynamics in the Verlet family:
##
##   1. integrate         semi-implicit Euler; momentum carried in chunk.vel
##   2. iterate:          distance constraints, flex constraints, swept-circle terrain
##   3. reconcile_velocity  vel = (pos - last_pos)/dt  — the key to stable settling:
##      constraint/terrain corrections are folded back into velocity, so a resting
##      chunk's pos stops changing and its velocity decays to zero (no explode/jitter).
##
## last_pos is set by the host BEFORE tick() (VivCreature.store_last_positions), so it is
## both the render-interpolation anchor and the Verlet "previous position". Determinism:
## fixed dt, no wall-clock, iteration over ordered arrays only.

const EPS := 1e-6

static func step(creature, world: VivWorld, dt: float, iterations: int = 8) -> void:
	integrate(creature.chunks, world.gravity, dt)
	for _i in iterations:
		solve_connections(creature.connections)
		solve_flexes(creature.flexes)
		if world.terrain != null:
			resolve_terrain(creature.chunks, world.terrain)
	reconcile_velocity(creature.chunks, dt)

static func integrate(chunks: Array, gravity: Vector2, dt: float) -> void:
	for c: VivChunk in chunks:
		c.grounded = false
		if c.pinned:
			continue
		c.vel += gravity * dt
		c.vel *= (1.0 - c.drag)
		c.pos += c.vel * dt

static func solve_connections(connections: Array) -> void:
	for con: VivConnection in connections:
		var a := con.a
		var b := con.b
		var d := b.pos - a.pos
		var dist := d.length()
		if dist < EPS:
			continue
		if con.type == VivConnection.Type.ELASTIC and dist <= con.rest_length:
			continue  # rope: resists stretch only
		var wa := a.inv_mass()
		var wb := b.inv_mass()
		var wsum := wa + wb
		if wsum == 0.0:
			continue
		var diff := (dist - con.rest_length) / dist
		var corr := d * (diff * con.stiffness)
		a.pos += corr * (wa / wsum)
		b.pos -= corr * (wb / wsum)

static func solve_flexes(flexes: Array) -> void:
	# Angle constraint as a law-of-cosines distance constraint on the far pair (a,c).
	for f: VivFlex in flexes:
		var a := f.a
		var b := f.b
		var c := f.c
		var u := a.pos - b.pos
		var v := c.pos - b.pos
		var lu := u.length()
		var lv := v.length()
		if lu < EPS or lv < EPS:
			continue
		var rest_ac := sqrt(maxf(0.0, lu * lu + lv * lv - 2.0 * lu * lv * cos(f.target_angle)))
		var d := c.pos - a.pos
		var dist := d.length()
		if dist < EPS:
			continue
		var wa := a.inv_mass()
		var wc := c.inv_mass()
		var wsum := wa + wc
		if wsum == 0.0:
			continue
		var diff := (dist - rest_ac) / dist
		var corr := d * (diff * f.stiffness)
		a.pos += corr * (wa / wsum)
		c.pos -= corr * (wc / wsum)

static func resolve_terrain(chunks: Array, terrain: VivTerrain) -> void:
	var n_seg := terrain.size()
	for c: VivChunk in chunks:
		if c.pinned:
			continue
		var r := c.radius
		for i in n_seg:
			var sa := terrain.seg_a[i]
			var sb := terrain.seg_b[i]
			# Swept anti-tunnel: if the tick's motion crossed the segment, snap back to
			# the crossing; the closest-point push below then lifts the chunk out by r.
			var hit = Geometry2D.segment_intersects_segment(c.last_pos, c.pos, sa, sb)
			if hit is Vector2:
				c.pos = hit
			var q := Geometry2D.get_closest_point_to_segment(c.pos, sa, sb)
			var delta := c.pos - q
			var dist := delta.length()
			if dist < r:
				var n: Vector2
				if dist > EPS:
					n = delta / dist
				else:
					# Center on the line: pick the side the chunk came from.
					var dl := c.last_pos - Geometry2D.get_closest_point_to_segment(c.last_pos, sa, sb)
					n = dl.normalized() if dl.length() > EPS else (sb - sa).orthogonal().normalized()
				c.pos = q + n * r
				c.grounded = true
				# Position-based friction: cancel tangential slide since last_pos.
				var motion := c.pos - c.last_pos
				var tangent := motion - n * motion.dot(n)
				c.pos -= tangent * terrain.friction

static func reconcile_velocity(chunks: Array, dt: float) -> void:
	var inv_dt := 1.0 / dt
	for c: VivChunk in chunks:
		if c.pinned:
			c.vel = Vector2.ZERO
			continue
		c.vel = (c.pos - c.last_pos) * inv_dt
