extends RefCounted

var runner: Node

func check(ok: bool, message: String) -> void:
	runner.check(ok, "powers: " + message)

func frames(count: int) -> void:
	await runner.frames(count)

func run(test_runner: Node) -> void:
	runner = test_runner
	await test_ballistics()
	await test_world()
	await test_input()

func measure(multiplier: float) -> Vector2:
	var scene := Node2D.new()
	runner.root.add_child(scene)
	var floor_island := SkyIsland.new()
	floor_island.configure({"position": Vector2(0, 450), "width": 6000.0, "goal": false, "amplitude": Vector2.ZERO, "period": 8.0, "phase": 0.0}, 0, "garden")
	scene.add_child(floor_island)
	var player := JumpingPenguin.new()
	player.position = Vector2(0, 448)
	scene.add_child(player)
	await frames(5)
	var start := player.position
	var highest := start.y
	check(player.jump(Vector2(300, -600) * multiplier), "measurement launch accepted")
	var ticks := 0
	while not player.can_jump() and ticks < 160:
		await frames(1)
		highest = minf(highest, player.position.y)
		ticks += 1
	check(player.can_jump(), "measurement lands on same-height floor")
	var result := Vector2(start.y - highest, player.position.x - start.x)
	scene.queue_free()
	await frames(2)
	return result

func test_ballistics() -> void:
	var normal := await measure(1.0)
	var boosted := await measure(AdventurePowers.JUMP_MULTIPLIER)
	# Semi-implicit 60 Hz integration introduces a small, predictable discretization error.
	check(absf(boosted.x / normal.x - 2.0) < 0.06, "measured height doubles")
	check(absf(boosted.y / normal.y - 2.0) < 0.06, "measured range doubles")
	print("Power ballistics: normal=", normal, " boosted=", boosted)

func make_world() -> PenguinWorld:
	var world := PenguinWorld.new()
	world.definition = load("res://resources/levels/garden.tres")
	world.profile = load("res://resources/difficulties/easy.tres")
	runner.root.add_child(world)
	return world

func stand(world: PenguinWorld, island: int = 0) -> void:
	world.player.position = world.islands[island].position + Vector2(0, -2)
	world.player.velocity = Vector2.ZERO
	world.player.state = JumpingPenguin.State.AIR
	await frames(6)
	check(world.player.can_jump(), "fixture stands on island %d" % island)

