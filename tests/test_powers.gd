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

func measure(double_jump: bool) -> Vector3:
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
	check(player.jump(Vector2(300, -600)), "measurement launch accepted")
	var ticks := 0
	while not player.can_jump() and ticks < 160:
		await frames(1)
		highest = minf(highest, player.position.y)
		ticks += 1
		if double_jump and ticks == 30:
			check(player.activate_jetpack(), "jetpack launches at apex without a floor")
	check(player.can_jump(), "measurement lands on same-height floor")
	var result := Vector3(start.y - highest, player.position.x - start.x, ticks)
	scene.queue_free()
	await frames(2)
	return result

func test_ballistics() -> void:
	var normal := await measure(false)
	var extended := await measure(true)
	check(extended.x > normal.x + 40, "double jump gains meaningful height")
	check(extended.y > normal.y + 20, "double jump extends horizontal reach")
	check(extended.z > normal.z + 15, "double jump extends flight time")
	print("Jetpack ballistics: normal=", normal, " double_jump=", extended)

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

func check_launch(world: PenguinWorld, direction: float) -> void:
	var velocity := world.player.velocity
	check(absf(velocity.length() - JumpGesture.MAX_SPEED) < 0.01, "doubled launch speed")
	check(absf(rad_to_deg(atan2(-velocity.y, absf(velocity.x))) - 60.0) < 0.01, "fixed 60 degree angle")
	check(signf(velocity.x) == direction, "launch follows facing")
	check(world.player.jetpack_age == 0.0 and world.player.jetpack_flight, "ignition starts temporary equipment animation")

