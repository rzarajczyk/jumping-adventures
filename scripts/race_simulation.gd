class_name RaceSimulation
extends RefCounted
## Replayable 60 Hz race rules. No nodes, rendering, wall clock, or network access.

const HZ := 60
const DT := 1.0 / HZ
const GRAVITY := 1200.0
const MAX_SPEED := 850.0
const WATER_Y := 642.0
const RESPAWN_TICKS := 180
const FINISH_TICKS := 1800
const TIE_SECONDS := 0.001
const SKIN := 0.05
const RADIUS := 17.0
const CONTACT_EPSILON := 0.00005

var layout: Array = []
var items: Array = []
var state: Dictionary = {}
var events: Array = []
var decisions: Array = []

func setup(data: Array, round_id: String, seed_value: int) -> void:
	layout = data.duplicate(true)
	items.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in layout.size():
		if layout[i].star:
			items.append({"id": "star:%d" % i, "island": i, "kind": 0, "priority": rng.randi_range(0, 1)})
		if layout[i].artifact != 0:
			items.append({"id": "power:%d" % i, "island": i, "kind": layout[i].artifact, "priority": rng.randi_range(0, 1)})
	var owners: Dictionary = {}
	for item in items: owners[item.id] = -1
	state = {"round": round_id, "epoch": 0, "revision": 0, "tick": 0, "players": [new_player(), new_player()], "owners": owners, "deadline": -1.0, "ended": false}
	events.clear()
	decisions.clear()

func new_player() -> Dictionary:
	return {"position": island_at(0, 0) + Vector2(0, -SKIN), "velocity": Vector2.ZERO,
		"ground": 0, "last_island": 0, "landing": 0, "life": 0, "flight": 0,
		"wind": 0, "anchor": 0, "anchor_used": false, "boosted": false,
		"facing": 1.0, "respawn": -1, "finish": -1.0, "stars": 0, "furthest": 0}

func snapshot() -> Dictionary:
	return state.duplicate(true)

func restore(value: Dictionary) -> void:
	state = value.duplicate(true)
	events.clear()
	decisions.clear()

func island_at(index: int, seconds: float) -> Vector2:
	var data: Dictionary = layout[index]
	# AnimatableBody2D commits the transform on the following physics step in
	# the campaign. Make that single-step phase explicit and replayable here.
	var phase_time := maxf(0.0, seconds - DT)
	return data.position + data.amplitude * sin(TAU * phase_time / data.period + data.phase)

func item_at(item: Dictionary, seconds: float) -> Vector2:
	var height := -64.0 if item.kind == 0 else -66.0
	var speed := 2.5 if item.kind == 0 else 2.4
	return island_at(item.island, seconds) + Vector2(0, height + sin(seconds * speed + item.island) * 5.0)

func goal_at(seconds: float) -> Vector2:
	return island_at(layout.size() - 1, seconds) + Vector2(0, -92 + sin(seconds * 2.0) * 6)

func command(player: int, seq: int, kind: String, vector: Vector2 = Vector2.ZERO, boosted: bool = false) -> Dictionary:
	var p: Dictionary = state.players[player]
	return {"round": state.round, "epoch": state.epoch, "seq": seq, "tick": state.tick + 1,
		"player": player, "life": p.life, "landing": p.landing, "flight": p.flight,
		"kind": kind, "vector": vector, "boosted": boosted}

func apply_command(c: Dictionary) -> String:
	if c.round != state.round or c.epoch != state.epoch: return "epoch"
	if c.tick != state.tick: return "tick"
	var p: Dictionary = state.players[c.player]
	if c.life != p.life: return "life"
	if p.respawn >= 0 or p.finish >= 0.0: return "inactive"
	if c.kind == "jump":
		if p.ground < 0 or c.landing != p.landing: return "landing"
		var v: Vector2 = c.vector
		if not v.is_finite() or v.length() > MAX_SPEED + 0.01 or v.y >= 0.0: return "vector"
		if c.boosted and p.wind <= 0: return "power"
		p.velocity = v * (sqrt(2.0) if c.boosted else 1.0)
		p.ground = -1
		p.flight = c.seq
		p.boosted = c.boosted
		if c.boosted: p.wind -= 1
		if absf(v.x) > 1.0: p.facing = signf(v.x)
		_event("jump", c.player, str(c.seq), {"boosted": c.boosted})
	elif c.kind == "anchor":
		if p.ground >= 0 or c.flight != p.flight: return "flight"
		if p.anchor <= 0 or p.anchor_used: return "power"
		p.velocity = Vector2.ZERO
		p.anchor -= 1
		p.anchor_used = true
		_event("anchor", c.player, str(c.seq))
	else:
		return "kind"
	return ""

