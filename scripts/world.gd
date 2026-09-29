class_name PenguinWorld
extends Node2D

signal stars_changed(count: int)
signal completed(count: int)
signal retry_started
signal island_reached(index: int)
signal powers_changed
signal artifact_collected(kind: AdventurePowers.Kind, at: Vector2)

const WATER_Y := 642.0

var character_id := "penguin"
var goal_collected := false
var definition: LevelDefinition
var profile: DifficultyProfile
var islands: Array[SkyIsland] = []
var stars: Array[Dictionary] = []
var artifacts: Array[Dictionary] = []
var powers := AdventurePowers.new()
var effects: PowerEffects
var flight_zoom: float = 1.0
var trail_time: float = 0.0
var player: JumpingPenguin
var camera: Camera2D
var gesture := JumpGesture.new()
var clock: float = 0.0
var elapsed: float = 0.0
var star_count: int = 0
var furthest: int = 0
var splash_time: float = -1.0
var splash_position := Vector2.ZERO
var particles: Array[Dictionary] = []
var star_texture: Texture2D
var finished := false
var attempt: int = 1

func _ready() -> void:
	process_physics_priority = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	star_texture = PenguinArt.texture("star")
	powers.changed.connect(func(): powers_changed.emit())
	effects = PowerEffects.new()
	add_child(effects)
	camera = Camera2D.new()
	add_child(camera)
	camera.position = get_viewport_rect().size * 0.5
	build_level()

func build_level() -> void:
	for island in islands:
		remove_child(island)
		island.queue_free()
	islands.clear()
	stars.clear()
	artifacts.clear()
	particles.clear()
	effects.clear()
	powers.reset()
	flight_zoom = 1.0
	trail_time = 0.0
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	clock = 0.0
	elapsed = 0.0
	star_count = 0
	furthest = 0
	splash_time = -1.0
	finished = false
	goal_collected = false
	gesture.cancel()
	var data := definition.layout(profile)
	for i in data.size():
		var island := SkyIsland.new()
		island.configure(data[i], i, definition.art)
		add_child(island)
		islands.append(island)
		if data[i].star:
			stars.append({"island": island, "taken": false})
		if data[i].artifact != AdventurePowers.Kind.NONE:
			artifacts.append({"island": island, "kind": data[i].artifact, "taken": false})
	player = JumpingPenguin.new()
	player.powers = powers
	player.character_id = character_id
	player.position = islands[0].position + Vector2(0, -2)
	add_child(player)
	player.landed.connect(_on_landed)
	player.jumped.connect(func(): Sound.effect("jump"))
	camera.zoom = Vector2.ONE
	camera.position = get_viewport_rect().size * 0.5
	camera.reset_smoothing()
	stars_changed.emit(0)
	island_reached.emit(0)
	powers_changed.emit()

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
	_update_camera(delta)
	if gesture.pointer != -99 and not player.can_jump():
		cancel_gesture()
	if player.jetpack_flight and player.jetpack_age < AdventurePowers.JETPACK_DURATION:
		trail_time += delta
		if trail_time >= 0.055:
			trail_time = 0.0
			effects.puff(player.position + Vector2(-player.facing * 28, -37), 13)
	for item in artifacts:
		if not item.taken:
			var at := artifact_position(item)
			if (player.position + Vector2(0, -34)).distance_to(at) < 48.0:
				item.taken = true
				powers.grant(item.kind)
				effects.burst(at, AdventurePowers.JETPACK_COLOR)
				Sound.effect("artifact")
				artifact_collected.emit(item.kind, at)
	for item in stars:
		if not item.taken:
			var at := star_position(item)
			if player.position.distance_to(at + Vector2(0, 36)) < 54.0:
				item.taken = true
				star_count += 1
				particles.append({"position": at, "born": clock})
				Sound.effect("star")
				stars_changed.emit(star_count)
	_check_goal()
	if finished:
		queue_redraw()
		return
	if player.position.y >= WATER_Y or player.position.x < -100.0:
		player.state = JumpingPenguin.State.FALL
		cancel_gesture()
		powers.reset()
		splash_position = Vector2(player.position.x, 647)
		splash_time = 0.0
		Sound.effect("splash")
	queue_redraw()

func star_position(item: Dictionary) -> Vector2:
	return item.island.position + Vector2(0, -64.0 + sin(clock * 2.5 + item.island.index) * 5.0)

func _on_landed(island: SkyIsland) -> void:
	Sound.effect("land")
	flight_zoom = 1.0
	if island.index > furthest:
		furthest = island.index
		island_reached.emit(furthest)

func goal_position() -> Vector2:
	return islands.back().position + Vector2(0, -92 + sin(clock * 2.0) * 6)

