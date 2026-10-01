extends Node

enum Stage { INITIAL_JUMP, PAUSE_AND_RECOVERY, RECOVERY_REQUESTED, MEASUREMENT, REMATCH }
const REQUIRED_REACTIONS := 20
const MAX_MEASUREMENT_ATTEMPTS := 48
const MEASUREMENT_TIMEOUT_MS := 35000

var host := false
var began := 0
var stage := Stage.INITIAL_JUMP
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
var measurement_started := 0
var measurement_commands: Dictionary = {}
var executed_commands: Dictionary = {}
var peer_reactions := 0
var last_progress := 0
var next_state_log := 0
var rematch_recovered := false
var rematch_pause_requested := false
var rematch_pause_seen := false
var failed := false

func _ready() -> void:
	began = Time.get_ticks_msec()
	host = "--host" in OS.get_cmdline_user_args()
	var relay := "--relay" in OS.get_cmdline_user_args()
	blackout = "--blackout" in OS.get_cmdline_user_args()
	Race.changed.connect(_phase_changed)
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
		if d.player == Race.local_player and measurement_commands.has(d.seq):
			if d.status == "EXECUTED": executed_commands[d.seq] = true
			elif d.status == "REJECTED": print("NETWORK REJECTED ", "host" if host else "client", " seq=", d.seq, " reason=", d.reason)
	)
	if host:
		if Race.host_game("127.0.0.1", "penguin", 7779 if relay else 7777) != OK:
			fail("host bind")
			return
		var file := FileAccess.open("res://build/network-invitation.txt", FileAccess.WRITE)
		file.store_string(LanPairing.encode("127.0.0.1", Race.session_id, Race.invitation, 7778) if relay else Race.pairing_code())
	else:
		var text := FileAccess.get_file_as_string("res://build/network-invitation.txt")
		if Race.join_game(text, "panda") != OK: fail("join")

func fail(message: String) -> void:
	failed = true
	printerr("NETWORK FAIL: ", message, " ", _state_description(Time.get_ticks_msec()))
	get_tree().quit(1)

func _state_description(now: int) -> String:
	return "role=%s stage=%s phase=%s generation=%d ready=%s attempts=%d executed=%d reactions=%d peer_reactions=%d ack_age_ms=%d status=%s" % ["host" if host else "client", Stage.keys()[stage], Race.phase, Race.generation, Race.ready_players, attempts, executed_commands.size(), reaction_samples.size(), peer_reactions, now - Race.last_ack, Race.status]

func _phase_changed() -> void:
	if Race.phase == last_phase: return
	var now := Time.get_ticks_msec()
	print("NETWORK PHASE ms=", now, " ", _state_description(now))
	if Race.phase == "race": race_started = now
	if Race.phase == "paused":
		pause_count += 1
		if rematch_started > 0: rematch_pause_seen = true
	if Race.phase == "recovering":
		recovery_seen = true
		if not completed_round.is_empty(): rematch_recovered = true
	last_phase = Race.phase

# Test-only feedback lets the host wait for both peers' measurements. A fixed
# number of submitted jumps cannot guarantee a quota after loss or recovery.
@rpc("any_peer", "call_remote", "reliable", 0)
func _measurement_progress(round_id: String, connection: int, samples: int) -> void:
	if Race.authenticated and multiplayer.get_remote_sender_id() == Race.remote_peer and connection == Race.generation and round_id == Race.config.get("round") and samples >= 0 and samples <= MAX_MEASUREMENT_ATTEMPTS:
		peer_reactions = maxi(peer_reactions, samples)

func _report_progress(now: int) -> void:
	if stage == Stage.MEASUREMENT and Race.authenticated and now - last_progress >= 250:
		last_progress = now
		_measurement_progress.rpc_id(Race.remote_peer, Race.config.round, Race.generation, reaction_samples.size())

func _measurement_done() -> bool:
	return reaction_samples.size() >= REQUIRED_REACTIONS and peer_reactions >= REQUIRED_REACTIONS and executed_commands.size() >= REQUIRED_REACTIONS

