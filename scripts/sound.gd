extends Node

var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	add_child(music)
	if ResourceLoader.exists("res://assets/audio/music.wav"):
		var stream: AudioStreamWAV = load("res://assets/audio/music.wav")
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
		music.stream = stream
		music.volume_db = -17.0
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	for name in ["jump", "land", "star", "splash", "win", "tap", "artifact", "super_jump", "anchor"]:
		var path := "res://assets/audio/%s.wav" % name
		if ResourceLoader.exists(path):
			sounds[name] = load(path)
	apply_settings()

func apply_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if music.stream:
		if Progress.music_enabled and not music.playing:
			music.play()
		elif not Progress.music_enabled:
			music.stop()

func effect(name: String) -> void:
	if DisplayServer.get_name() == "headless" or not Progress.effects_enabled or not sounds.has(name):
		return
	for player in voices:
		if not player.playing:
			player.stream = sounds[name]
			player.volume_db = -9.0
			player.play()
			return

func suspend_audio(suspended: bool) -> void:
	music.stream_paused = suspended
	for player in voices:
		player.stream_paused = suspended

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in voices:
		player.stop()
		player.stream = null
	sounds.clear()
