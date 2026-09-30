extends SceneTree
## Captures unaltered gameplay from the current build for the Play listing.
## The tablet set is rendered at a larger 16:9 viewport using the project's
## normal canvas stretch settings.

const OUT := "res://play_store/assets/screenshots"
var game: Node
var progress: Node

func _initialize() -> void:
	_capture.call_deferred()

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func snap(device: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	print("capture ", device, "/", name, " instruction_card=", game.hint_panel.visible if is_instance_valid(game.hint_panel) else "freed", " app_process=", game.is_processing())
	var image := root.get_texture().get_image()
	image.save_jpg("%s/%s/%s.jpg" % [OUT, device, name], 0.94)

func freeze() -> void:
	game.world.set_physics_process(false)
	game.world.player.set_physics_process(false)
	game.world.effects.set_physics_process(false)

func set_viewport(width: int, height: int) -> void:
	root.size = Vector2i(width, height)
	# Godot's canvas_items stretch already scales the stage to the output resolution.
	# Applying a second scale here would enlarge the HUD over the character.
	game.stage.scale = Vector2.ONE
	game.stage.position = Vector2.ZERO

func setup(device: String, width: int, height: int) -> void:
	progress.selected_character = "penguin"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	set_viewport(width, height)
	game.start_level(0)
	await frames(10)
	game.hint_panel.visible = false
	game.set_process(false)

func cleanup() -> void:
	game.show_home()
	game.queue_free()
	await frames(2)

func capture_device(device: String, width: int, height: int) -> void:
	await setup(device, width, height)

	# A clean opening view with the route, stars, first artifact and jetpack HUD.
	freeze()
	await snap(device, "01-skacz-po-wyspach")

	# Show both jetpack artifacts present along the route.
	game.world.set_physics_process(true)
	game.world.player.set_physics_process(true)
	game.world.effects.set_physics_process(true)
	game.world.player.position = game.world.islands[2].position + Vector2(-100, -2)
	game.world.camera.position.x = game.world.islands[2].position.x + 240
	game.backdrop.scroll = game.world.camera.position.x - width * 0.5
	freeze()
	await frames(4)
	await snap(device, "02-dwa-plecaki")

	# Equip a power, jump, then fire the jetpack while airborne.
	game.start_level(0)
	await frames(10)
	game.hint_panel.visible = false
	game.set_process(false)
	game.world.powers.grant(AdventurePowers.Kind.JETPACK)
	game.world.launch(Vector2(300, -600))
	await frames(28)
	game.world.use_jetpack()
	await frames(6)
	freeze()
	await snap(device, "03-jetpack-w-locie")

	# Continue the same flight to show the extra lift and longer jump.
	game.world.set_physics_process(true)
	game.world.player.set_physics_process(true)
	game.world.effects.set_physics_process(true)
	await frames(26)
	freeze()
	await snap(device, "04-dodatkowy-skok")
	await cleanup()

func _capture() -> void:
	progress = root.get_node("Progress")
	progress.save_path = "res://build/capture-play-store-progress.cfg"
	await capture_device("phone", 1920, 1080)
	await capture_device("tablet", 2560, 1440)
	root.get_node("Sound").music.stop()
	DirAccess.remove_absolute("res://build/capture-play-store-progress.cfg")
	quit()
