class_name RaceWorld
extends PenguinWorld

var prediction := RacePrediction.new()
var actors: Array[RaceActor] = []
var indicator: OpponentIndicator
var seen_events: Dictionary = {}
var needs_reconcile := false
var needs_snap := true
var round_id := ""
var view: Dictionary = {}

func _ready() -> void:
	# Reuse the environment, artwork, gesture routing and particle drawing. The
	# single-player physics/collection loop is overridden, never run in a race.
	super._ready()
	for island in islands:
		island.sync_to_physics = false
		island.collision_layer = 0
		island.collision_mask = 0
	remove_child(player)
	player.queue_free()
	for id in 2:
		var actor := RaceActor.new()
		actor.character_id = Race.characters[id]
		actor.powers = powers if id == Race.local_player else AdventurePowers.new()
		if id != Race.local_player:
			actor.modulate = Color(0.88, 0.83, 1.0, 0.45)
			actor.z_index = 4
		add_child(actor)
		if id != Race.local_player: actor.z_index = 4
		actors.append(actor)
	player = actors[Race.local_player]
	prediction.setup(definition.layout(profile), Race.config.round, Race.config.seed)
	round_id = Race.config.round
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	indicator = OpponentIndicator.new()
	indicator.world = self
	indicator.character = Race.characters[1 - Race.local_player]
	indicator.ui_font = load("res://assets/fonts/Nunito.ttf")
	layer.add_child(indicator)
	Race.snapshot_received.connect(_snapshot_received)
	Race.command_announced.connect(_command_announced)
	Race.command_resolved.connect(_command_resolved)
	Race.race_event.connect(_confirmed_event)
	Race.changed.connect(_phase_changed)
	_snapshot_received(Race.confirmed, true)
	_phase_changed()

func _snapshot_received(value: Dictionary, reset: bool) -> void:
	if value.is_empty() or value.round != round_id: return
	prediction.accept_snapshot(value, reset)
	needs_reconcile = not reset
	needs_snap = needs_snap or reset
	star_count = value.players[Race.local_player].stars
	stars_changed.emit(star_count)
	if reset: cancel_gesture()

func _command_announced(c: Dictionary) -> void:
	prediction.announce(c)

func _command_resolved(result: Dictionary) -> void:
	prediction.resolve(result)
	if result.status == "REJECTED": needs_reconcile = true

func _phase_changed() -> void:
	effects.set_physics_process(Race.phase == "race")
	if Race.phase != "race": cancel_gesture()

func _physics_process(delta: float) -> void:
	if prediction.baseline.is_empty(): return
	var target := Race.presentation_tick()
	# Compare at the SAME presentation tick. Comparing last frame's visible
	# position with this frame's advanced position would smooth ordinary motion
	# on every snapshot and introduce a permanent extra visual delay.
	if needs_reconcile and not needs_snap and not view.is_empty() and view.tick >= prediction.baseline.tick:
		prediction.rebuild(view.tick, Race.local_player)
		for id in 2:
			var corrected: Dictionary = prediction.sim.state.players[id] if id == Race.local_player else prediction.ghost
			actors[id].correct(actors[id].simulation_position - corrected.position)
	prediction.rebuild(target, Race.local_player)
	if prediction.needs_resync:
		Race.request_resync()
		return
	view = prediction.sim.state
	clock = float(view.tick) / RaceSimulation.HZ
	elapsed = clock
	for island in islands: island.advance(maxf(0.0, clock - RaceSimulation.DT))
	for id in 2:
		var p: Dictionary = view.players[id] if id == Race.local_player else prediction.ghost
		actors[id].present(p, clock, delta, false, needs_snap)
	needs_reconcile = false
	needs_snap = false
	var local: Dictionary = view.players[Race.local_player]
	finished = local.finish >= 0.0
	goal_collected = false
	furthest = local.furthest
	splash_time = maxf(0, 3.0 - float(local.respawn - view.tick) / 60.0) if local.respawn >= 0 else -1.0
	splash_position = Vector2(local.position.x, 647)
	if not player.can_jump() and (gesture.pointer != -99 or powers.armed): cancel_gesture()
	if gesture.pointer != -99 and player.can_jump(): player.state = JumpingPenguin.State.AIMING
	for item in stars: item.taken = view.owners["star:%d" % item.island.index] >= 0
	for item in artifacts: item.taken = view.owners["power:%d" % item.island.index] >= 0
	for event in prediction.events:
		if event.player == Race.local_player and event.kind in ["jump", "anchor", "land", "fall"]: _effect_once(event)
	var other: Dictionary = prediction.ghost
	var target_position: Vector2 = other.position + Vector2(0, -40)
	var remaining := 0
	if other.respawn >= 0:
		target_position = prediction.sim.island_at(other.last_island, clock) + Vector2(0, -40)
		remaining = maxi(1, int(ceil(float(other.respawn - view.tick) / 60.0)))
	indicator.update_target(target_position, remaining, prediction.ghost_stale)
	_update_race_camera(delta, actors[1 - Race.local_player] if finished else actors[Race.local_player])
	powers_changed.emit()
	island_reached.emit(furthest)
	queue_redraw()

