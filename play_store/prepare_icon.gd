extends SceneTree

func _initialize() -> void:
	var icon := Image.load_from_file("res://assets/art/icon.png")
	if icon.is_empty():
		push_error("Could not load app icon")
		quit(1)
		return
	icon.convert(Image.FORMAT_RGBA8)
	icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var error := icon.save_png("res://play_store/assets/app-icon-512.png")
	if error != OK:
		push_error("Could not save Play icon: %s" % error)
		quit(1)
		return
	quit()