func step(commands: Array = [], collect: bool = true) -> void:
	events.clear()
	decisions.clear()
	if state.ended: return
	var before: Array = state.players.duplicate(true)
	state.tick += 1
	state.revision += 1
	for c in commands:
		var reason := apply_command(c)
		decisions.append({"player": c.player, "seq": c.seq, "tick": state.tick, "status": "EXECUTED" if reason.is_empty() else "REJECTED", "reason": reason})
	for i in 2:
		_move_player(i, before[i].ground)
	if collect: _contacts(before)
	for i in 2:
		var p: Dictionary = state.players[i]
		if p.finish < 0.0 and p.respawn < 0 and (p.position.y >= WATER_Y or p.position.x < -100.0):
			p.respawn = state.tick + RESPAWN_TICKS
			p.ground = -1
			p.velocity = Vector2.ZERO
			p.wind = 0
			p.anchor = 0
			p.boosted = false
			p.anchor_used = false
			_event("fall", i, str(p.life))
	if (state.players[0].finish >= 0.0 and state.players[1].finish >= 0.0) or (state.deadline >= 0.0 and float(state.tick) / HZ >= state.deadline):
		state.ended = true
		_event("results", -1, "end")

func _move_player(id: int, previous_ground: int) -> void:
	var p: Dictionary = state.players[id]
	var t: float = float(state.tick) / HZ
	if p.finish >= 0.0: return
	if p.respawn >= 0:
		if state.tick >= p.respawn:
			p.position = island_at(p.last_island, t) + Vector2(0, -SKIN)
			p.velocity = Vector2.ZERO
			p.ground = p.last_island
			p.life += 1
			p.landing += 1
			p.flight = 0
			p.respawn = -1
			_event("respawn", id, str(p.life))
		return
	# Godot carries a grounded body with the platform, including the takeoff frame,
	# but PLATFORM_ON_LEAVE_DO_NOTHING does not add its velocity to the jump.
	if previous_ground >= 0:
		p.position += island_at(previous_ground, t) - island_at(previous_ground, t - DT)
	if p.ground >= 0:
		p.velocity = Vector2.ZERO
		p.position.y = island_at(p.ground, t).y - SKIN
		return
	# Match GodotPhysics' one-way recovery at the top of a capsule ascending
	# through the 8-unit one-way margin (four 40% recovery iterations).
	if p.velocity.y < 0.0:
		for i in layout.size():
			var surface := island_at(i, t)
			var cap: Vector2 = p.position - Vector2(0, RADIUS)
			var closest := Vector2(clampf(cap.x, surface.x - layout[i].width * 0.5, surface.x + layout[i].width * 0.5), surface.y)
			var normal := cap - closest
			var penetration := RADIUS - normal.length()
			if normal.y < 0.0 and penetration > 0.0 and penetration < 8.0:
				p.position += normal.normalized() * (penetration + SKIN) * (1.0 - pow(0.6, 4))
	var start: Vector2 = p.position
	p.velocity.y += GRAVITY * DT
	var end: Vector2 = start + p.velocity * DT
	var landing := -1
	var earliest := 2.0
	var landing_y := 0.0
	for i in layout.size():
		var old := island_at(i, t - DT)
		var now := island_at(i, t)
		# A platform moving upwards can meet a descending capsule. One-way
		# platforms must never catch an ascending body from below.
		var relative_dy := (end.y - start.y) - (now.y - old.y)
		if relative_dy <= 0.0 or start.y > old.y + 0.1: continue
		# A tangent endpoint has not crossed the one-way surface yet. Use a
		# subpixel tolerance for float32 integration at large world coordinates.
		var fraction := (old.y + CONTACT_EPSILON - start.y) / relative_dy
		if fraction < -0.02 or fraction > 1.0: continue
		fraction = clampf(fraction, 0.0, 1.0)
		var x := lerpf(start.x, end.x, fraction)
		var center := lerpf(old.x, now.x, fraction)
		var outside := maxf(0.0, absf(x - center) - layout[i].width * 0.5)
		if outside > RADIUS * 0.707: continue
		var round_offset := RADIUS - sqrt(maxf(0.0, RADIUS * RADIUS - outside * outside))
		fraction = (old.y + round_offset + CONTACT_EPSILON - start.y) / relative_dy
		if fraction >= -0.02 and fraction <= 1.0 and fraction < earliest:
			earliest = fraction
			landing = i
			landing_y = now.y + round_offset - SKIN
	if landing >= 0:
		end.y = landing_y
		p.velocity = Vector2.ZERO
		p.ground = landing
		p.last_island = landing
		p.furthest = maxi(p.furthest, landing)
		p.landing += 1
		p.anchor_used = false
		p.boosted = false
		_event("land", id, str(p.landing))
	p.position = end