func _confirmed_event(event: Dictionary) -> void:
	if not str(event.id).begins_with(round_id + ":"): return
	_effect_once(event)

func _effect_once(event: Dictionary) -> void:
	if seen_events.has(event.id): return
	seen_events[event.id] = true
	if event.player != Race.local_player: return
	match event.kind:
		"jump": Sound.effect("super_jump" if event.boosted else "jump")
		"anchor":
			Sound.effect("anchor")
			effects.catch_air(player.position + Vector2(0, -35), player.facing)
		"land": Sound.effect("land")
		"fall": Sound.effect("splash")
		"star":
			Sound.effect("star")
			particles.append({"position": event.position, "born": clock})
		"artifact":
			Sound.effect("artifact")
			effects.burst(event.position, AdventurePowers.WIND_COLOR if event.power_kind == 1 else AdventurePowers.ANCHOR_COLOR)
			artifact_collected.emit(event.get("power_kind", 1), event.position)
		"finish": Sound.effect("win")

func _powers_allowed() -> bool:
	return Race.phase == "race" and not Race.suspended and not view.is_empty() and not finished and splash_time < 0.0

func can_arm_wind() -> bool:
	return _powers_allowed() and powers.wind > 0 and player.can_jump() and gesture.pointer == -99

func can_use_anchor() -> bool:
	return _powers_allowed() and powers.anchor > 0 and not powers.anchor_used and player.state == JumpingPenguin.State.AIR

func launch(vector: Vector2) -> bool:
	if not _powers_allowed() or not player.can_jump() or vector == Vector2.ZERO: return false
	var c := prediction.sim.command(Race.local_player, Race.next_sequence(), "jump", vector, powers.armed and powers.wind > 0)
	prediction.announce(c)
	powers.disarm()
	player.aim = Vector2.ZERO
	Race.submit(c)
	return true

func use_anchor() -> bool:
	if not can_use_anchor(): return false
	var c := prediction.sim.command(Race.local_player, Race.next_sequence(), "anchor")
	prediction.announce(c)
	Race.submit(c)
	return true

func _begin(id: int, at: Vector2) -> void:
	if _powers_allowed(): super._begin(id, at)

func _unhandled_input(event: InputEvent) -> void:
	if Race.phase == "race": super._unhandled_input(event)

func _update_race_camera(delta: float, focus: RaceActor) -> void:
	var viewport_size := get_viewport_rect().size
	var desired_zoom := 1.0
	if focus.boosted_flight:
		var apex: float = focus.simulation_position.y - minf(0.0, focus.velocity.y) ** 2 / (2.0 * RaceSimulation.GRAVITY) - 110
		desired_zoom = minf(1.0, (WATER_Y - 142) / maxf(1, WATER_Y - apex))
	camera.zoom = Vector2.ONE * lerpf(camera.zoom.x, desired_zoom, 1.0 - exp(-delta * 8.0))
	var visible_width := viewport_size.x / camera.zoom.x
	var look := -0.15 if focus.velocity.x < -1 else 0.25
	var target_x := maxf(visible_width * 0.5, focus.simulation_position.x + visible_width * look)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-delta * 5.0))
	camera.position.y = WATER_Y - (WATER_Y - viewport_size.y * 0.5) / camera.zoom.y
