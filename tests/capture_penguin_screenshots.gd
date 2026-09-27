extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture.call_deferred()

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _snapshot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("res://build/" + name)

func _fly_to(world: PenguinWorld, island_index: int) -> void:
	for index in range(1, island_index + 1):
		var island := world.islands[index]
		var flight := 1.0
		var target := island.position_at(world.clock + flight)
		var start := world.player.position
		var shot := (target - start) / flight - Vector2(0, JumpingPenguin.GRAVITY * (flight + 1.0 / 60.0) * 0.5)
		if not world.player.jump(shot):
			push_error("Could not launch toward island %d" % index)
			return
		var ticks := 0
		while not world.player.can_jump() and world.splash_time < 0.0 and ticks < 110:
			await _frames(1)
			ticks += 1
		if world.splash_time >= 0.0 or world.player.last_island != island:
			push_error("Penguin did not land on island %d" % index)
			return
		await _frames(8)

func _start_game(difficulty: int, level_index: int) -> Node:
	var game = load("res://main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(4)
	game.difficulty = difficulty
	game.start_level(level_index)
	await _frames(5)
	return game

func _close_game(game: Node) -> void:
	get_tree().root.remove_child(game)
	game.queue_free()
	await get_tree().process_frame

func _capture() -> void:
	var progress = get_tree().root.get_node("Progress")
	progress.save_path = "res://build/capture-penguin-progress.cfg"
	progress.records.clear()
	progress.selected_character = "penguin"
	get_tree().root.size = Vector2i(1280, 720)

	var garden: Variant = await _start_game(0, 0)
	var garden_world: PenguinWorld = garden.world
	await _fly_to(garden_world, 4)
	garden.hint_panel.visible = false
	await _snapshot("JumpingAdventure-penguin-garden.png")
	await _close_game(garden)

	var crystal: Variant = await _start_game(1, 1)
	var crystal_world: PenguinWorld = crystal.world
	await _fly_to(crystal_world, 5)
	await _snapshot("JumpingAdventure-penguin-crystal.png")
	await _close_game(crystal)

	var aurora: Variant = await _start_game(2, 2)
	var aurora_world: PenguinWorld = aurora.world
	await _fly_to(aurora_world, 3)
	var origin := Vector2(600, 390)
	var next_island: SkyIsland = aurora_world.islands[4]
	var flight := 1.0
	var target: Vector2 = next_island.position_at(aurora_world.clock + flight)
	var start: Vector2 = aurora_world.player.position
	var shot: Vector2 = (target - start) / flight - Vector2(0, JumpingPenguin.GRAVITY * (flight + 1.0 / 60.0) * 0.5)
	var drag: Vector2 = shot.limit_length(JumpGesture.MAX_SPEED) * (JumpGesture.MAX_DRAG / JumpGesture.MAX_SPEED)
	aurora_world._begin(7, origin)
	aurora_world._drag(7, origin + drag)
	await _snapshot("JumpingAdventure-penguin-aurora.png")
	await _close_game(aurora)

	DirAccess.remove_absolute("res://build/capture-penguin-progress.cfg")
	get_tree().root.get_node("Sound").music.stop()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()
