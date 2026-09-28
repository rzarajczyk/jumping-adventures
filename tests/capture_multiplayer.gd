extends SceneTree
## Rendered UI smoke test; no connection and no campaign save writes.
var game: Node
var race: Node

func _initialize() -> void:
	_capture.call_deferred()

func snap(label: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/race-%s.png" % label)

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.show_multiplayer()
	await snap("menu")
	race = root.get_node("Race")
	race.set_process(false)
	race.set_physics_process(false)
	race.phase = "lobby"
	race.hosting = true
	race.authenticated = true
	race.characters = ["penguin", "panda"]
	race.changed.emit()
	await snap("lobby")
	race.config = {"level": 0, "difficulty": 0, "round": "capture", "seed": 13, "characters": race.characters}
	race._setup_simulation()
	race.confirmed = race.simulation.snapshot()
	race.phase = "race"
	race.start_ms = LanPairing.now_ms() + 100000
	race.changed.emit()
	await snap("game")
	race.confirmed.players[1].position.x = 1800
	race.snapshot_received.emit(race.confirmed, true)
	await snap("arrow")
	race.phase = "paused"
	race.changed.emit()
	await snap("pause")
	race.simulation.state.players[0].finish = 96.28
	race.simulation.state.players[0].stars = 4
	race.simulation.state.players[1].stars = 6
	race.simulation.state.ended = true
	race.confirmed = race.simulation.snapshot()
	race.phase = "results"
	race.changed.emit()
	await snap("results")
	game.show_home()
	root.remove_child(game)
	game.queue_free()
	root.get_node("Sound").music.stop()
	await create_timer(0.2).timeout
	quit()
