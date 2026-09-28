extends Node

var host := false
var began := 0
var stage := 0
var last_phase := ""
var race_started := 0
var pause_count := 0
var recovery_seen := false
var command_seen := false
var predictor := RacePrediction.new()
var configured := false
var generation_before := 0
var finished_at := 0
var blackout := false
var attempts := 0
var last_jump := 0
var observed_commands: Dictionary = {}
var reaction_samples: Array[float] = []
var seen_reactions: Dictionary = {}
var completed_round := ""
var result_hash := ""
var rematch_started := 0
var result_generation := 0

func _ready() -> void:
	began = Time.get_ticks_msec()
	host = "--host" in OS.get_cmdline_user_args()
	var relay := "--relay" in OS.get_cmdline_user_args()
	blackout = "--blackout" in OS.get_cmdline_user_args()
	Race.snapshot_received.connect(func(value: Dictionary, reset: bool):
		if not configured or value.round != predictor.baseline.get("round"):
			predictor.setup(Race.simulation.layout, value.round, Race.config.seed)
			configured = true
		predictor.accept_snapshot(value, reset)
	)
	Race.command_announced.connect(func(c: Dictionary):
		predictor.announce(c)
		if c.player != Race.local_player and c.has("test_sent_ms") and not seen_reactions.has(c.seq): observed_commands[c.seq] = c.test_sent_ms
	)
	Race.command_resolved.connect(func(d: Dictionary):
		predictor.resolve(d)
		if d.status == "EXECUTED": command_seen = true
	)
	if host:
		if Race.host_game("127.0.0.1", "penguin", 7779 if relay else 7777) != OK: fail("host bind")
		var file := FileAccess.open("res://build/network-invitation.txt", FileAccess.WRITE)
		file.store_string(LanPairing.encode("127.0.0.1", Race.session_id, Race.invitation, 7778) if relay else Race.pairing_code())
	else:
		var text := FileAccess.get_file_as_string("res://build/network-invitation.txt")
		if Race.join_game(text, "panda") != OK: fail("join")

func fail(message: String) -> void:
	printerr("NETWORK FAIL: ", message)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if finished_at > 0:
		if now - finished_at > (1000 if host else 300): get_tree().quit(0)
		return
	if now - began > 80000:
		fail("timeout phase=%s status=%s" % [Race.phase, Race.status])
		return
	if not completed_round.is_empty():
		if Race.phase == "results": Race.set_ready()
		elif Race.phase == "race" and Race.config.round != completed_round:
			if rematch_started == 0:
				rematch_started = now
				if Race.generation != result_generation or Race.confirmed.players[0].stars != 0 or Race.confirmed.players[1].stars != 0:
					fail("rematch did not reset state on the same connection")
					return
				print("NETWORK REMATCH ", "host" if host else "client")
			if host and now - rematch_started > 500:
				Race.leave()
				print("NETWORK PASS host hash=", result_hash)
				finished_at = now
		elif Race.phase == "aborted" and not host and rematch_started > 0 and Race.status.contains("opuścił"):
			print("NETWORK PASS client hash=", result_hash)
			finished_at = now
		return
	if Race.phase != last_phase:
		print("NETWORK ", "host" if host else "client", " phase=", Race.phase, " generation=", Race.generation)
		if Race.phase == "race": race_started = now
		if Race.phase == "paused": pause_count += 1
		if Race.phase == "recovering": recovery_seen = true
		last_phase = Race.phase
	if Race.phase == "aborted":
		fail(Race.status)
		return
	if Race.phase in ["lobby", "paused"] and Race.authenticated:
		Race.set_ready()
	if configured and Race.phase == "race":
		predictor.rebuild(Race.presentation_tick(), Race.local_player)
		if predictor.needs_resync: fail("prediction history")
		if observed_commands.has(predictor.ghost.flight) and predictor.ghost.ground < 0:
			reaction_samples.append(Race.server_now() - observed_commands[predictor.ghost.flight])
			seen_reactions[predictor.ghost.flight] = true
			observed_commands.erase(predictor.ghost.flight)
		if stage == 0 and now - race_started > 200:
			var c := predictor.sim.command(Race.local_player, Race.next_sequence(), "jump", Vector2(120, -600))
			predictor.announce(c)
			Race.submit(c)
			stage = 1
		if not host and stage == 1 and pause_count == 0 and now - race_started > 1600:
			Race.request_pause()
		if not host and stage == 1 and pause_count == 1 and now - race_started > 600:
			generation_before = Race.generation
			if blackout:
				var signal_file := FileAccess.open("res://build/network-blackout.txt", FileAccess.WRITE)
				signal_file.store_string("start")
			else: Race._begin_recovery()
			stage = 2
		if recovery_seen and pause_count >= 2 and now - race_started > 500:
			if not command_seen: fail("no executed command")
			if not host and Race.generation <= generation_before: fail("connection generation did not rotate")
			if attempts < 24 and predictor.sim.state.players[Race.local_player].ground >= 0 and now - last_jump > 650:
				var c := predictor.sim.command(Race.local_player, Race.next_sequence(), "jump", Vector2(0, -220))
				c.test_sent_ms = Race.server_now()
				predictor.announce(c)
				Race.submit(c)
				last_jump = now
				attempts += 1
			if host and attempts == 24 and reaction_samples.size() >= 20 and now - last_jump > 1500:
				for p in Race.simulation.state.players:
					p.position = Race.simulation.goal_at(float(Race.simulation.state.tick) / 60) + Vector2(0, 34)
					p.ground = -1
					p.velocity = Vector2.ZERO
	if Race.phase == "results":
		if completed_round.is_empty():
			if not Race.confirmed.ended or Race.simulation.awards().race != [0, 1]: fail("results differ")
			if reaction_samples.size() < 20: fail("too few visible opponent reactions")
			reaction_samples.sort()
			var p95 := reaction_samples[int(ceil(reaction_samples.size() * 0.95)) - 1]
			print("GHOST REACTION samples=", reaction_samples.size(), " p95_ms=", snappedf(p95, 0.1))
			if p95 > 200:
				fail("ghost reaction exceeds 200 ms")
				return
			completed_round = Race.config.round
			result_generation = Race.generation
			result_hash = RaceProtocol.state_hash(Race.confirmed)
			Race.set_ready()