func _check_goal() -> void:
	if finished or splash_time >= 0.0 or player.state == JumpingPenguin.State.FALL:
		return
	if (player.position + Vector2(0, -34)).distance_to(goal_position()) <= 68.0:
		goal_collected = true
		star_count += 1
		stars_changed.emit(star_count)
		finished = true
		cancel_gesture()
		player.velocity = Vector2.ZERO
		player.state = JumpingPenguin.State.WON
		Sound.effect("win")
		completed.emit(star_count)

func cancel_gesture() -> void:
	gesture.cancel()
	if is_instance_valid(player):
		player.aim = Vector2.ZERO
		if player.state == JumpingPenguin.State.AIMING:
			player.state = JumpingPenguin.State.IDLE
		player.queue_redraw()
	powers_changed.emit()

func can_use_jetpack() -> bool:
	return _powers_allowed() and powers.jetpack > 0 and player.can_use_jetpack()

func _powers_allowed() -> bool:
	return is_instance_valid(player) and not get_tree().paused and not finished and splash_time < 0.0 and player.position.y < WATER_Y

func use_jetpack() -> bool:
	if not can_use_jetpack():
		return false
	cancel_gesture()
	if not player.activate_jetpack():
		return false
	powers.consume_jetpack()
	effects.ignite(player.position + Vector2(0, -35), player.facing)
	trail_time = 0.0
	Sound.effect("jetpack")
	var apex_top := player.position.y - player.velocity.y ** 2 / (2.0 * JumpingPenguin.GRAVITY) - 110.0
	# Allow chained midair jumps to extend the view while keeping the waterline fixed.
	var top_margin := maxf(142.0, (get_viewport_rect().size.y - 720.0) * 0.5 + 142.0)
	flight_zoom = minf(flight_zoom, (WATER_Y - top_margin) / maxf(1.0, WATER_Y - apex_top))
	return true

func launch(vector: Vector2) -> bool:
	if not _powers_allowed() or not player.jump(vector):
		return false
	powers_changed.emit()
	return true

func _update_camera(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var zoom_value := lerpf(camera.zoom.x, flight_zoom, 1.0 - exp(-delta * 8.0))
	camera.zoom = Vector2.ONE * zoom_value
	var visible_width := viewport_size.x / zoom_value
	var target_x := maxf(visible_width * 0.5, player.position.x + visible_width * 0.25)
	# During a backwards jump leave room in front of the character as well.
	if player.state == JumpingPenguin.State.AIR and player.velocity.x < -1.0:
		target_x = maxf(visible_width * 0.5, player.position.x - visible_width * 0.15)
	camera.position.x = lerpf(camera.position.x, target_x, 1.0 - exp(-delta * 5.0))
	camera.position.y = WATER_Y - (WATER_Y - viewport_size.y * 0.5) / zoom_value

func artifact_position(item: Dictionary) -> Vector2:
	return item.island.position + Vector2(0, -66.0 + sin(clock * 2.4 + item.island.index) * 5.0)

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
		powers_changed.emit()

func _drag(id: int, at: Vector2) -> void:
	gesture.update(id, at)
	player.aim = JumpGesture.launch_vector(gesture.displacement)

func _end(id: int, at: Vector2) -> void:
	if id != gesture.pointer:
		return
	var vector := gesture.finish(id, at)
	if not launch(vector):
		cancel_gesture()

func _draw() -> void:
	for item in artifacts:
		if item.taken:
			continue
		var at := artifact_position(item)
		var glow := AdventurePowers.JETPACK_COLOR
		glow.a = 0.13
		draw_circle(at, 35 + sin(clock * 3.0) * 2, glow)
		draw_set_transform(at, sin(clock * 4.0) * 0.045)
		draw_texture_rect(PenguinArt.texture("cloud_pack"), Rect2(-25, -28, 50, 56), false)
		draw_set_transform(Vector2.ZERO)
	for item in stars:
		if item.taken:
			continue
		var at := star_position(item)
		draw_circle(at, 24 + sin(clock * 3.0) * 2, Color(1, 0.89, 0.62, 0.18))
		if star_texture:
			draw_texture_rect(star_texture, Rect2(at - Vector2(21, 21), Vector2(42, 42)), false)
	if not goal_collected and star_texture and not islands.is_empty():
		var at := goal_position()
		var pulse := 1.0 + sin(clock * 2.0) * 0.07
		draw_circle(at, 82 * pulse, Color(1, 0.86, 0.40, 0.14))
		draw_circle(at, 66 * pulse, Color(1, 0.91, 0.61, 0.25))
		for ray in 8:
			var direction := Vector2.from_angle(clock * 0.25 + TAU * ray / 8.0)
			draw_line(at + direction * 71, at + direction * (82 + 7 * pulse), Color(1, 0.94, 0.68, 0.7), 3, true)
		draw_texture_rect(star_texture, Rect2(at - Vector2.ONE * 59 * pulse, Vector2.ONE * 118 * pulse), false)
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