func test_world() -> void:
	var world := make_world()
	await frames(5)
	check(world.powers.wind == 0 and world.powers.anchor == 0, "attempt starts empty")
	check(not world.toggle_super_jump() and not world.use_anchor(), "empty inventory cannot activate")
	# Collect by the actual collision path, before landing.
	world.player.position = world.artifact_position(world.artifacts[0]) + Vector2(0, 34)
	world.player.state = JumpingPenguin.State.AIR
	world.player.velocity = Vector2(0, -80)
	await frames(1)
	check(world.artifacts[0].taken and world.powers.wind == 3, "bottle can be collected in air")
	await stand(world, 2)
	world.powers.wind = 2
	await frames(5)
	check(world.powers.wind == 2, "collected artifact does not refill repeatedly")
	world.powers.grant(AdventurePowers.Kind.WIND)
	check(world.toggle_super_jump() and world.powers.armed, "arm on floor")
	check(world.toggle_super_jump() and not world.powers.armed, "toggle off without spending")
	world.toggle_super_jump()
	world._begin(1, Vector2(500, 400))
	world._drag(1, Vector2(600, 250))
	check(not world.toggle_super_jump() and world.powers.armed, "cannot toggle during a gesture")
	world._end(1, Vector2(500, 400))
	check(world.powers.wind == 3 and not world.powers.armed and world.player.can_jump(), "canceled gesture disarms without spending")
	await stand(world)
	for count in range(3, 0, -1):
		check(world.toggle_super_jump(), "arm charge %d" % count)
		check(world.launch(Vector2(0, -850)), "boost launch %d" % count)
		check(is_equal_approx(world.player.velocity.y, -850 * sqrt(2.0)) and world.powers.wind == count - 1 and not world.powers.armed, "boost applies once and spends one charge")
		check(not world.launch(Vector2(0, -500)), "second jump while airborne rejected")
		var top := 10000.0
		var water_error := 0.0
		var ticks := 0
		while not world.player.can_jump() and world.splash_time < 0.0 and ticks < 180:
			await frames(1)
			var transform := world.get_canvas_transform()
			top = minf(top, (transform * (world.player.position + Vector2(0, -110))).y)
			water_error = maxf(water_error, absf((transform * Vector2(0, PenguinWorld.WATER_Y)).y - PenguinWorld.WATER_Y))
			ticks += 1
		check(world.player.can_jump() and world.player.last_island.index == 0, "maximum boosted descent does not tunnel")
		check(top >= 120.0, "boosted character stays below HUD")
		check(water_error < 1.0, "zoom preserves water screen position")
		await frames(25)
	check(not world.toggle_super_jump(), "fourth super jump unavailable")
	check(absf(world.camera.zoom.x - 1.0) < 0.03, "camera returns after landing")
	world.powers.grant(AdventurePowers.Kind.ANCHOR)
	check(not world.use_anchor() and world.powers.anchor == 3, "anchor cannot be spent on floor")
	for vy in [-500.0, 0.0, 500.0]:
		world.player.position = Vector2(240, 120)
		world.player.state = JumpingPenguin.State.AIR
		world.player.velocity = Vector2(400, vy)
		var count := world.powers.anchor
		check(world.use_anchor(), "anchor works for vertical speed %f" % vy)
		check(world.player.velocity == Vector2.ZERO and world.powers.anchor == count - 1, "anchor instantly cancels both components")
		check(not world.use_anchor() and world.powers.anchor == count - 1, "repeat press in same flight ignored")
		var x := world.player.position.x
		await frames(5)
		check(is_equal_approx(world.player.position.x, x) and world.player.velocity.y > 0, "normal gravity resumes vertically")
		await stand(world)
		check(not world.powers.anchor_used, "landing re-enables anchor for next flight")
	check(world.powers.anchor == 0 and not world.can_use_anchor(), "all three anchor charges spent")
	# Combining powers, then landing on a moving island.
	await stand(world, 5)
	world.powers.grant(AdventurePowers.Kind.WIND)
	world.powers.grant(AdventurePowers.Kind.ANCHOR)
	world.toggle_super_jump()
	world.launch(Vector2(0, -500))
	await frames(12)
	check(world.use_anchor() and world.powers.wind == 2 and world.powers.anchor == 2, "both powers combine in one flight")
	await frames(80)
	check(world.player.can_jump() and world.player.last_island.index == 5, "anchor descent lands on moving platform")
	var relative := world.player.position - world.islands[5].position
	await frames(20)
	check((world.player.position - world.islands[5].position).distance_to(relative) < 2.0, "platform carry remains intact after anchor")
	world.player.position.y = 700
	world.player.state = JumpingPenguin.State.AIR
	await frames(2)
	check(world.splash_time >= 0 and world.powers.wind == 0 and world.powers.anchor == 0, "water immediately clears charges")
	check(not world.use_anchor() and not world.toggle_super_jump(), "powers unavailable during splash")
	await frames(80)
	check(not world.artifacts[0].taken and not world.artifacts[1].taken and world.powers.wind == 0, "retry restores artifacts with empty inventory")
	world.powers.grant(AdventurePowers.Kind.ANCHOR)
	world.player.position = world.goal_position() + Vector2(0, 34)
	world._check_goal()
	check(world.finished and not world.use_anchor(), "cannot anchor after victory")
	world.queue_free()
	await frames(2)

