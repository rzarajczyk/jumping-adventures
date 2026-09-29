extends SceneTree

var game: Node

func _initialize() -> void:
	_capture.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/powers-%s.png" % name)

func freeze() -> void:
	game.world.set_physics_process(false)
	game.world.player.set_physics_process(false)
	game.world.effects.set_physics_process(false)

func _capture() -> void:
	var save = root.get_node("Progress")
	save.save_path = "res://build/capture-powers-progress.cfg"
	save.selected_character = "penguin"
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_level(0)
	await frames(8)
	await snap("start")
	game.world.player.position = game.world.islands[2].position + Vector2(-100, -2)
	game.world.camera.position.x = game.world.islands[2].position.x + 240
	freeze()
	await frames(4)
	await snap("artifacts")
	for id in AdventureCharacters.IDS:
		save.selected_character = id
		game.start_level(0)
		await frames(5)
		game.world.powers.grant(AdventurePowers.Kind.JETPACK)
		game.world.launch(Vector2(300, -600))
		await frames(28)
		game.world.use_jetpack()
		await frames(6)
		freeze()
		await snap("jetpack-" + id)
		if id == "penguin":
			game.world.set_physics_process(true)
			game.world.player.set_physics_process(true)
			game.world.effects.set_physics_process(true)
			await frames(26)
			freeze()
			await snap("after-jetpack")
	save.selected_character = "penguin"
	game.difficulty = 2
	game.start_level(2)
	await frames(6)
	game.world.powers.grant(AdventurePowers.Kind.JETPACK)
	game.world.launch(Vector2(250, -800))
	await frames(39)
	game.world.use_jetpack()
	await frames(18)
	game.world.use_jetpack()
	await frames(18)
	freeze()
	await snap("apex")
	root.size = Vector2i(1600, 720)
	await frames(4)
	await snap("wide")
	game.show_home()
	game.queue_free()
	await frames(2)
	root.get_node("Sound").music.stop()
	DirAccess.remove_absolute("res://build/capture-powers-progress.cfg")
	quit()
