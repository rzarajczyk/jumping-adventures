class_name RacePrediction
extends RefCounted
## Both phones use this, including the hosting phone. RECEIVED never commits.
var sim := RaceSimulation.new()
var baseline: Dictionary = {}
var commands: Dictionary = {}
var ghost: Dictionary = {}
var ghost_stale := false
var events: Array = []
var needs_resync := false

func setup(layout: Array, round_id: String, seed_value: int) -> void:
	sim.setup(layout, round_id, seed_value)
	baseline = sim.snapshot()
	commands.clear()
	needs_resync = false

func accept_snapshot(value: Dictionary, reset: bool = false) -> void:
	if not reset and not baseline.is_empty() and (value.round != baseline.round or value.epoch != baseline.epoch or value.tick < baseline.tick): return
	if reset: commands.clear()
	baseline = value.duplicate(true)
	for key in commands.keys():
		var c: Dictionary = commands[key]
		if c.round != value.round or c.epoch != value.epoch or c.tick <= value.tick: commands.erase(key)
	needs_resync = false

func announce(c: Dictionary) -> void:
	if baseline.is_empty() or c.round != baseline.round or c.epoch != baseline.epoch or c.tick <= baseline.tick: return
	commands["%d:%d" % [c.player, c.seq]] = c.duplicate(true)

func resolve(result: Dictionary) -> void:
	if result.get("round", baseline.get("round")) != baseline.get("round") or result.get("epoch", baseline.get("epoch")) != baseline.get("epoch"): return
	if result.status == "REJECTED": commands.erase("%d:%d" % [result.player, result.seq])

func rebuild(target: int, local_player: int) -> void:
	if baseline.is_empty(): return
	needs_resync = target - baseline.tick > RaceSession.HISTORY_TICKS
	if needs_resync: return
	sim.restore(baseline)
	events.clear()
	ghost = sim.state.players[1 - local_player].duplicate(true)
	ghost_stale = target - baseline.tick > RaceSession.GHOST_TICKS
	var by_tick: Dictionary = {}
	for c in commands.values():
		if not by_tick.has(c.tick): by_tick[c.tick] = []
		by_tick[c.tick].append(c)
	while sim.state.tick < target and not sim.state.ended:
		var step_commands: Array = by_tick.get(sim.state.tick + 1, [])
		step_commands.sort_custom(func(a: Dictionary, b: Dictionary): return a.seq < b.seq if a.player == b.player else a.player < b.player)
		sim.step(step_commands)
		events.append_array(sim.events)
		if sim.state.tick - baseline.tick <= RaceSession.GHOST_TICKS:
			ghost = sim.state.players[1 - local_player].duplicate(true)
