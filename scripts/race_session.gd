class_name RaceSession
extends Node
## Stable autoload RPC path. Authority never consumes client positions or scores.

signal changed
signal snapshot_received(value: Dictionary, reset: bool)
signal command_announced(command: Dictionary)
signal command_resolved(result: Dictionary)
signal race_event(event: Dictionary)

const INPUT_BUFFER := 9
const HISTORY_TICKS := 120
const GHOST_TICKS := 18
const RECOVERY_MS := 60000
const HEARTBEAT_MS := 250
const LOSS_MS := 1000

var phase := "idle"
var status := ""
var hosting := false
var local_player := 0
var remote_peer := 0
var authenticated := false
var generation := 0
var session_id := ""
var invitation := ""
var resume_token := ""
var address := ""
var port := LanPairing.PORT
var characters := ["penguin", "penguin"]
var level_index := 0
var difficulty := 0
var ready_players := [false, false]
var config: Dictionary = {}
var simulation := RaceSimulation.new()
var confirmed: Dictionary = {}
var pending: Dictionary = {}
var resolved: Dictionary = {}
var sequence := 0
var received_sequences := [0, 0]
var loaded_players := [false, false]
var clock_ready := false
var offset_ms := 0.0
var rtt_ms := 0.0
var samples: Array = []
var start_ms := 0.0
var base_tick := 0
var recovery_deadline := 0
var recovery_return := "paused"
var stable_since := 0
var peer_stable := false
var state_acknowledged := false
var stable_reported := false
var last_ack := 0
var last_frame := 0
var last_ping := 0
var ping_sequence := 0
var outstanding_pings: Dictionary = {}
var last_attempt := 0
var connect_started := 0
var suspended := false
var _closing := false
var _clock_announced := false
var _draining: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)

func active() -> bool:
	return not phase in ["idle", "aborted"]

func host_game(ip: String, character: String, listen_port: int = LanPairing.PORT) -> Error:
	leave(false)
	for item in _draining: item.transport.close()
	_draining.clear()
	if not LanPairing.valid_ip(ip): return ERR_INVALID_PARAMETER
	var transport := ENetMultiplayerPeer.new()
	transport.set_bind_ip(ip)
	var error := transport.create_server(listen_port, 1, 4)
	if error != OK:
		status = "Nie można utworzyć gry. Sprawdź Wi-Fi i spróbuj ponownie."
		changed.emit()
		return error
	multiplayer.multiplayer_peer = transport
	hosting = true
	local_player = 0
	address = ip
	port = listen_port
	session_id = LanPairing.token()
	invitation = LanPairing.token()
	characters = [AdventureCharacters.valid_id(character), "penguin"]
	phase = "lobby"
	status = "Drugi gracz skanuje kod QR."
	changed.emit()
	return OK

func join_game(payload: String, character: String) -> Error:
	var data := LanPairing.decode(payload)
	if data.is_empty():
		status = "Nieprawidłowy kod QR Jumping Adventure."
		changed.emit()
		return ERR_INVALID_DATA
	leave(false)
	hosting = false
	local_player = 1
	address = data.ip
	port = int(data.port)
	session_id = data.session
	invitation = data.token
	characters[1] = AdventureCharacters.valid_id(character)
	phase = "connecting"
	status = "Łączenie z gospodarzem…"
	changed.emit()
	return _connect_transport()

func pairing_code() -> String:
	return LanPairing.encode(address, session_id, invitation, port)

func _connect_transport() -> Error:
	_close_transport()
	var transport := ENetMultiplayerPeer.new()
	var error := transport.create_client(address, port, 4)
	if error != OK:
		if phase != "recovering": _abort("Nie można połączyć się z gospodarzem.")
		return error
	multiplayer.multiplayer_peer = transport
	connect_started = LanPairing.now_ms()
	last_attempt = connect_started
	return OK

