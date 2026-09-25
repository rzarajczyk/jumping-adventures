extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func snap(name: String) -> void:
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/%s.png" % name)

func _capture() -> void:
	var save = root.get_node("Progress")
	save.save_path = "res://build/capture-progress.cfg"
	save.records.clear()
	save.selected_character = "penguin"
	root.size = Vector2i(1280, 720)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await snap("menu")
	game.show_characters()
	await snap("characters")
	save.select_character("capybara")
	game.show_home()
	await snap("capybara-menu")
	game.show_levels()
	await snap("levels")
	game.start_level(0)
	await snap("game")
	game.world._begin(1, Vector2(800, 520))
	game.world._drag(1, Vector2(960, 370))
	await snap("aim")
	game.pause_game()
	await snap("pause")
	game.resume_game()
	game.world.star_count = 7
	game.world.player.position = game.world.goal_position() + Vector2(0, 34)
	game.world._check_goal()
	await create_timer(0.7).timeout
	await snap("victory")
	game.start_level(0)
	game.world.player.position = game.world.islands.back().position + Vector2(-210, -2)
	game.world.camera.position.x = game.world.player.position.x + 220
	game.world.set_physics_process(false)
	game.world.player.set_physics_process(false)
	await snap("finish-star")
	game.difficulty = 2
	game.start_level(2)
	await snap("aurora")
	root.size = Vector2i(1600, 720)
	await snap("wide")
	game.show_characters()
	await snap("characters-wide")
	for id in AdventureCharacters.IDS:
		save.select_character(id)
		game.start_level(0)
		await snap("character-" + id)
	game.show_home()
	root.remove_child(game)
	game.queue_free()
	await process_frame
	# Let the audio server release the looping playback before terminating the tool.
	root.get_node("Sound").music.stop()
	await create_timer(0.15).timeout
	DirAccess.remove_absolute("res://build/capture-progress.cfg")
	quit()
