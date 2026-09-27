extends SceneTree

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	e.canceled = false
	return e

var hits := 0

func _initialize() -> void:
	_probe.call_deferred()

func _probe() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_level(0)
	await frames(5)
	var btn: Button = game.stage.get_node("PauseButton")
	btn.pressed.connect(func(): hits += 1)
	var at: Vector2 = btn.get_global_rect().get_center()

	# main._input ENABLED (normal runtime path)
	root.push_input(touch(2, Vector2(400, 400), true), true)
	await frames(1)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(600, 250)
	root.push_input(drag, true)
	await frames(1)
	print("PROBE normal path: pointer=", game.world.gesture.pointer, " displacement=", game.world.gesture.displacement, " aim=", game.world.player.aim)
	root.push_input(touch(2, Vector2(600, 250), false), true)
	await frames(3)
	print("PROBE after release: pointer=", game.world.gesture.pointer, " velocity=", game.world.player.velocity, " state=", game.world.player.state)
	quit(0)