static func contact_fraction(a: Vector2, b: Vector2, radius: float) -> float:
	if a.length_squared() <= radius * radius: return 0.0
	var d := b - a
	var aa := d.length_squared()
	if aa < 0.000001: return INF
	var bb := 2.0 * a.dot(d)
	var cc := a.length_squared() - radius * radius
	var discriminant := bb * bb - 4.0 * aa * cc
	if discriminant < 0.0: return INF
	var hit := (-bb - sqrt(discriminant)) / (2.0 * aa)
	return hit if hit >= 0.0 and hit <= 1.0 else INF

func _contacts(before: Array) -> void:
	var t0: float = float(state.tick - 1) / HZ
	var t1 := t0 + DT
	var finish_hits := [INF, INF]
	for id in 2:
		if before[id].respawn >= 0 or before[id].finish >= 0.0: continue
		finish_hits[id] = contact_fraction(before[id].position + Vector2(0, -34) - goal_at(t0), state.players[id].position + Vector2(0, -34) - goal_at(t1), 68.0)
	for item in items:
		if state.owners[item.id] >= 0: continue
		var hits := [INF, INF]
		for id in 2:
			if before[id].respawn >= 0 or before[id].finish >= 0.0: continue
			var offset := Vector2(0, -36 if item.kind == 0 else -34)
			var hit := contact_fraction(before[id].position + offset - item_at(item, t0), state.players[id].position + offset - item_at(item, t1), 54.0 if item.kind == 0 else 48.0)
			if hit <= finish_hits[id] and (state.deadline < 0.0 or t0 + hit * DT <= state.deadline): hits[id] = hit
		if is_inf(hits[0]) and is_inf(hits[1]): continue
		var winner: int = 0 if hits[0] < hits[1] else 1
		if not is_inf(hits[0]) and not is_inf(hits[1]) and absf(hits[0] - hits[1]) * DT <= TIE_SECONDS: winner = item.priority
		state.owners[item.id] = winner
		var p: Dictionary = state.players[winner]
		if item.kind == 0: p.stars += 1
		elif item.kind == 1: p.wind = 3
		else: p.anchor = 3
		_event("star" if item.kind == 0 else "artifact", winner, item.id, {"power_kind": item.kind, "position": item_at(item, t0 + hits[winner] * DT)})
	for id in 2:
		if is_inf(finish_hits[id]): continue
		var at: float = t0 + finish_hits[id] * DT
		if state.deadline >= 0.0 and at > state.deadline: continue
		var p: Dictionary = state.players[id]
		p.finish = at
		p.velocity = Vector2.ZERO
		if state.deadline < 0.0 or at + 30.0 < state.deadline: state.deadline = at + 30.0
		_event("finish", id, "finish")

func _event(kind: String, player: int, key: String, extra: Dictionary = {}) -> void:
	var event := {"id": "%s:%s:%d:%s:%s" % [state.round, state.epoch, player, kind, key], "kind": kind, "player": player, "tick": state.tick}
	event.merge(extra)
	events.append(event)

func awards() -> Dictionary:
	var a: Dictionary = state.players[0]
	var b: Dictionary = state.players[1]
	var race: Array = []
	if a.finish >= 0.0 and b.finish >= 0.0 and absf(a.finish - b.finish) <= TIE_SECONDS: race = [0, 1]
	elif a.finish >= 0.0 and (b.finish < 0.0 or a.finish < b.finish): race = [0]
	elif b.finish >= 0.0: race = [1]
	var stars: Array = []
	if a.stars > 0 or b.stars > 0:
		stars = [0, 1] if a.stars == b.stars else ([0] if a.stars > b.stars else [1])
	return {"race": race, "stars": stars}
