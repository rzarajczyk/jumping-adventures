extends Node

var checks := 0
var failures: Array[String] = []

class PhysicsFixture extends Node2D:
	var sim: RaceSimulation
	var body: JumpingPenguin
	var platforms: Array[SkyIsland] = []
	var commands: Array = []
	func _physics_process(_delta: float) -> void:
		sim.step(commands, false)
		commands.clear()
		for island in platforms: island.advance(float(sim.state.tick) / 60.0)

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame
		await get_tree().process_frame

func make_sim() -> RaceSimulation:
	var sim := RaceSimulation.new()
	var level: LevelDefinition = load("res://resources/levels/garden.tres")
	var profile: DifficultyProfile = load("res://resources/difficulties/easy.tres")
	sim.setup(level.layout(profile), "test", 13)
	return sim

func _run() -> void:
	for amplitude in [Vector2.ZERO, Vector2(35, 0), Vector2(0, 35)]:
		await compare_physics(amplitude, Vector2(210, -600), false, false)
		await compare_physics(amplitude, Vector2(0, -850), true, false)
		await compare_physics(amplitude, Vector2(210, -600), false, true)
	await compare_edges()
	for level in 3:
		for difficulty in 3: await compare_route(level, difficulty)
	test_rules()
	test_jetpack_rules()
	test_prediction()
	test_presentation()
	test_session_contracts()
	print("RACE RESULT: %d checks, %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func compare_route(level: int, difficulty: int) -> void:
	var f := PhysicsFixture.new()
	f.process_physics_priority = -10
	f.sim = RaceSimulation.new()
	var data: Array = RaceProtocol.LEVELS[level].layout(RaceProtocol.PROFILES[difficulty])
	f.sim.setup(data, "route", 14)
	for i in data.size():
		var island := SkyIsland.new()
		island.configure(data[i], i, "garden")
		f.add_child(island)
		f.platforms.append(island)
	f.body = JumpingPenguin.new()
	f.body.position = f.sim.state.players[0].position
	f.add_child(f.body)
	add_child(f)
	await frames(6)
	var largest_error := 0.0
	var worst := ""
	var complete := true
	for destination in range(1, 21):
		var t: float = float(f.sim.state.tick) / 60.0
		var shot: Vector2 = f.sim.island_at(destination, t + 1.0) - f.body.position - Vector2(0, 610)
		check(shot.length() <= RaceSimulation.MAX_SPEED, "route jump reachable %d/%d/%d" % [level, difficulty, destination])
		for id in 2: f.commands.append(f.sim.command(id, destination, "jump", shot))
		f.body.jump(shot)
		var reference_landing := -1
		var sim_landing := -1
		for tick in 100:
			await frames(1)
			var error := f.body.position.distance_to(f.sim.state.players[0].position)
			if error > largest_error:
				largest_error = error
				worst = "island=%d frame=%d ref=%s sim=%s ground=%s/%s velocity=%s/%s" % [destination, tick, f.body.position, f.sim.state.players[0].position, f.body.can_jump(), f.sim.state.players[0].ground, f.body.velocity, f.sim.state.players[0].velocity]
			if tick > 1 and f.body.can_jump() and reference_landing < 0: reference_landing = tick
			if tick > 1 and f.sim.state.players[0].ground >= 0 and sim_landing < 0: sim_landing = tick
			if reference_landing >= 0 and sim_landing >= 0: break
		check(reference_landing >= 0 and sim_landing >= 0 and absi(reference_landing - sim_landing) <= 1, "route landing time %d/%d/%d" % [level, difficulty, destination])
		var correct: bool = f.body.last_island != null and f.body.last_island.index == destination and f.sim.state.players[0].ground == destination and f.sim.state.players[1].ground == destination
		check(correct, "route same island for reference and both roles %d/%d/%d" % [level, difficulty, destination])
		if not correct:
			complete = false
			break
		await frames(6)
	check(largest_error <= 2.0, "route differential positions %d/%d error=%f" % [level, difficulty, largest_error])
	print("RACE PHYSICS level=%d difficulty=%d max_error=%.4f" % [level, difficulty, largest_error])
	if largest_error > 2: print(worst)
	# The fixture disables collection so both engines can be compared all the
	# way to landing; verify actual finish contact and shared stars separately.
	check(complete, "all 20 route jumps in both roles %d/%d" % [level, difficulty])
	f.queue_free()
	await frames(2)
	var sim := RaceSimulation.new()
	sim.setup(data, "collect", 14)
	for destination in range(1, 21):
		var p: Dictionary = sim.state.players[0]
		var shot := sim.island_at(destination, float(sim.state.tick) / 60 + 1.0) - (p.position as Vector2) - Vector2(0, 610)
		sim.step([sim.command(0, destination, "jump", shot), sim.command(1, destination, "jump", shot)])
		for tick in 100:
			if sim.state.players[0].ground >= 0 or sim.state.ended: break
			sim.step()
		for tick in 6: sim.step()
	check(sim.state.ended and sim.state.players[0].finish >= 0 and sim.state.players[1].finish >= 0, "both roles finish %d/%d" % [level, difficulty])
	check(sim.state.players[0].stars + sim.state.players[1].stars == 10, "ten shared stars across full route %d/%d" % [level, difficulty])

func test_prediction() -> void:
	var sim := make_sim()
	var artifact: Dictionary
	for item in sim.items:
		if item.kind == 1: artifact = item
	var p: Dictionary = sim.state.players[0]
	p.position = sim.island_at(artifact.island, 0) + Vector2(0, -RaceSimulation.SKIN)
	p.ground = artifact.island
	p.last_island = artifact.island
	var baseline := sim.snapshot()
	var prediction := RacePrediction.new()
	prediction.setup(sim.layout, "test", 13)
	prediction.accept_snapshot(baseline, true)
	prediction.rebuild(1, 0)
	check(prediction.sim.state.players[0].jetpack == 3, "artifact grants predicted inventory without snapshot")
	var boost := prediction.sim.command(0, 1, "jetpack")
	prediction.announce(boost)
	prediction.resolve({"player": 0, "seq": 1, "status": "RECEIVED"})
	check(prediction.commands.size() == 1, "RECEIVED retains command for replay")
	prediction.rebuild(2, 0)
	check(prediction.sim.state.players[0].jetpack == 2 and prediction.sim.state.players[0].velocity.y < -340, "immediate boost uses predicted jetpack")
	# Rival's unseen movement reaches the jetpack first in the authoritative run.
	sim.state.players[1].position = sim.item_at(artifact, 0) + Vector2(0, 34)
	sim.state.players[1].ground = -1
	artifact.priority = 1
	sim.step()
	check(sim.state.owners[artifact.id] == 1, "server can award predicted jetpack to opponent")
	sim.step([boost])
	check(sim.decisions[0].reason == "power", "server denies the entire dependent jetpack launch")
	prediction.resolve(sim.decisions[0])
	prediction.accept_snapshot(sim.snapshot())
	prediction.rebuild(8, 0)
	check(prediction.sim.state.players[0].ground == artifact.island and prediction.sim.state.players[0].jetpack == 0, "reconciliation removes boost movement and inventory")
	prediction.rebuild(sim.state.tick + 19, 0)
	check(prediction.ghost_stale, "opponent prediction stops after 300 ms")
	prediction.rebuild(sim.state.tick + 121, 0)
	check(prediction.needs_resync, "missing replay history requests full synchronization")

func test_session_contracts() -> void:
	Race.set_process(false)
	Race.set_physics_process(false)
	Race.simulation = make_sim()
	Race.confirmed = Race.simulation.snapshot()
	Race.config = {"round": "test"}
	Race.hosting = true
	Race.phase = "race"
	Race.start_ms = LanPairing.now_ms() - 150
	var jump := Race.simulation.command(0, 1, "jump", Vector2(0, -500))
	var previous_round := jump.duplicate(true)
	previous_round.round = "previous"
	Race._accept_command(previous_round, 0)
	check(Race.resolved.is_empty(), "previous round cannot poison reused sequence numbers")
	Race._accept_command(jump, 0)
	Race._accept_command(jump, 0)
	check(Race.pending[1].size() == 1, "duplicate is queued only once")
	Race._physics_process(1.0 / 60)
	Race.simulation.step(Race.pending.get(1, []))
	Race.pending.clear()
	var late := Race.simulation.command(0, 2, "jetpack")
	late.tick = 1
	Race._accept_command(late, 0)
	check(Race.resolved["0:2"].reason == "late", "server rejects late input without retiming")
	var stale := Race.simulation.command(0, 3, "jetpack")
	stale.life += 1
	Race.simulation.step([stale])
	check(Race.simulation.decisions[0].reason == "life", "old-life command cannot act")
	stale = Race.simulation.command(0, 4, "jetpack")
	Race._pause_host()
	var frozen := Race.simulation.snapshot()
	Race._physics_process(50.0)
	check(frozen == Race.simulation.snapshot(), "pause advances no simulation or counters")
	Race._accept_command(stale, 0)
	check(not Race.pending.has(stale.tick) and not Race.resolved.has("0:4"), "pause invalidates outstanding input without poisoning the new epoch")
	Race.resume_token = LanPairing.token()
	Race._begin_recovery()
	var deadline := Race.recovery_deadline
	frozen = Race.simulation.snapshot()
	Race._begin_recovery()
	check(Race.recovery_deadline == deadline, "connection flaps never extend recovery deadline")
	Race.authenticated = true
	Race.remote_peer = 25
	Race.session_id = "session"
	check(not Race._valid_sender(25, {"session": "session", "generation": Race.generation - 1}), "old connection generation is rejected")
	Race.authenticated = false
	Race.remote_peer = 0
	Race.recovery_deadline = LanPairing.now_ms() - 1
	Race._notification(NOTIFICATION_APPLICATION_RESUMED)
	check(Race.phase == "aborted" and Race.simulation.snapshot() == frozen, "resume after deadline aborts without catching up simulation")
	Race.leave(false)

func test_presentation() -> void:
	var actor := RaceActor.new()
	actor.powers = AdventurePowers.new()
	add_child(actor)
	var p: Dictionary = make_sim().state.players[0]
	actor.present(p, 0, 0, false, true)
	actor.correct(Vector2(100, 0))
	for tick in 6:
		if tick == 3: actor.correct(Vector2(-30, 12))
		actor.present(p, 0, 1.0 / 60, false, false)
	check(actor.position.distance_to(p.position) < 0.001, "successive snapshots cannot prolong visual correction beyond 100 ms")
	actor.correct(Vector2(120, 30))
	p.life += 1
	p.position += Vector2(300, -100)
	actor.present(p, 0, 1.0 / 60, false, false)
	check(actor.position == p.position, "respawn changes position without interpolating across the world")
	p.ground = -1
	p.jetpack_tick = 60
	p.jetpack = 2
	actor.present(p, 1.1, 1.0 / 60, false, false)
	check(actor.jetpack_age < AdventurePowers.JETPACK_DURATION and actor.powers.jetpack == 2, "snapshot displays jetpack ignition and charge count")
	actor.present(p, 1.6, 1.0 / 60, false, false)
	check(actor.jetpack_age > AdventurePowers.JETPACK_DURATION, "repeated snapshots do not restart jetpack animation")
	actor.queue_free()

func fixture(amplitude: Vector2, width: float = 6000.0) -> PhysicsFixture:
	var scene := PhysicsFixture.new()
	scene.process_physics_priority = -10
	scene.sim = RaceSimulation.new()
	var data := [{"position": Vector2(220, 450), "width": width, "amplitude": amplitude,
		"period": 6.0, "phase": 0.0, "star": false, "artifact": 0, "goal": false}]
	scene.sim.setup(data, "physics", 2)
	for i in data.size():
		var island := SkyIsland.new()
		island.configure(data[i], i, "garden")
		scene.add_child(island)
		scene.platforms.append(island)
	scene.body = JumpingPenguin.new()
	scene.body.position = Vector2(220, 448)
	scene.add_child(scene.body)
	add_child(scene)
	return scene

func compare_physics(amplitude: Vector2, vector: Vector2, ground_jetpack: bool, air_jetpack: bool) -> void:
	var f := fixture(amplitude)
	await frames(8)
	f.sim.state.players[0].position = f.body.position
	f.sim.state.players[0].jetpack = 3
	f.commands.append(f.sim.command(0, 1, "jetpack" if ground_jetpack else "jump", vector))
	if ground_jetpack: f.body.activate_jetpack()
	else: f.body.jump(vector)
	var max_error := 0.0
	var sim_landing := -1
	var reference_landing := -1
	var worst := ""
	for i in 200:
		if air_jetpack and i in [15, 35, 55]:
			f.commands.append(f.sim.command(0, i + 2, "jetpack"))
			f.body.activate_jetpack()
		await frames(1)
		var error := f.body.position.distance_to(f.sim.state.players[0].position)
		if error > max_error:
			max_error = error
			worst = "frame=%d ref=%s sim=%s floor=%s/%s" % [i, f.body.position, f.sim.state.players[0].position, f.body.can_jump(), f.sim.state.players[0].ground]
		if i > 1 and sim_landing < 0 and f.sim.state.players[0].ground >= 0: sim_landing = i
		if i > 1 and reference_landing < 0 and f.body.can_jump(): reference_landing = i
		if sim_landing >= 0 and reference_landing >= 0 and i > maxi(sim_landing, reference_landing) + 12: break
	var label := "amp=%s ground_jetpack=%s air_jetpack=%s" % [amplitude, ground_jetpack, air_jetpack]
	if max_error > 2.0: print("DIFFERENTIAL ", label, " ", worst)
	check(max_error <= 2.0, "physics positions %s error=%f" % [label, max_error])
	check(sim_landing >= 0 and reference_landing >= 0 and absi(sim_landing - reference_landing) <= 1, "physics landing %s ticks=%d/%d" % [label, sim_landing, reference_landing])
	check(f.sim.state.players[0].ground == f.body.last_island.index, "physics same island " + label)
	f.queue_free()
	await frames(2)

func compare_edges() -> void:
	for offset in [0.0, 142.0, 155.0, 175.0]:
		var f := fixture(Vector2.ZERO, 300.0)
		await frames(6)
		var at := Vector2(220 + offset, 510)
		f.body.position = at
		f.body.velocity = Vector2(0, -620)
		f.body.state = JumpingPenguin.State.AIR
		var p: Dictionary = f.sim.state.players[0]
		p.position = at
		p.velocity = Vector2(0, -620)
		p.ground = -1
		var max_error := 0.0
		var landed_sim := -1
		var landed_ref := -1
		var worst := ""
		for i in 70:
			await frames(1)
			if p.respawn < 0 and f.body.position.distance_to(p.position) > max_error:
				max_error = f.body.position.distance_to(p.position)
				worst = "frame=%d ref=%s sim=%s" % [i, f.body.position, p.position]
			if landed_sim < 0 and p.ground >= 0: landed_sim = i
			if landed_ref < 0 and f.body.can_jump(): landed_ref = i
			if p.respawn >= 0: break
		if max_error > 2.0: print("DIFFERENTIAL edge=", offset, " ", worst)
		check(max_error <= 2.0, "edge/ascent error offset=%f error=%f" % [offset, max_error])
		check((landed_sim < 0 and landed_ref < 0) or (landed_sim >= 0 and landed_ref >= 0 and absi(landed_sim - landed_ref) <= 1), "edge/ascent landing offset=%f ticks=%d/%d" % [offset, landed_sim, landed_ref])
		f.queue_free()
		await frames(2)

func test_rules() -> void:
	var sim := make_sim()
	var packet := RaceProtocol.pack_snapshot(sim.snapshot(), [], [])
	check(RaceProtocol.unpack_snapshot(packet).state == sim.snapshot(), "snapshot compression preserves exact state")
	check(packet.size() < 1100, "snapshot leaves room for RPC envelope below MTU")
	var session := LanPairing.token()
	var token := LanPairing.token()
	var invitation := LanPairing.encode("192.168.1.4", session, token)
	check(LanPairing.decode(invitation).token == token, "QR round trip retains invitation token")
	check(LanPairing.decode("https://example.org").is_empty() and LanPairing.decode(invitation.replace("192.168.1.4", "300.168.1.4")).is_empty(), "malformed QR is rejected")
	var jump := sim.command(0, 1, "jump", Vector2(0, -600))
	sim.step([jump])
	check(sim.decisions[0].status == "EXECUTED", "jump executes")
	var old_jetpack := sim.command(0, 2, "jetpack")
	sim.state.players[0].jetpack = 3
	sim.state.players[0].flight = 99
	sim.step([old_jetpack])
	check(sim.decisions[0].reason == "flight" and sim.state.players[0].jetpack == 3, "jetpack never affects another flight")
	sim.step([jump])
	check(sim.decisions[0].status == "REJECTED", "late jump is not retimed")
	var boosted := sim.command(1, 3, "jetpack")
	sim.step([boosted])
	check(sim.decisions[0].reason == "power" and sim.state.players[1].ground == 0, "empty jetpack cannot launch from ground")
	var snap := sim.snapshot()
	sim.step()
	var expected := sim.snapshot()
	sim.restore(snap)
	sim.step()
	check(sim.snapshot() == expected, "snapshot replay is identical")
	sim = make_sim()
	var star: Dictionary = sim.items[0]
	for p in sim.state.players:
		p.position = sim.item_at(star, 0.0) + Vector2(0, 36)
		p.ground = -1
	sim.step()
	check(sim.state.owners[star.id] == star.priority, "tie uses preassigned item priority")
	check(sim.state.players[0].stars + sim.state.players[1].stars == 1, "shared star granted once")
	var owner: int = sim.state.owners[star.id]
	var p: Dictionary = sim.state.players[owner]
	p.jetpack = 3
	p.position.y = 700
	sim.step()
	check(p.jetpack == 0 and p.stars == 1, "fall clears powers but preserves score")
	var respawn_at: int = p.respawn
	for _i in 179: sim.step()
	check(p.respawn == respawn_at, "no early respawn")
	sim.step()
	check(p.respawn == -1 and p.life == 1 and p.ground == p.last_island, "respawn at exactly 180 ticks")
	check(sim.state.owners[star.id] == owner, "respawn does not restore shared star")
	sim = make_sim()
	for player in sim.state.players:
		player.position = sim.goal_at(0) + Vector2(0, 34)
		player.ground = -1
	sim.step()
	check(sim.state.ended and sim.awards().race == [0, 1], "simultaneous finish ties")
	check(sim.state.players[0].stars == 0 and sim.awards().stars.is_empty(), "finish grants no star; 0:0 has no collector award")
	sim = make_sim()
	sim.state.players[0].position = sim.goal_at(0) + Vector2(0, 34)
	sim.state.players[0].ground = -1
	sim.step()
	for _i in 1798: sim.step()
	check(not sim.state.ended, "second racer retains full finish window")
	sim.step()
	check(sim.state.ended and sim.state.players[1].finish < 0.0, "finish deadline is 1800 active ticks after contact")

func test_jetpack_rules() -> void:
	var sim := make_sim()
	var p: Dictionary = sim.state.players[0]
	p.jetpack = 3
	var command := sim.command(0, 1, "jetpack", Vector2(8000, -9000))
	check(RaceProtocol.valid_command(command), "jetpack command uses current protocol")
	var legacy := command.duplicate(true)
	legacy.kind = "anchor"
	check(not RaceProtocol.valid_command(legacy), "retired anchor command rejected")
	sim.step([command], false)
	check(sim.decisions[0].status == "EXECUTED" and p.jetpack == 2 and p.ground == -1, "ground jetpack spends one charge")
	check((p.velocity - Vector2(0, RaceSimulation.GRAVITY * RaceSimulation.DT)).is_equal_approx(AdventurePowers.launch_vector(1)), "client vector cannot alter jetpack strength or angle")
	for seq in [2, 3]:
		p.velocity = Vector2(-600, 500)
		p.facing = -1.0
		sim.step([sim.command(0, seq, "jetpack")], false)
		check(sim.decisions[0].status == "EXECUTED" and p.jetpack == 3 - seq, "repeated airborne jetpack spends exactly one charge")
		check((p.velocity - Vector2(0, RaceSimulation.GRAVITY * RaceSimulation.DT)).is_equal_approx(AdventurePowers.launch_vector(-1)), "falling backwards jetpack has fixed launch")
	sim.step([sim.command(0, 4, "jetpack")], false)
	check(sim.decisions[0].reason == "power" and p.jetpack == 0, "fourth use rejected")
	p.jetpack = 1
	command = sim.command(0, 5, "jetpack")
	p.landing += 1
	sim.step([command], false)
	check(sim.decisions[0].reason == "landing" and p.jetpack == 1, "old landing jetpack cannot spend a charge")
	for inactive in ["respawn", "finish"]:
		p[inactive] = 99
		sim.step([sim.command(0, 6, "jetpack")], false)
		check(sim.decisions[0].reason == "inactive" and p.jetpack == 1, "inactive racer cannot use jetpack: " + inactive)
		p[inactive] = -1
