extends Node
## Debug-only two-device race driver. It is activated solely by a user:// file
## written into a debuggable Android install by the emulator test procedure.

const CONFIG_PATH := "user://race-emulator-demo.json"
const INVITATION_PATH := "user://race-emulator-invitation.txt"

var app: Node2D
var config: Dictionary = {}
var prediction := RacePrediction.new()
var prepared_round := ""
var route_selected := false
var readied := false
var last_launch_tick := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Race.snapshot_received.connect(_snapshot_received)
	Race.command_announced.connect(func(command: Dictionary): prediction.announce(command))
	Race.command_resolved.connect(func(result: Dictionary): prediction.resolve(result))
	start.call_deferred()

func start() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		queue_free()
		return
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		push_error("Invalid emulator race demo configuration")
		queue_free()
		return
	config = value
	var role := str(config.get("role", ""))
	var error := ERR_INVALID_PARAMETER
	if role == "host":
		error = Race.host_game(str(config.get("ip", "")), str(config.get("character", "penguin")))
		if error == OK:
			var invitation := FileAccess.open(INVITATION_PATH, FileAccess.WRITE)
			invitation.store_string(Race.pairing_code())
	elif role == "client":
		error = Race.join_game(str(config.get("invitation", "")), str(config.get("character", "panda")))
	if error != OK:
		push_error("Could not start emulator race demo: %s" % Race.status)
		queue_free()
		return
	app.show_multiplayer()

func _snapshot_received(value: Dictionary, reset: bool) -> void:
	if value.is_empty() or Race.config.is_empty(): return
	if prepared_round != value.round:
		var layout: Array[Dictionary] = RaceProtocol.LEVELS[Race.config.level].layout(RaceProtocol.PROFILES[Race.config.difficulty])
		prediction.setup(layout, value.round, Race.config.seed)
		prepared_round = value.round
		last_launch_tick = -1
	prediction.accept_snapshot(value, reset)

func _process(_delta: float) -> void:
	if Race.phase == "lobby" and Race.authenticated:
		if Race.hosting and not route_selected:
			Race.select_route(0, 0)
			route_selected = true
			return
		if not readied:
			Race.set_ready()
			readied = true
	if Race.phase == "race": _launch_next_jump()

func _launch_next_jump() -> void:
	if prediction.baseline.is_empty(): return
	prediction.rebuild(Race.presentation_tick(), Race.local_player)
	if prediction.needs_resync: return
	var state: Dictionary = prediction.sim.state
	var player: Dictionary = state.players[Race.local_player]
	if player.ground < 0 or player.respawn >= 0 or player.finish >= 0.0: return
	if last_launch_tick == state.tick: return
	var next_island: int = mini(player.ground + 1, prediction.sim.layout.size() - 1)
	if next_island <= player.ground: return
	var flight := 0.94
	var target := prediction.sim.island_at(next_island, float(state.tick) / RaceSimulation.HZ + flight)
	# The two devices choose nearby landing points, so both characters remain visible.
	target.x += 24.0 if Race.local_player == 0 else -24.0
	var vector: Vector2 = (target - player.position) / flight - Vector2(0, RaceSimulation.GRAVITY * (flight + RaceSimulation.DT) * 0.5)
	if vector.length() > RaceSimulation.MAX_SPEED: vector = vector.limit_length(RaceSimulation.MAX_SPEED)
	var command := prediction.sim.command(Race.local_player, Race.next_sequence(), "jump", vector)
	prediction.announce(command)
	Race.submit(command)
	last_launch_tick = state.tick
