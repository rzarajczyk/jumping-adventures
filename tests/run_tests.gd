extends Node

var root: Window:
	get: return get_tree().root
var paused: bool:
	get: return get_tree().paused

var checks: int = 0
var failures: Array[String] = []
const LEVEL_PATHS := ["garden", "crystal", "aurora"]
const PROFILE_PATHS := ["easy", "medium", "hard"]
const ARTIFACT_PLACEMENTS: Array[Vector2i] = [Vector2i(2, 4), Vector2i(5, 1), Vector2i(3, 4)]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _run() -> void:
	var save = root.get_node("Progress")
	save.save_path = "res://build/test-progress.cfg"
	save.records.clear()
	var gesture := JumpGesture.new()
	check(JumpGesture.launch_vector(Vector2(200, -200)).length() <= 850.01, "force is capped")
	check(JumpGesture.launch_vector(Vector2(8, -8)) == Vector2.ZERO, "tap dead zone")
	check(JumpGesture.launch_vector(Vector2(200, 20)) == Vector2.ZERO, "downward swipe is canceled")
	check(JumpGesture.launch_vector(Vector2(-120, -120)).x < 0, "leftward jumps supported")
	check(gesture.begin(3, Vector2(100, 400)), "first finger begins")
	check(not gesture.begin(4, Vector2(0, 0)), "second finger ignored")
	gesture.update(4, Vector2(900, 30))
	check(gesture.displacement == Vector2.ZERO, "second finger cannot change aim")
	check(gesture.finish(4, Vector2(500, 200)) == Vector2.ZERO and gesture.pointer == 3, "second release does not launch")
	var velocity := gesture.finish(3, Vector2(220, 280))
	check(velocity.is_equal_approx(Vector2(425, -425)), "gesture direction and linear strength")
	gesture.begin(3, Vector2(30, 30))
	gesture.update(3, Vector2(200, -100))
	check(gesture.finish(3, Vector2(30, 30)) == Vector2.ZERO, "return to origin cancels")
	for star_count in [0, 1, 5, 6, 10, 11]:
		check(save.medals_for(star_count) == (3 if star_count == 11 else (2 if star_count >= 6 else (1 if star_count > 0 else 0))), "star threshold %d" % star_count)
	save.complete(1, 0, 8)
	save.complete(1, 0, 2)
	check(save.best(1, 0).collected == 8, "best result never decreases")
	check(save.unlocked(1, 1) and not save.unlocked(0, 1) and not save.unlocked(1, 2), "unlock is sequential and difficulty-specific")
	save.music_enabled = false
	save.effects_enabled = false
	save.save_progress()
	save.records.clear()
	save.load_progress()
	check(save.best(1, 0).medals == 2 and not save.music_enabled and not save.effects_enabled, "save survives reload")
	await test_menu_navigation()
	await test_characters_and_migration()
	for d in 3:
		for l in 3:
			await test_route(d, l)
	await test_fail_and_ui()
	await preload("res://tests/test_powers.gd").new().run(self)
	DirAccess.remove_absolute("res://build/test-progress.cfg")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: print("  " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func menu_button(parent: Node, text: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func click_button(button: Button) -> void:
	check(is_instance_valid(button), "menu button exists")
	if not is_instance_valid(button):
		return
	var at := button.get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		root.push_input(event, true)
		await frames(1)
	await frames(2)

func press_back() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event, true)
	await frames(2)

func test_menu_navigation() -> void:
	var save = root.get_node("Progress")
	save.records.clear()
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	for d in 3:
		await click_button(game.stage.get_node("Difficulty%d" % d))
		check(game.difficulty == d and game.screen == "home", "home chooses difficulty %d" % d)
	await click_button(menu_button(game.stage, "Start   →"))
	check(game.screen == "levels" and not is_instance_valid(game.world), "start opens level selection")
	check(not game.stage.get_node("Level0").disabled and game.stage.get_node("Level1").disabled and game.stage.get_node("Level2").disabled, "fresh progress opens only the first route")
	await press_back()
	check(game.screen == "home", "back returns from level selection")
	await click_button(menu_button(game.stage, "Dźwięk"))
	check(is_instance_valid(game.modal), "home opens audio settings")
	var previous_music: bool = save.music_enabled
	await click_button(menu_button(game.modal, "Muzyka: " + ("włączona" if previous_music else "wyłączona")))
	save.load_progress()
	check(save.music_enabled != previous_music, "audio toggle survives save reload")
	await press_back()
	check(not is_instance_valid(game.modal) and game.screen == "home", "back closes home settings")
	# Close the settings even when this regression fails, so later checks still run.
	game._close_overlay()
	await click_button(menu_button(game.stage, "Zmień postać"))
	check(game.screen == "characters", "home opens character selection")
	await press_back()
	check(game.screen == "home", "back returns from character selection")
	await click_button(menu_button(game.stage, "Start   →"))
	await click_button(game.stage.get_node("Level0"))
	check(game.screen == "game" and game.world.profile == game.PROFILES[2] and game.world.player.can_jump(), "menu starts selected difficulty on a grounded character")
	await click_button(game.stage.get_node("PauseButton"))
	await click_button(menu_button(game.modal, "Dźwięk"))
	await click_button(menu_button(game.modal, "Gotowe"))
	check(paused and game.pause_overlay, "closing audio settings restores pause menu")
	await click_button(menu_button(game.modal, "Zacznij planszę od nowa"))
	check(not paused and game.world.attempt == 1 and game.world.star_count == 0 and game.world.player.can_jump(), "pause menu restarts a playable route")
	game.world.player.position = game.world.goal_position() + Vector2(0, 34)
	game.world._check_goal()
	check(game.screen == "victory" and save.unlocked(2, 1), "victory unlocks next route on selected difficulty")
	await press_back()
	check(game.screen == "levels" and not is_instance_valid(game.world), "back leaves victory for level selection")
	game.show_home()
	root.remove_child(game)
	game.queue_free()
	await frames(2)

func test_route(d: int, l: int) -> void:
	var world := PenguinWorld.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.definition = load("res://resources/levels/%s.tres" % LEVEL_PATHS[l])
	world.profile = load("res://resources/difficulties/%s.tres" % PROFILE_PATHS[d])
	root.add_child(world)
	await frames(5)
	check(world.islands.size() == 21 and world.stars.size() == 10, "route content %d/%d" % [d, l])
	var expected := ARTIFACT_PLACEMENTS[l]
	var indices: Array[int] = []
	for artifact in world.artifacts:
		check(artifact.kind == AdventurePowers.Kind.JETPACK, "only jetpack artifacts %d/%d" % [d, l])
		indices.append(artifact.island.index)
	check(indices.size() == 2 and int(expected.x) in indices and int(expected.y) in indices, "artifact placements %d/%d" % [d, l])
	check(world.player.can_jump(), "spawn stands on first island %d/%d" % [d, l])
	for index in range(1, 21):
		var island := world.islands[index]
		var start := world.player.position
		var flight: float = 1.0
		var target := island.position_at(world.clock + flight)
		var shot := (target - start) / flight - Vector2(0, JumpingPenguin.GRAVITY * (flight + 1.0 / 60.0) * 0.5)
		check(shot.length() <= JumpGesture.MAX_SPEED, "reachable %d/%d island %d" % [d, l, index])
		var screen_target := world.camera.get_screen_center_position() - root.get_visible_rect().size * 0.5
		check(island.position.x - screen_target.x < root.get_visible_rect().size.x, "next landing is visible %d/%d/%d" % [d, l, index])
		check(world.player.jump(shot), "launch accepted %d/%d/%d" % [d, l, index])
		check(not world.player.jump(shot), "air jump rejected")
		await frames(3)
		check(absf(world.player.velocity.x - shot.x) < 0.01, "platform does not add horizontal launch velocity")
		var ticks := 0
		while not world.player.can_jump() and not world.finished and world.splash_time < 0.0 and ticks < 110:
			await frames(1)
			ticks += 1
		var landed := (is_instance_valid(world.player.last_island) and world.player.last_island.index == index) if index < 20 else world.goal_collected
		check(landed, "actual landing %d/%d/%d" % [d, l, index])
		if not landed:
			print("  position=", world.player.position, " target=", island.position, " state=", world.player.state)
			break
		if index == 4 and island.amplitude != Vector2.ZERO:
			var relative := world.player.position - island.position
			await frames(75)
			check((world.player.position - island.position).distance_to(relative) < 2.0, "riding moving island %d/%d" % [d, l])
		if index < 20:
			await frames(6)
	check(world.finished, "route completed %d/%d" % [d, l])
	check(world.star_count == 11, "ten stars and finish star collectible %d/%d" % [d, l])
	check(world.powers.jetpack == 6 and world.artifacts.all(func(item: Dictionary): return item.taken), "ordinary route collects six charges from both artifacts %d/%d" % [d, l])
	print("Route %s / %s: finished=%s, stars=%d" % [PROFILE_PATHS[d], LEVEL_PATHS[l], world.finished, world.star_count])
	root.remove_child(world)
	world.queue_free()
	await frames(2)

func test_fail_and_ui() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_level(0)
	await frames(5)
	var world: PenguinWorld = game.world
	world._begin(1, Vector2(200, 400))
	world._drag(1, Vector2(320, 280))
	var canceled_other := InputEventScreenTouch.new()
	canceled_other.index = 2
	canceled_other.canceled = true
	canceled_other.pressed = false
	game._input(canceled_other)
	check(world.gesture.pointer == 1, "canceling second finger preserves the first gesture")
	game.pause_game()
	check(paused and world.gesture.pointer == -99, "pause cancels gesture")
	var before := world.clock
	await frames(5)
	check(is_equal_approx(before, world.clock), "pause freezes level")
	game.resume_game()
	check(not paused and world.player.can_jump(), "resume keeps player grounded")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(paused and game.application_suspended, "background pauses")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(paused, "foreground needs explicit resume")
	game.resume_game()
	var first := world.islands[5].position_at(0.0)
	world.stars[0].taken = true
	world.star_count = 1
	world.player.position.y = 700
	world.player.state = JumpingPenguin.State.AIR
	await frames(3)
	check(world.splash_time >= 0.0, "water starts splash")
	await frames(78)
	check(world.attempt == 2 and world.star_count == 0 and not world.stars[0].taken, "fall resets attempt and stars")
	check(world.islands[5].position.distance_to(first) < 2.0, "restart resets platform phase")
	check(world.furthest == 0 and world.player.position.x < 225, "restart returns to beginning")
	check(game.hint_label.text.begins_with("Przeciągnij"), "restart restores the first tutorial hint")
	# Verify GUI events do not start a jump, using the real viewport event routing.
	await frames(5)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = game.stage.position + Vector2(1185, 60)
	root.push_input(press, true)
	await frames(1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position
	root.push_input(release, true)
	await frames(2)
	check(paused and world.gesture.pointer == -99, "HUD pause button consumes input")
	game.resume_game()
	# A full-speed vertical jump must land back on the same thin surface.
	check(world.player.jump(Vector2(0, -850)), "maximum force launch")
	await frames(92)
	check(world.player.can_jump() and world.player.last_island.index == 0, "maximum speed does not tunnel through platform")
	# Approach from below: one-way platforms allow ascent, then catch the descent.
	world.player.position = world.islands[0].position + Vector2(0, 52)
	world.player.velocity = Vector2(0, -620)
	world.player.state = JumpingPenguin.State.AIR
	await frames(70)
	check(world.player.can_jump() and world.player.last_island.index == 0, "one-way ascent and subsequent landing")
	world.star_count = 6
	world._on_landed(world.islands.back())
	check(not world.finished, "landing alone is not victory without collecting the finish star")
	world.player.position = world.goal_position() + Vector2(0, 34)
	world._check_goal()
	check(world.star_count == 7 and world.goal_collected, "finish star adds exactly one point")
	world._check_goal()
	check(world.star_count == 7, "finish star cannot be collected twice")
	var save = root.get_node("Progress")
	check(save.best(0, 0).medals == 2 and save.unlocked(0, 1), "victory signal persists score and unlocks next level")
	check(is_instance_valid(game.modal) and world.finished, "victory opens result screen")
	var next_button: Button = game.modal.find_child("NextLevelButton", true, false)
	var score: Label = game.modal.find_child("VictoryScore", true, false)
	check(score.text == "Zebrane gwiazdki: 7 / 11", "victory shows the exact total")
	check(game.modal.has_node("Fireworks"), "victory contains animated fireworks")
	if next_button:
		next_button.pressed.emit()
	check(game.level_index == 1 and not game.world.finished, "result button starts the next level")
	game.show_home()
	root.remove_child(game)
	game.queue_free()
	await frames(2)

func test_characters_and_migration() -> void:
	var save = root.get_node("Progress")
	var legacy := ConfigFile.new()
	legacy.set_value("save", "version", 1)
	legacy.set_value("save", "records", {"0_0": {"stars": 3, "fish": 10}, "1_0": {"stars": 2, "fish": 5}, "2_0": {"stars": 1, "fish": 0}})
	legacy.save(save.save_path)
	save.load_progress()
	check(save.best(0, 0).collected == 11 and save.best(0, 0).medals == 3, "legacy perfect score migration")
	check(save.best(1, 0).collected == 6 and save.best(2, 0).collected == 1, "legacy counts include finish star")
	check(save.unlocked(0, 1) and save.unlocked(1, 1) and not save.unlocked(0, 2), "migration preserves unlocks")
	check(save.selected_character == "penguin", "legacy save defaults to penguin")
	save.records.clear()
	save.music_enabled = false
	save.effects_enabled = false
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for id in AdventureCharacters.IDS:
		game.show_characters()
		var card: Button = game.stage.get_node("Character_" + id)
		check(Rect2(Vector2.ZERO, game.stage.size).encloses(card.get_rect()), "character card fits on screen " + id)
		card.pressed.emit()
		check(save.selected_character == id, "character card selects " + id)
		save.load_progress()
		check(save.selected_character == id, "character survives save/reload " + id)
		game.start_level(0)
		await frames(5)
		check(game.world.player.character_id == id and game.world.player.can_jump(), "selected character spawns " + id)
		for pose in ["idle", "blink", "fly"]:
			check(AdventureCharacters.frame(id, pose) != null, "character frame exists " + id + pose)
		check(game.world.player.jump(Vector2(0, -500)), "character can jump " + id)
		await frames(60)
		check(game.world.player.can_jump(), "character lands " + id)
		game.world.player.position.y = 700
		game.world.player.state = JumpingPenguin.State.AIR
		await frames(82)
		check(game.world.player.character_id == id and game.world.star_count == 0, "restart retains character and resets stars " + id)
		game.world.player.position = game.world.goal_position() + Vector2(0, 34)
		game.world._check_goal()
		check(game.world.finished and game.world.star_count == 1, "optional stars may be skipped " + id)
		check(is_instance_valid(game.modal), "character victory screen " + id)
		game.show_home()
	save.select_character("invalid")
	check(save.selected_character == "penguin", "invalid character safely defaults")
	save.records.clear()
	root.remove_child(game)
	game.queue_free()
	await frames(2)
