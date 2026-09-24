class_name PenguinWorld
extends Node2D

signal fish_changed(count: int)
signal completed(count: int)
signal retry_started
signal island_reached(index: int)

var definition: LevelDefinition
var profile: DifficultyProfile
var islands: Array[SkyIsland] = []
var fish: Array[Dictionary] = []
var player: JumpingPenguin
var camera: Camera2D
var gesture := JumpGesture.new()
var clock: float = 0.0
var elapsed: float = 0.0
var fish_count: int = 0
var furthest: int = 0
var splash_time: float = -1.0
var splash_position := Vector2.ZERO
var particles: Array[Dictionary] = []
var fish_texture: Texture2D
var finished := false
var attempt: int = 1

func _ready() -> void:
	process_physics_priority = -10
	fish_texture = PenguinArt.texture("fish")
	camera = Camera2D.new()
	add_child(camera)
	camera.position = get_viewport_rect().size * 0.5
	build_level()

func build_level() -> void:
	for island in islands:
		remove_child(island)
		island.queue_free()
	islands.clear()
	fish.clear()
	particles.clear()
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	clock = 0.0
	elapsed = 0.0
	fish_count = 0
	furthest = 0
	splash_time = -1.0
	finished = false
	gesture.cancel()
	var data := definition.layout(profile)
	for i in data.size():
		var island := SkyIsland.new()
		island.configure(data[i], i, definition.art)
		add_child(island)
		islands.append(island)
		if data[i].fish:
			fish.append({"island": island, "taken": false})
	player = JumpingPenguin.new()
	player.position = islands[0].position + Vector2(0, -2)
	add_child(player)
	player.landed.connect(_on_landed)
	player.jumped.connect(func(): Sound.effect("jump"))
	camera.position = get_viewport_rect().size * 0.5
	camera.reset_smoothing()
	fish_changed.emit(0)
	island_reached.emit(0)

func _physics_process(delta: float) -> void:
	if finished:
		clock += delta
		queue_redraw()
		return
	clock += delta
	elapsed += delta
	if splash_time >= 0.0:
		splash_time += delta
		if splash_time >= 1.25:
			attempt += 1
			build_level()
			retry_started.emit()
		queue_redraw()
		return
	for island in islands:
		island.advance(clock)
	var viewport_size := get_viewport_rect().size
	var target_x := maxf(viewport_size.x * 0.5, player.position.x + viewport_size.x * 0.25)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-delta * 5.0))
	camera.position.y = viewport_size.y * 0.5
	for item in fish:
		if not item.taken:
			var at := fish_position(item)
			if player.position.distance_to(at + Vector2(0, 36)) < 54.0:
				item.taken = true
				fish_count += 1
				particles.append({"position": at, "born": clock})
				Sound.effect("fish")
				fish_changed.emit(fish_count)
	if player.position.y >= 642.0 or player.position.x < -100.0:
		player.state = JumpingPenguin.State.FALL
		gesture.cancel()
		splash_position = Vector2(player.position.x, 647)
		splash_time = 0.0
		Sound.effect("splash")
	queue_redraw()

func fish_position(item: Dictionary) -> Vector2:
	return item.island.position + Vector2(0, -64.0 + sin(clock * 2.5 + item.island.index) * 5.0)

func _on_landed(island: SkyIsland) -> void:
	Sound.effect("land")
	if island.index > furthest:
		furthest = island.index
		island_reached.emit(furthest)
	if island.goal and not finished:
		finished = true
		cancel_gesture()
		player.state = JumpingPenguin.State.WON
		Sound.effect("win")
		completed.emit(fish_count)

func cancel_gesture() -> void:
	gesture.cancel()
	if is_instance_valid(player):
		player.aim = Vector2.ZERO
		if player.state == JumpingPenguin.State.AIMING:
			player.state = JumpingPenguin.State.IDLE
		player.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if finished or splash_time >= 0.0:
		return
	if event is InputEventScreenTouch:
		if event.canceled:
			if event.index == gesture.pointer:
				cancel_gesture()
		elif event.pressed:
			_begin(event.index, event.position)
		else:
			_end(event.index, event.position)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(-1, event.position)
		else:
			_end(-1, event.position)
	elif event is InputEventMouseMotion and gesture.pointer == -1:
		_drag(-1, event.position)

func _begin(id: int, at: Vector2) -> void:
	if player.can_jump() and gesture.begin(id, at):
		player.state = JumpingPenguin.State.AIMING

func _drag(id: int, at: Vector2) -> void:
	gesture.update(id, at)
	player.aim = JumpGesture.launch_vector(gesture.displacement)

func _end(id: int, at: Vector2) -> void:
	if id != gesture.pointer:
		return
	var vector := gesture.finish(id, at)
	if not player.jump(vector):
		cancel_gesture()

func _draw() -> void:
	for item in fish:
		if item.taken:
			continue
		var at := fish_position(item)
		draw_circle(at, 24 + sin(clock * 3.0) * 2, Color(1, 0.89, 0.62, 0.18))
		if fish_texture:
			draw_texture_rect(fish_texture, Rect2(at - Vector2(23, 15), Vector2(46, 30)), false)
	for i in range(particles.size() - 1, -1, -1):
		var p := particles[i]
		var age: float = clock - p.born
		if age > 0.65:
			particles.remove_at(i)
			continue
		for j in 7:
			var direction := Vector2.from_angle(TAU * j / 7.0)
			draw_circle(p.position + direction * age * 85.0, 3.0 * (1.0 - age), Color(1, 0.83, 0.43, 1.0 - age))
	if splash_time >= 0.0:
		for j in 12:
			var direction := Vector2.from_angle(PI + PI * float(j) / 11.0)
			var at := splash_position + direction * splash_time * 175.0 + Vector2(0, 220 * splash_time * splash_time)
			draw_circle(at, maxf(0, 7.0 - splash_time * 5), Color(0.88, 1, 1, maxf(0, 1.0 - splash_time)))
		if splash_time < 1.0:
			draw_arc(splash_position, 20 + splash_time * 80, 0, PI, 32, Color(1, 1, 1, 1.0 - splash_time), 3, true)
	if finished:
		for j in 26:
			var at := player.position + Vector2(sin(j * 14.0) * 210, -fposmod(clock * 64 + j * 21, 340))
			draw_circle(at, 3 + j % 3, Color("f2c780") if j % 2 else Color("a2daca"))