func touch(id: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	runner.root.push_input(event, true)

func click(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	runner.root.push_input(event, true)

func test_input() -> void:
	var game = load("res://main.tscn").instantiate()
	runner.root.add_child(game)
	game.start_level(0)
	await frames(5)
	var world: PenguinWorld = game.world
	check(game.wind_button.size.x >= 88 and game.wind_button.size.y >= 88 and game.anchor_button.size.y >= 88, "touch targets meet minimum size")
	var wind_at: Vector2 = game.stage.position + game.wind_button.position + Vector2(30, 30)
	var anchor_at: Vector2 = game.stage.position + game.anchor_button.position + Vector2(30, 30)
	touch(1, wind_at, true)
	touch(1, wind_at, false)
	check(world.gesture.pointer == -99, "disabled power button consumes input")
	world.powers.grant(AdventurePowers.Kind.WIND)
	world.powers.grant(AdventurePowers.Kind.ANCHOR)
	await frames(1)
	touch(1, wind_at, true)
	touch(1, wind_at, false)
	check(world.powers.armed and world.gesture.pointer == -99, "touch arms boost without beginning aim")
	var origin := Vector2(600, 450)
	touch(4, origin, true)
	touch(5, wind_at, true)
	touch(5, wind_at, false)
	check(world.powers.armed and world.gesture.pointer == 4, "second finger on power button cannot alter aim or arm state")
	touch(4, origin, false, true)
	check(not world.powers.armed and world.powers.wind == 3, "OS touch cancellation preserves charges")
	click(wind_at, true)
	click(wind_at, false)
	check(world.powers.armed, "mouse arms power")
	game.pause_game()
	check(not world.powers.armed and world.powers.wind == 3 and world.powers.anchor == 3, "pause disarms but preserves inventory")
	check(not world.toggle_super_jump() and not world.use_anchor(), "paused powers reject direct activation")
	game.resume_game()
	world.toggle_super_jump()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(runner.paused and not world.powers.armed and world.powers.wind == 3, "background and foreground preserve charges and require resume")
	game.resume_game()
	# Release an active gesture over the anchor button. This must launch only.
	world.toggle_super_jump()
	click(Vector2(anchor_at.x - 100, anchor_at.y + 80), true)
	click(anchor_at, false)
	check(world.player.state == JumpingPenguin.State.AIR and world.powers.wind == 2 and world.powers.anchor == 3, "gesture release over anchor launches without triggering anchor")
	await frames(4)
	touch(7, anchor_at, true)
	check(world.player.velocity == Vector2.ZERO and world.powers.anchor == 2, "anchor activates on touch down, without waiting for release")
	touch(8, anchor_at, true)
	touch(8, anchor_at, false)
	touch(7, anchor_at, false)
	check(world.powers.anchor == 2, "multi-touch cannot double-spend anchor")
	game.start_level(0)
	await frames(5)
	check(game.world.powers.wind == 0 and not game.world.artifacts[0].taken, "manual restart resets inventory and pickups")
	game.world.player.position = game.world.artifact_position(game.world.artifacts[0]) + Vector2(0, 34)
	game.world.player.state = JumpingPenguin.State.AIR
	await frames(1)
	check(game.wind_button.charges == 3 and game.power_hint_time > 0.0 and game.power_hud_effects.motes.size() == 3, "collection updates HUD, tutorial and three traveling pearls")
	game.pause_game()
	var hint_time: float = game.power_hint_time
	var mote_age: float = game.power_hud_effects.motes[0].age
	await frames(5)
	check(game.power_hint_time == hint_time and game.power_hud_effects.motes[0].age == mote_age, "pause freezes the tutorial and collection animation")
	game.resume_game()
	game.start_level(1)
	await frames(5)
	check(game.world.powers.wind == 0 and not game.world.artifacts[0].taken, "level transition starts empty")
	for id in AdventureCharacters.IDS:
		runner.root.get_node("Progress").selected_character = id
		game.start_level(0)
		await frames(5)
		game.world.powers.grant(AdventurePowers.Kind.WIND)
		game.world.powers.grant(AdventurePowers.Kind.ANCHOR)
		game.world.toggle_super_jump()
		check(game.world.launch(Vector2(0, -500)), "equipped character launches: " + id)
		await frames(5)
		check(game.world.use_anchor(), "equipped character anchors: " + id)
		await frames(35)
		check(game.world.player.can_jump(), "equipped character lands: " + id)
	game.show_home()
	game.queue_free()
	await frames(2)