func test_world() -> void:
	var world := make_world()
	await frames(5)
	check(world.powers.jetpack == 0 and not world.use_jetpack(), "attempt starts empty")
	world.player.position = world.artifact_position(world.artifacts[0]) + Vector2(0, 34)
	world.player.state = JumpingPenguin.State.AIR
	world.player.velocity = Vector2(0, -80)
	await frames(1)
	check(world.artifacts[0].taken and world.powers.jetpack == 3, "jetpack can be collected in air")
	await stand(world, 2)
	world.powers.jetpack = 2
	await frames(5)
	check(world.powers.jetpack == 2, "collected artifact does not refill repeatedly")
	await stand(world)
	world.powers.reset()
	world.powers.grant(AdventurePowers.Kind.JETPACK)
	check(world.use_jetpack() and world.powers.jetpack == 2, "jetpack works directly on ground")
	check_launch(world, 1.0)
	check(not world.launch(Vector2(0, -500)), "ordinary jump still requires floor")
	await stand(world)
	check(world.launch(Vector2(300, -600)) and world.powers.jetpack == 2, "normal jump never spends jetpack")
	world.powers.reset()
	for direction in [1.0, -1.0]:
		world.powers.grant(AdventurePowers.Kind.JETPACK)
		for vy in [-700.0, 0.0, 500.0]:
			world.player.position = Vector2(900, 180)
			world.player.state = JumpingPenguin.State.AIR
			world.player.facing = direction
			world.player.velocity = Vector2(direction * 600, vy)
			var count := world.powers.jetpack
			check(world.use_jetpack() and world.powers.jetpack == count - 1, "jetpack replaces momentum while rising, at apex and falling")
			check_launch(world, direction)
			await frames(2)
			check(world.player.velocity.y < 0, "gravity resumes with upward flight")
		check(not world.use_jetpack() and world.powers.jetpack == 0, "three uses in one flight exhaust charges")
	world.player.facing = 1.0
	world.powers.grant(AdventurePowers.Kind.JETPACK)
	check(world.use_jetpack() and world.powers.jetpack == 2, "spend one charge before collecting second artifact")
	await stand(world, 4)
	check(world.artifacts[1].taken and world.powers.jetpack == 5, "second artifact adds three to two remaining charges")
	await stand(world)
	world._begin(1, Vector2(500, 400))
	world._drag(1, Vector2(600, 250))
	check(world.use_jetpack() and world.gesture.pointer == -99 and world.player.aim == Vector2.ZERO, "jetpack cancels aiming and launches immediately")
	world._end(1, Vector2(600, 250))
	check(world.powers.jetpack == 4, "old gesture release cannot spend another charge")
	await frames(30)
	check(world.player.jetpack_age >= AdventurePowers.JETPACK_DURATION, "jetpack overlay expires after ignition")
	await stand(world)
	world.player.position = Vector2(250, 210)
	world.player.state = JumpingPenguin.State.AIR
	world.powers.grant(AdventurePowers.Kind.JETPACK)
	check(world.use_jetpack(), "high airborne launch accepted")
	var top := 10000.0
	var water_error := 0.0
	for tick in 28:
		await frames(1)
		var transform := world.get_canvas_transform()
		top = minf(top, (transform * (world.player.position + Vector2(0, -92))).y)
		water_error = maxf(water_error, absf((transform * Vector2(0, PenguinWorld.WATER_Y)).y - PenguinWorld.WATER_Y))
	check(top >= 100.0, "camera keeps airborne jetpack visible below HUD")
	check(water_error < 1.0, "zoom preserves water screen position")
	await stand(world)
	await frames(30)
	check(absf(world.camera.zoom.x - 1.0) < 0.03, "camera returns after landing")
	world.player.position.y = 700
	world.player.state = JumpingPenguin.State.AIR
	check(not world.use_jetpack(), "cannot escape after crossing waterline")
	await frames(2)
	check(world.splash_time >= 0 and world.powers.jetpack == 0, "water clears charges")
	check(not world.use_jetpack(), "jetpack unavailable during splash")
	await frames(80)
	check(not world.artifacts[0].taken and not world.artifacts[1].taken and world.powers.jetpack == 0, "retry restores artifacts and resets inventory")
	world.powers.grant(AdventurePowers.Kind.JETPACK)
	world.player.position = world.goal_position() + Vector2(0, 34)
	world._check_goal()
	check(world.finished and not world.use_jetpack(), "cannot use jetpack after victory")
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
	check(game.jetpack_button.size.x >= 88 and game.jetpack_button.size.y >= 88, "touch target meets minimum size")
	var at: Vector2 = game.stage.position + game.jetpack_button.position + Vector2(30, 30)
	touch(1, at, true)
	touch(1, at, false)
	check(world.gesture.pointer == -99, "disabled button consumes input")
	world.powers.grant(AdventurePowers.Kind.JETPACK)
	await frames(1)
	touch(1, at, true)
	check(world.player.state == JumpingPenguin.State.AIR and world.powers.jetpack == 2, "touch down launches from ground immediately")
	touch(1, at, false)
	check(world.powers.jetpack == 2 and world.gesture.pointer == -99, "release does not retrigger or start aiming")
	await frames(15)
	touch(2, at, true)
	touch(2, at, false)
	check(world.powers.jetpack == 1 and world.player.velocity.y < -360, "touch works in midair")
	await frames(4)
	click(at, true)
	click(at, false)
	check(world.powers.jetpack == 0, "mouse also triggers airborne jetpack")
	world.powers.grant(AdventurePowers.Kind.JETPACK)
	game.pause_game()
	check(not world.use_jetpack() and world.powers.jetpack == 3, "pause prevents use and preserves charges")
	game.resume_game()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(runner.paused and world.powers.jetpack == 3, "background preserves charges and requires resume")
	game.resume_game()
	await stand(world)
	await frames(1)
	click(Vector2(at.x - 100, at.y + 80), true)
	click(at, false)
	check(world.player.state == JumpingPenguin.State.AIR and world.powers.jetpack == 3, "gesture release over button only launches ordinary jump")
	await stand(world)
	var origin := Vector2(600, 450)
	touch(4, origin, true)
	touch(5, at, true)
	touch(5, at, false)
	check(world.gesture.pointer == -99 and world.powers.jetpack == 2, "second finger activates jetpack while aiming")
	touch(4, origin, false, true)
	check(world.powers.jetpack == 2, "canceled old touch preserves remaining charges")
	game.start_level(0)
	await frames(5)
	check(game.world.powers.jetpack == 0 and not game.world.artifacts[0].taken, "restart resets inventory and pickups")
	game.world.player.position = game.world.artifact_position(game.world.artifacts[0]) + Vector2(0, 34)
	game.world.player.state = JumpingPenguin.State.AIR
	await frames(1)
	check(game.jetpack_button.charges == 3 and game.power_hint_time > 0.0 and game.power_hud_effects.motes.size() == 3, "collection updates HUD, tutorial and three pearls")
	game.world.player.position = game.world.artifact_position(game.world.artifacts[1]) + Vector2(0, 34)
	game.world.player.velocity = Vector2.ZERO
	game.world.player.state = JumpingPenguin.State.AIR
	await frames(1)
	check(game.world.artifacts[1].taken and game.jetpack_button.charges == 6, "second pickup displays six available jumps")
	await frames(5)
	check(game.world.powers.jetpack == 6, "remaining near a collected refill does not grant more charges")
	for remaining in range(5, -1, -1):
		check(game.world.use_jetpack() and game.jetpack_button.charges == remaining, "six collected charges can be spent and update HUD: %d left" % remaining)
	check(not game.world.use_jetpack(), "seventh jump is rejected after spending six collected charges")
	game.pause_game()
	var hint_time: float = game.power_hint_time
	var mote_age: float = game.power_hud_effects.motes[0].age
	await frames(5)
	check(game.power_hint_time == hint_time and game.power_hud_effects.motes[0].age == mote_age, "pause freezes tutorial and collection animation")
	game.resume_game()
	game.start_level(1)
	await frames(5)
	check(game.world.powers.jetpack == 0 and not game.world.artifacts[0].taken, "level transition starts empty")
	for id in AdventureCharacters.IDS:
		runner.root.get_node("Progress").selected_character = id
		game.start_level(0)
		await frames(5)
		game.world.powers.grant(AdventurePowers.Kind.JETPACK)
		check(game.world.launch(Vector2(210, -500)), "character launches: " + id)
		await frames(20)
		check(game.world.use_jetpack(), "character double jumps: " + id)
		await frames(90)
		check(game.world.player.can_jump(), "character lands after double jump: " + id)
	game.show_home()
	game.queue_free()
	await frames(2)