func leave(notify_peer: bool = true) -> void:
	var graceful := notify_peer and authenticated
	if graceful:
		_send("leave")
	_close_transport(graceful)
	phase = "idle"
	status = ""
	hosting = false
	local_player = 0
	remote_peer = 0
	generation = 0
	session_id = ""
	invitation = ""
	resume_token = ""
	ready_players = [false, false]
	loaded_players = [false, false]
	characters = ["penguin", "penguin"]
	config.clear()
	confirmed.clear()
	simulation.state.clear()
	pending.clear()
	resolved.clear()
	sequence = 0
	received_sequences = [0, 0]
	recovery_deadline = 0
	_reset_clock()
	changed.emit()

func _close_transport(drain: bool = false) -> void:
	_closing = true
	var transport := multiplayer.multiplayer_peer
	if drain and transport is ENetMultiplayerPeer and remote_peer > 0:
		transport.get_peer(remote_peer).peer_disconnect_later()
		transport.host.flush()
		# Keep pumping ENet acknowledgments after detaching the game session.
		# Immediate close can discard the reliable leave packet before delivery.
		_draining.append({"transport": transport, "until": LanPairing.now_ms() + 2000})
	else: transport.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	authenticated = false
	remote_peer = 0
	_closing = false

func _connected() -> void:
	if hosting or not phase in ["connecting", "recovering"]: return
	remote_peer = 1
	_control.rpc_id(1, {"op": "hello", "version": RaceProtocol.VERSION, "fingerprint": RaceProtocol.fingerprint(),
		"session": session_id, "token": resume_token if phase == "recovering" else invitation,
		"resume": phase == "recovering", "character": characters[1]})

func _peer_connected(peer: int) -> void:
	if hosting and remote_peer == 0:
		# This is a transport candidate, not yet a participant.
		remote_peer = peer
		connect_started = LanPairing.now_ms()

func _connection_failed() -> void:
	if _closing: return
	if phase == "recovering":
		_close_transport()
	else: _abort("Nie znaleziono gospodarza. Połącz oba telefony z tym samym Wi-Fi. Router może blokować połączenia między urządzeniami.")

func _server_disconnected() -> void:
	if not _closing and active(): _begin_recovery()

func _peer_disconnected(peer: int) -> void:
	if not _closing and hosting and peer == remote_peer and active():
		var was_authenticated := authenticated
		remote_peer = 0
		authenticated = false
		if was_authenticated: _begin_recovery()

func _evict_remote() -> void:
	var old_peer := remote_peer
	remote_peer = 0
	authenticated = false
	if old_peer <= 0 or not multiplayer.multiplayer_peer is ENetMultiplayerPeer: return
	var transport: ENetMultiplayerPeer = multiplayer.multiplayer_peer
	transport.disconnect_peer(old_peer, true)
	# Forced ENet eviction deliberately omits this signal. SceneMultiplayer
	# still needs it to discard its RPC path/peer cache before a new admission.
	transport.peer_disconnected.emit(old_peer)

func _send(op: String, fields: Dictionary = {}) -> void:
	if remote_peer == 0: return
	var message := {"op": op, "session": session_id, "generation": generation}
	message.merge(fields, true)
	_control.rpc_id(remote_peer, message)

func _valid_sender(sender: int, message: Dictionary) -> bool:
	return authenticated and sender == remote_peer and message.get("session") == session_id and message.get("generation") == generation