func _process(_delta: float) -> void:
	if failed: return
	var now := Time.get_ticks_msec()
	_phase_changed()
	if finished_at > 0:
		if now - finished_at > (1000 if host else 300): get_tree().quit(0)
		return
	if now - began > 80000:
		fail("scenario deadline exceeded")
		return
	if now >= next_state_log:
		next_state_log = now + 2000
		print("NETWORK STATE ms=", now, " ", _state_description(now))
	if Race.phase == "aborted":
		if not host and rematch_started > 0 and rematch_pause_seen and Race.status.contains("opuścił"):
			print("NETWORK PASS client hash=", result_hash)
			finished_at = now
		else: fail(Race.status)
		return
	# Readiness and recovery apply to the rematch too, before its early return.
	if Race.phase in ["lobby", "paused"] and Race.authenticated:
		Race.set_ready()
	_report_progress(now)
	if stage == Stage.MEASUREMENT and now - measurement_started > MEASUREMENT_TIMEOUT_MS:
		fail("opponent reaction quota not reached within measurement deadline")
		return
	if not completed_round.is_empty():
		if Race.phase == "results": Race.set_ready()
		elif Race.phase == "race" and Race.config.round != completed_round:
			if rematch_started == 0:
				rematch_started = now
				if (Race.generation != result_generation and not rematch_recovered) or Race.confirmed.players[0].stars != 0 or Race.confirmed.players[1].stars != 0:
					fail("rematch did not reset state or changed connection without recovery")
					return
				print("NETWORK REMATCH ", "host" if host else "client")
			# Exercise the paused-rematch path that previously waited forever.
			if host and not rematch_pause_requested and now - race_started > 150:
				rematch_pause_requested = true
				Race.request_pause()
				return
			if host and rematch_pause_seen and now - race_started > 500:
				Race.leave()
				print("NETWORK PASS host hash=", result_hash)
				finished_at = now
		return
	if configured and Race.phase == "race":
		predictor.rebuild(Race.presentation_tick(), Race.local_player)
		if predictor.needs_resync:
			fail("prediction history")
			return
		if observed_commands.has(predictor.ghost.flight) and predictor.ghost.ground < 0:
			reaction_samples.append(Race.server_now() - observed_commands[predictor.ghost.flight])
			seen_reactions[predictor.ghost.flight] = true
			observed_commands.erase(predictor.ghost.flight)
		if stage == Stage.INITIAL_JUMP and now - race_started > 200:
			var c := predictor.sim.command(Race.local_player, Race.next_sequence(), "jump", Vector2(120, -600))
			predictor.announce(c)
			Race.submit(c)
			stage = Stage.PAUSE_AND_RECOVERY
		if not host and stage == Stage.PAUSE_AND_RECOVERY and pause_count == 0 and now - race_started > 1600:
			Race.request_pause()
			return
		if not host and stage == Stage.PAUSE_AND_RECOVERY and pause_count == 1 and now - race_started > 600:
			generation_before = Race.generation
			if blackout:
				var signal_file := FileAccess.open("res://build/network-blackout.txt", FileAccess.WRITE)
				signal_file.store_string("start")
			else: Race._begin_recovery()
			stage = Stage.RECOVERY_REQUESTED
			return
		if recovery_seen and pause_count >= 2 and now - race_started > 500:
			if not command_seen:
				fail("no executed command")
				return
			if not host and Race.generation <= generation_before:
				fail("connection generation did not rotate")
				return
			if stage != Stage.MEASUREMENT:
				stage = Stage.MEASUREMENT
				measurement_started = now
			if not _measurement_done() and attempts < MAX_MEASUREMENT_ATTEMPTS and predictor.sim.state.players[Race.local_player].ground >= 0 and now - last_jump > 650:
				var c := predictor.sim.command(Race.local_player, Race.next_sequence(), "jump", Vector2(0, -220))
				c.test_sent_ms = Race.server_now()
				measurement_commands[c.seq] = true
				predictor.announce(c)
				Race.submit(c)
				last_jump = now
				attempts += 1
			if attempts == MAX_MEASUREMENT_ATTEMPTS and not _measurement_done() and now - last_jump > 2000:
				fail("measurement attempts exhausted before both peers reached their quota")
				return
			if host and _measurement_done() and now - last_jump > 1500:
				for p in Race.simulation.state.players:
					p.position = Race.simulation.goal_at(float(Race.simulation.state.tick) / 60) + Vector2(0, 34)
					p.ground = -1
					p.velocity = Vector2.ZERO
	if Race.phase == "results":
		if completed_round.is_empty():
			if not Race.confirmed.ended or Race.simulation.awards().race != [0, 1]:
				fail("results differ")
				return
			if reaction_samples.size() < REQUIRED_REACTIONS:
				fail("too few visible opponent reactions")
				return
			reaction_samples.sort()
			var p95 := reaction_samples[int(ceil(reaction_samples.size() * 0.95)) - 1]
			print("GHOST REACTION samples=", reaction_samples.size(), " p95_ms=", snappedf(p95, 0.1))
			if p95 > 200:
				fail("ghost reaction exceeds 200 ms")
				return
			completed_round = Race.config.round
			result_generation = Race.generation
			result_hash = RaceProtocol.state_hash(Race.confirmed)
			stage = Stage.REMATCH
			Race.set_ready()