@rpc("any_peer", "call_remote", "reliable", 0)
func _control(message: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if var_to_bytes(message).size() > 65536: return
	var op: String = message.get("op", "") if message.get("op", "") is String else ""
	if op == "hello" and hosting:
		_accept_hello(sender, message)
		return
	if op == "welcome" and not hosting and sender == 1 and message.get("session") == session_id and phase in ["connecting", "recovering"]:
		_accept_welcome(message)
		return
	if op == "error" and not hosting and sender == 1 and phase == "connecting":
		_abort(str(message.get("message", "Nie można dołączyć.")))
		return
	if not _valid_sender(sender, message): return
	match op:
		"lobby":
			if not hosting:
				level_index = message.level
				difficulty = message.difficulty
				characters = message.characters
				ready_players = message.ready
				phase = "lobby"
				changed.emit()
		"selection":
			if hosting and phase == "lobby" and message.get("character") in AdventureCharacters.IDS:
				characters[1] = message.character
				ready_players = [false, false]
				_publish_lobby()
		"ready":
			if hosting and phase in ["lobby", "paused", "results"]:
				ready_players[1] = true
				_try_ready()
		"load":
			if not hosting: _load_round(message.config)
		"loaded":
			if hosting and phase == "loading" and message.get("round") == config.round:
				loaded_players[1] = true
				_try_start()
		"clock_ready":
			if hosting:
				clock_ready = true
				_try_start()
		"timeline":
			if not hosting:
				_install_snapshot(message.state, true)
				base_tick = message.state.tick
				start_ms = message.start
				ready_players = [false, false]
				phase = "countdown"
				changed.emit()
		"pause":
			if hosting: _pause_host()
		"paused":
			if not hosting:
				_install_snapshot(message.state, true)
				ready_players = message.ready
				phase = "paused"
				changed.emit()
		"state_ack":
			if hosting and phase == "recovering": state_acknowledged = message.get("hash") == _recovery_hash()
		"stable":
			if hosting and phase == "recovering": peer_stable = message.get("hash") == _recovery_hash()
		"unstable":
			if hosting and phase == "recovering": peer_stable = false
		"recovered":
			if not hosting and phase == "recovering" and not _expired():
				recovery_deadline = 0
				phase = message.phase
				ready_players = [false, false]
				changed.emit()
		"resync":
			if hosting and phase in ["race", "countdown", "paused"]: _pause_host()
		"event":
			if not hosting: race_event.emit(message.event)
		"results":
			if not hosting:
				_install_snapshot(message.state, false)
				phase = "results"
				ready_players = [false, false]
				changed.emit()
		"leave": _abort("Drugi gracz opuścił grę. Runda została przerwana.")
		"aborted": _abort(str(message.message))

func _accept_hello(sender: int, m: Dictionary) -> void:
	if authenticated or sender != remote_peer: return
	var error := ""
	if m.get("version") != RaceProtocol.VERSION or m.get("fingerprint") != RaceProtocol.fingerprint(): error = "Oba telefony muszą mieć zgodną wersję gry."
	elif m.get("session") != session_id: error = "Ten kod QR już wygasł."
	elif not m.get("character") in AdventureCharacters.IDS: error = "Nieprawidłowa postać."
	elif phase == "recovering":
		if _expired(): return
		if m.get("resume") != true or m.get("token") != resume_token or resume_token.is_empty(): error = "To miejsce jest zarezerwowane dla poprzedniego gracza."
	elif phase != "lobby" or invitation.is_empty() or m.get("resume") != false or m.get("token") != invitation:
		error = "Sesja jest zajęta albo kod QR wygasł."
	if not error.is_empty():
		_control.rpc_id(sender, {"op": "error", "message": error})
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(sender).peer_disconnect_later()
		return
	authenticated = true
	generation += 1
	characters[1] = m.character
	if phase != "recovering":
		resume_token = LanPairing.token()
		invitation = ""
	_reset_clock()
	last_ack = LanPairing.now_ms()
	last_frame = last_ack
	_send("welcome", {"token": resume_token, "characters": characters, "level": level_index, "difficulty": difficulty,
		"phase": phase, "config": config, "state": simulation.snapshot() if not simulation.state.is_empty() else {},
		"remaining": maxi(0, recovery_deadline - last_ack) if phase == "recovering" else 0})
	status = "Wybierzcie postacie i naciśnijcie Gotowy."
	if phase == "lobby": _publish_lobby()
	changed.emit()

func _accept_welcome(m: Dictionary) -> void:
	if not m.get("generation") is int or not LanPairing.valid_token(m.get("token")): return
	if phase == "recovering" and _expired(): return
	generation = m.generation
	authenticated = true
	remote_peer = 1
	resume_token = m.token
	invitation = ""
	characters = m.characters
	level_index = m.level
	difficulty = m.difficulty
	_reset_clock()
	last_ack = LanPairing.now_ms()
	last_frame = last_ack
	if m.phase == "recovering":
		phase = "recovering"
		var deadline: int = last_ack + int(m.remaining)
		recovery_deadline = mini(recovery_deadline, deadline) if recovery_deadline > 0 else deadline
		config = m.config
		if not config.is_empty():
			_setup_simulation()
			_install_snapshot(m.state, true)
		_send("state_ack", {"hash": _recovery_hash()})
	else:
		phase = "lobby"
	status = "Wybierzcie postacie i naciśnijcie Gotowy."
	changed.emit()

func select_character(character: String) -> void:
	if phase != "lobby" or not character in AdventureCharacters.IDS: return
	characters[local_player] = character
	ready_players = [false, false]
	if hosting: _publish_lobby()
	else: _send("selection", {"character": character})
	changed.emit()

func select_route(level: int, profile: int) -> void:
	if not hosting or phase != "lobby": return
	level_index = clampi(level, 0, 2)
	difficulty = clampi(profile, 0, 2)
	ready_players = [false, false]
	_publish_lobby()

func _publish_lobby() -> void:
	if authenticated: _send("lobby", {"level": level_index, "difficulty": difficulty, "characters": characters, "ready": ready_players})
	changed.emit()

func set_ready() -> void:
	if not authenticated or suspended or not phase in ["lobby", "paused", "results"]: return
	if ready_players[local_player]: return
	ready_players[local_player] = true
	if hosting: _try_ready()
	else: _send("ready")
	changed.emit()

func _try_ready() -> void:
	if not ready_players[0] or not ready_players[1]:
		if phase == "lobby": _publish_lobby()
		elif phase == "paused": _send("paused", {"state": simulation.snapshot(), "ready": ready_players})
		changed.emit()
		return
	if phase == "paused": _start_countdown()
	elif phase in ["lobby", "results"]:
		config = {"level": level_index, "difficulty": difficulty, "round": LanPairing.token(), "seed": randi() & 0x7fffffff, "characters": characters.duplicate()}
		_send("load", {"config": config})
		_load_round(config)

func _setup_simulation() -> void:
	simulation.setup(RaceProtocol.LEVELS[config.level].layout(RaceProtocol.PROFILES[config.difficulty]), config.round, config.seed)

func _load_round(value: Dictionary) -> void:
	config = value.duplicate(true)
	_setup_simulation()
	confirmed = simulation.snapshot()
	pending.clear()
	resolved.clear()
	sequence = 0
	received_sequences = [0, 0]
	loaded_players = [false, false]
	ready_players = [false, false]
	phase = "loading"
	changed.emit()
	snapshot_received.emit(confirmed.duplicate(true), true)
	_loaded.call_deferred()

func _loaded() -> void:
	if phase != "loading": return
	loaded_players[local_player] = true
	if hosting: _try_start()
	else: _send("loaded", {"round": config.round})

func _try_start() -> void:
	if hosting and phase == "loading" and loaded_players[0] and loaded_players[1] and clock_ready: _start_countdown()

func _start_countdown() -> void:
	base_tick = simulation.state.tick
	start_ms = LanPairing.now_ms() + 3000.0
	ready_players = [false, false]
	phase = "countdown"
	_send("timeline", {"state": simulation.snapshot(), "start": start_ms})
	_install_snapshot(simulation.snapshot(), true)
	changed.emit()

func server_now() -> float:
	return float(LanPairing.now_ms()) + (0.0 if hosting else offset_ms)

func presentation_tick() -> int:
	if phase in ["race", "countdown"]: return base_tick + maxi(0, int(floor((server_now() - start_ms) * 0.06)))
	return confirmed.get("tick", 0)

func countdown() -> int:
	return maxi(0, int(ceil((start_ms - server_now()) / 1000.0)))

func submit(command: Dictionary) -> void:
	if phase != "race" or suspended: return
	if hosting: _accept_command(command, 0)
	else: _input_command.rpc_id(1, session_id, generation, command)

func next_sequence() -> int:
	sequence += 1
	return sequence

@rpc("any_peer", "call_remote", "reliable", 1)
func _input_command(session: String, connection: int, c: Dictionary) -> void:
	if hosting and authenticated and multiplayer.get_remote_sender_id() == remote_peer and session == session_id and connection == generation and var_to_bytes(c).size() <= 1024:
		_accept_command(c, 1)

func _accept_command(c: Dictionary, player: int) -> void:
	if not RaceProtocol.valid_command(c) or c.player != player: return
	if not simulation.state.is_empty() and (c.round != simulation.state.round or c.epoch != simulation.state.epoch):
		_publish_decision({"round": c.round, "epoch": c.epoch, "player": player, "seq": c.seq, "tick": c.tick, "status": "REJECTED", "reason": "epoch"})
		return
	var key := "%d:%d" % [player, c.seq]
	if resolved.has(key):
		_publish_decision(resolved[key])
		return
	var reason := ""
	if phase != "race" or simulation.state.is_empty(): reason = "paused"
	elif c.round != simulation.state.round or c.epoch != simulation.state.epoch: reason = "epoch"
	elif c.seq <= received_sequences[player]: reason = "sequence"
	elif c.tick <= simulation.state.tick: reason = "late"
	elif c.tick > presentation_tick() + 2: reason = "future"
	if not reason.is_empty():
		_publish_decision({"player": player, "seq": c.seq, "tick": simulation.state.get("tick", 0), "status": "REJECTED", "reason": reason})
		return
	received_sequences[player] = c.seq
	if not pending.has(c.tick): pending[c.tick] = []
	pending[c.tick].append(c.duplicate(true))
	_publish_decision({"player": player, "seq": c.seq, "tick": c.tick, "status": "RECEIVED", "reason": ""})
	command_announced.emit(c.duplicate(true))
	if authenticated: _preview.rpc_id(remote_peer, session_id, generation, c)

@rpc("authority", "call_remote", "reliable", 1)
func _preview(session: String, connection: int, c: Dictionary) -> void:
	if not hosting and authenticated and session == session_id and connection == generation and RaceProtocol.valid_command(c) and not confirmed.is_empty() and c.round == confirmed.round and c.epoch == confirmed.epoch:
		command_announced.emit(c)

func _publish_decision(value: Dictionary) -> void:
	value = value.duplicate(true)
	if not value.has("round"): value.round = simulation.state.get("round", "")
	if not value.has("epoch"): value.epoch = simulation.state.get("epoch", 0)
	# Delayed packets from the previous round must not poison the sequence cache
	# or remove a new round's predicted command which happens to reuse that seq.
	if value.round == simulation.state.get("round", "") and value.epoch == simulation.state.get("epoch", 0):
		resolved["%d:%d" % [value.player, value.seq]] = value.duplicate(true)
		command_resolved.emit(value.duplicate(true))
	if authenticated: _decision.rpc_id(remote_peer, session_id, generation, value.epoch, value)

@rpc("authority", "call_remote", "reliable", 1)
func _decision(session: String, connection: int, epoch: int, value: Dictionary) -> void:
	if not hosting and authenticated and session == session_id and connection == generation and not confirmed.is_empty() and epoch == confirmed.epoch and value.get("round") == confirmed.round:
		command_resolved.emit(value)

func _physics_process(_delta: float) -> void:
	if not hosting or phase != "race" or suspended: return
	var target := maxi(base_tick, presentation_tick() - INPUT_BUFFER)
	if target - simulation.state.tick > HISTORY_TICKS:
		_begin_recovery()
		return
	while simulation.state.tick < target and phase == "race":
		var tick: int = simulation.state.tick + 1
		var commands: Array = pending.get(tick, [])
		pending.erase(tick)
		simulation.step(commands)
		for decision in simulation.decisions: _publish_decision(decision)
		for event in simulation.events:
			race_event.emit(event)
			_send("event", {"event": event})
		if tick % 3 == 0 or simulation.state.ended: _publish_snapshot()
		if simulation.state.ended:
			phase = "results"
			ready_players = [false, false]
			_send("results", {"state": simulation.snapshot()})
			changed.emit()
	for key in resolved.keys():
		if resolved[key].tick < simulation.state.tick - HISTORY_TICKS: resolved.erase(key)

func _publish_snapshot() -> void:
	var value := simulation.snapshot()
	var decisions: Array = []
	var previews: Array = []
	for decision in resolved.values():
		if decision.status != "RECEIVED": decisions.append(decision.duplicate(true))
	# Redundant previews avoid waiting for a reliable-channel retransmission
	# to show the ghost. They remain predictions, never execution acknowledgments.
	for commands in pending.values(): previews.append_array(commands)
	_install_snapshot(value, false)
	if authenticated: _snapshot.rpc_id(remote_peer, session_id, generation, RaceProtocol.pack_snapshot(value, decisions, previews))

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _snapshot(session: String, connection: int, packet: PackedByteArray) -> void:
	if not hosting and authenticated and session == session_id and connection == generation and phase in ["race", "countdown"]:
		var payload := RaceProtocol.unpack_snapshot(packet)
		if payload.is_empty(): return
		var value: Dictionary = payload.state
		_install_snapshot(value, false)
		if value.round == confirmed.round and value.epoch == confirmed.epoch:
			for command in payload.previews: command_announced.emit(command)
			for decision in payload.decisions: command_resolved.emit(decision)

func _install_snapshot(value: Dictionary, reset: bool) -> void:
	if value.is_empty(): return
	if not reset and not confirmed.is_empty() and (value.round != confirmed.round or value.epoch != confirmed.epoch or value.tick <= confirmed.tick): return
	confirmed = value.duplicate(true)
	if not hosting: simulation.restore(value)
	snapshot_received.emit(confirmed.duplicate(true), reset)

func request_pause() -> void:
	if not phase in ["race", "countdown"]: return
	if hosting: _pause_host()
	else:
		_send("pause")
		phase = "paused"
		ready_players = [false, false]
		changed.emit()

func request_resync() -> void:
	if not phase in ["race", "countdown"]: return
	if hosting: _pause_host()
	else:
		_send("resync")
		phase = "paused"
		changed.emit()

func _freeze() -> void:
	if simulation.state.is_empty(): return
	simulation.state.epoch += 1
	simulation.state.revision += 1
	pending.clear()
	resolved.clear()
	ready_players = [false, false]
	_install_snapshot(simulation.snapshot(), true)

func _pause_host() -> void:
	if not phase in ["race", "countdown", "paused"]: return
	_freeze()
	phase = "paused"
	_send("paused", {"state": simulation.snapshot(), "ready": ready_players})
	changed.emit()

func _reset_clock() -> void:
	samples.clear()
	outstanding_pings.clear()
	clock_ready = false
	_clock_announced = false
	stable_since = 0
	state_acknowledged = false
	peer_stable = false
	stable_reported = false
	last_ping = 0

func _process(_delta: float) -> void:
	for i in range(_draining.size() - 1, -1, -1):
		var item: Dictionary = _draining[i]
		item.transport.poll()
		if LanPairing.now_ms() >= item.until or item.transport.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			item.transport.close()
			_draining.remove_at(i)
	if not active(): return
	var now := LanPairing.now_ms()
	if phase == "recovering" and _expired(): return
	if suspended: return
	if authenticated and last_frame > 0 and now - last_frame > LOSS_MS and phase in ["race", "countdown"]:
		_begin_recovery(last_ack + LOSS_MS)
	last_frame = now
	if authenticated:
		if now - last_ack >= LOSS_MS:
			_begin_recovery(last_ack + LOSS_MS)
		elif now - last_ping >= (80 if samples.size() < 8 else HEARTBEAT_MS):
			last_ping = now
			ping_sequence += 1
			outstanding_pings[ping_sequence] = now
			_heartbeat.rpc_id(remote_peer, session_id, generation, ping_sequence, false, 0)
			for key in outstanding_pings.keys():
				if now - outstanding_pings[key] > LOSS_MS: outstanding_pings.erase(key)
	if phase == "countdown" and server_now() >= start_ms:
		phase = "race"
		changed.emit()
	if not authenticated and hosting and remote_peer > 0 and now - connect_started > 3000:
		_evict_remote()
	if phase == "connecting" and now - connect_started > 8000: _connection_failed()
	if phase == "recovering":
		if not authenticated and not hosting and now - last_attempt >= 2000: _connect_transport()
		_try_recovered(now)

@rpc("any_peer", "call_remote", "unreliable", 3)
func _heartbeat(session: String, connection: int, id: int, reply: bool, remote_ms: int) -> void:
	if not authenticated or multiplayer.get_remote_sender_id() != remote_peer or session != session_id or connection != generation: return
	var now := LanPairing.now_ms()
	if not reply:
		_heartbeat.rpc_id(remote_peer, session_id, generation, id, true, now)
		return
	if not outstanding_pings.has(id): return
	var sent: int = outstanding_pings[id]
	outstanding_pings.erase(id)
	rtt_ms = float(now - sent)
	if rtt_ms <= 250.0 and now - last_ack <= 500:
		if stable_since == 0: stable_since = now
	else:
		stable_since = 0
		if stable_reported:
			stable_reported = false
			_send("unstable")
	last_ack = now
	samples.append({"rtt": rtt_ms, "offset": float(remote_ms) - (sent + now) * 0.5})
	if samples.size() > 16: samples.pop_front()
	if not hosting:
		var best: Dictionary = samples[0]
		for sample in samples:
			if sample.rtt < best.rtt: best = sample
		offset_ms = best.offset
		if samples.size() >= 8 and not _clock_announced:
			_clock_announced = true
			clock_ready = true
			_send("clock_ready")

func _begin_recovery(detected_at: int = -1) -> void:
	if not active(): return
	if resume_token.is_empty():
		_abort("Połączenie przerwane. Zeskanuj nowy kod QR.")
		return
	var now := LanPairing.now_ms()
	if recovery_deadline == 0:
		recovery_deadline = (now if detected_at < 0 else detected_at) + RECOVERY_MS
		recovery_return = "lobby" if config.is_empty() else ("results" if simulation.state.get("ended", false) else "paused")
		if hosting: _freeze()
	phase = "recovering"
	status = "Odzyskiwanie połączenia…"
	ready_players = [false, false]
	if hosting:
		_evict_remote()
		generation += 1
	else: _close_transport()
	_reset_clock()
	changed.emit()
	_expired()

func _recovery_hash() -> String:
	return RaceProtocol.state_hash({"config": config, "state": simulation.snapshot() if not simulation.state.is_empty() else {}})

func _try_recovered(now: int) -> void:
	if not authenticated or stable_since == 0 or now - stable_since < 2000 or now - last_ack > 500 or not clock_ready: return
	if hosting:
		if not state_acknowledged or not peer_stable: return
		recovery_deadline = 0
		phase = recovery_return
		_send("recovered", {"phase": phase})
		changed.emit()
	elif not stable_reported:
		stable_reported = true
		_send("stable", {"hash": _recovery_hash()})

func _expired() -> bool:
	if recovery_deadline > 0 and LanPairing.now_ms() >= recovery_deadline:
		if authenticated: _send("aborted", {"message": "Nie odzyskano połączenia w ciągu minuty. Runda przerwana."})
		_abort("Nie odzyskano połączenia w ciągu minuty. Runda przerwana.")
		return true
	return false

func _abort(message: String) -> void:
	_close_transport()
	phase = "aborted"
	status = message
	recovery_deadline = 0
	pending.clear()
	changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		request_pause()
		suspended = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		suspended = false
		var now := LanPairing.now_ms()
		if _expired(): return
		if authenticated and now - last_ack >= LOSS_MS: _begin_recovery(last_ack + LOSS_MS)
		last_frame = now
