extends Node2D

const INK := Color("31485b")
const MUTED := Color("68818c")
const CREAM := Color("fffdf6")
const TEAL := Color("398b82")
const GOLD := Color("e7ae55")
const LEVELS: Array[LevelDefinition] = [preload("res://resources/levels/garden.tres"), preload("res://resources/levels/crystal.tres"), preload("res://resources/levels/aurora.tres")]
const PROFILES: Array[DifficultyProfile] = [preload("res://resources/difficulties/easy.tres"), preload("res://resources/difficulties/medium.tres"), preload("res://resources/difficulties/hard.tres")]

var backdrop: SkyBackdrop
var world: PenguinWorld
var canvas: CanvasLayer
var stage: Control
var modal: Control
var font: Font
var bold: FontVariation
var difficulty: int = 0
var level_index: int = 0
var screen := "home"
var star_label: Label
var progress_bar: ProgressBar
var power_bar: ProgressBar
var hint_label: Label
var hint_panel: Panel
var splash_label: Label
var hero: TextureRect
var menu_clock: float = 0.0
var hero_base_y: float = 239.0
var pause_overlay := false
var application_suspended := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var regular := FontVariation.new()
	regular.base_font = load("res://assets/fonts/Nunito.ttf")
	regular.variation_opentype = {2003265652: 600.0}
	font = regular
	bold = FontVariation.new()
	bold.base_font = regular.base_font
	bold.variation_opentype = {2003265652: 850.0}
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	backdrop = SkyBackdrop.new()
	sky_layer.add_child(backdrop)
	canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = Vector2(1280, 720)
	canvas.add_child(stage)
	get_viewport().size_changed.connect(_layout)
	_layout()
	show_home()
	# Explicit developer switches for reproducible screenshots and smoke tests.
	if OS.has_feature("debug"):
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--level="):
				var parts := arg.trim_prefix("--level=").split(",")
				if parts.size() == 2:
					difficulty = clampi(int(parts[1]), 0, 2)
					start_level(clampi(int(parts[0]), 0, 2))

func _layout() -> void:
	var size := get_viewport_rect().size
	stage.position = (size - stage.size) * 0.5
	# The centered design already has 48px internal margins. Account for safe areas
	# on devices whose display cutout extends beyond those margins.
	if OS.get_name() == "Android":
		var safe := DisplayServer.get_display_safe_area()
		var display := Vector2(DisplayServer.screen_get_size())
		if display.x > 0 and display.y > 0:
			var scale_to_view := size / display
			var left := safe.position.x * scale_to_view.x
			var right := (display.x - safe.end.x) * scale_to_view.x
			stage.position.x += (left - right) * 0.5

func _clear() -> void:
	for child in stage.get_children():
		stage.remove_child(child)
		child.queue_free()
	modal = null
	hero = null
	star_label = null
	progress_bar = null
	power_bar = null
	hint_label = null
	hint_panel = null
	splash_label = null
	pause_overlay = false

func _leave_world() -> void:
	get_tree().paused = false
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	backdrop.scroll = 0
	backdrop.theme_id = 0
	backdrop.tint = Color.WHITE

func _panel(parent: Node, rect: Rect2, color: Color = CREAM, radius: int = 26) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _box(color, radius))
	parent.add_child(panel)
	return panel

func _box(color: Color, radius: int = 22, shadow: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if shadow:
		box.shadow_color = Color(0.20, 0.36, 0.42, 0.09)
		box.shadow_size = 10
		box.shadow_offset = Vector2(0, 5)
	return box

func _label(parent: Node, text: String, rect: Rect2, size: int = 24, color: Color = INK, heavy: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", bold if heavy else font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2, action: Callable, filled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold)
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", CREAM if filled else INK)
	b.add_theme_color_override("font_hover_color", CREAM if filled else INK)
	b.add_theme_color_override("font_pressed_color", CREAM if filled else INK)
	b.add_theme_color_override("font_disabled_color", Color("98a4aa"))
	var normal := TEAL if filled else CREAM
	b.add_theme_stylebox_override("normal", _box(normal, 20))
	b.add_theme_stylebox_override("hover", _box(normal.lightened(0.07), 20))
	b.add_theme_stylebox_override("pressed", _box(normal.darkened(0.06), 20, false))
	b.add_theme_stylebox_override("disabled", _box(Color(0.96, 0.97, 0.95, 0.74), 20, false))
	b.pressed.connect(func(): Sound.effect("tap"); action.call())
	parent.add_child(b)
	return b

func _picture(parent: Node, art: String, rect: Rect2) -> TextureRect:
	var view := TextureRect.new()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture = PenguinArt.texture(art)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	view.position = rect.position
	view.size = rect.size
	return view

func _character_picture(parent: Node, id: String, rect: Rect2) -> TextureRect:
	var view := _picture(parent, "penguin", rect)
	view.texture = AdventureCharacters.frame(id)
	return view

func show_home() -> void:
	_leave_world()
	_clear()
	screen = "home"
	_panel(stage, Rect2(65, 120, 625, 465), Color(1, 0.995, 0.966, 0.92), 34)
	_picture(stage, "star", Rect2(68, 38, 42, 44))
	_label(stage, "JUMPING ADVENTURE", Rect2(120, 40, 470, 44), 24, INK, true)
	_button(stage, "Dźwięk", Rect2(1092, 34, 128, 54), show_settings)
	_label(stage, "MAŁE ŁAPKI, WIELKIE MARZENIA", Rect2(101, 149, 560, 35), 17, TEAL, true)
	_label(stage, "Wielka przygoda\nmałych przyjaciół.", Rect2(98, 195, 580, 165), 48, INK, true)
	_label(stage, "Skacz po wyspach. Zbieraj gwiazdki!", Rect2(102, 367, 565, 40), 23, MUTED)
	for i in 3:
		var b := _button(stage, PROFILES[i].title, Rect2(101 + i * 178, 425, 164, 56), func(): difficulty = i; show_home(), difficulty == i)
		b.name = "Difficulty%d" % i
	_button(stage, "Start   →", Rect2(101, 501, 520, 62), show_levels, true)
	_picture(stage, "garden", Rect2(756, 483, 422, 150))
	hero_base_y = 239
	hero = _character_picture(stage, Progress.selected_character, Rect2(834, hero_base_y, 248, 277))
	_picture(stage, "star", Rect2(752, 256, 64, 64))
	_picture(stage, "star", Rect2(1112, 344, 62, 62))
	_label(stage, AdventureCharacters.display_name(Progress.selected_character), Rect2(806, 173, 320, 48), 29, TEAL, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var choose := _button(stage, "Zmień postać", Rect2(822, 600, 280, 62), show_characters)
	choose.name = "ChooseCharacter"
	_label(stage, "%d przyjaciół   ·   3 krainy   ·   mnóstwo gwiazdek" % AdventureCharacters.IDS.size(), Rect2(83, 635, 730, 36), 20, INK)

func show_characters() -> void:
	_leave_world()
	_clear()
	screen = "characters"
	_button(stage, "←  Wróć", Rect2(58, 38, 147, 56), show_home)
	_label(stage, "Kto dziś wyrusza w przygodę?", Rect2(64, 126, 1150, 70), 44, INK, true)
	_label(stage, "Każdy skacze tak samo dobrze. Wybierz swojego przyjaciela!", Rect2(67, 197, 1140, 36), 22, MUTED)
	var card_gap := 14.0
	var card_width := (stage.size.x - 96.0 - card_gap * (AdventureCharacters.IDS.size() - 1)) / AdventureCharacters.IDS.size()
	for i in AdventureCharacters.IDS.size():
		var id: String = AdventureCharacters.IDS[i]
		var selected := id == Progress.selected_character
		var card := _button(stage, "", Rect2(48 + i * (card_width + card_gap), 268, card_width, 303), func(): Progress.select_character(id); show_characters(), selected)
		card.name = "Character_" + id
		_character_picture(card, id, Rect2(20, 24, card_width - 40, 174))
		_label(card, AdventureCharacters.NAMES[i], Rect2(10, 209, card_width - 20, 40), 27, CREAM if selected else INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(card, "✓  Wybrano" if selected else "Wybierz mnie", Rect2(10, 256, card_width - 20, 30), 18, CREAM if selected else MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(stage, "Ruszamy!   →", Rect2(430, 614, 420, 64), show_levels, true)

func show_levels() -> void:
	_leave_world()
	_clear()
	screen = "levels"
	_button(stage, "←  Wróć", Rect2(58, 38, 147, 56), show_home)
	_label(stage, "Dokąd dziś skaczemy?", Rect2(62, 129, 1050, 72), 48, INK, true)
	_label(stage, PROFILES[difficulty].subtitle, Rect2(65, 205, 900, 36), 22, MUTED)
	for i in 3:
		var x: float = 64 + i * 392
		var open := Progress.unlocked(difficulty, i)
		var card := _button(stage, "", Rect2(x, 278, 368, 319), func(): start_level(i))
		card.disabled = not open
		card.name = "Level%d" % i
		_label(card, "0%d" % (i + 1), Rect2(24, 14, 64, 38), 24, MUTED, true)
		_picture(card, LEVELS[i].art, Rect2(26, 68, 316, 121))
		_label(card, LEVELS[i].title, Rect2(23, 194, 330, 43), 27, INK, true)
		var collected: int = Progress.best(difficulty, i).collected
		var detail := ("★  %d / 11 gwiazdek" % collected) if open else "Najpierw ukończ poprzednią wyspę"
		_label(card, detail, Rect2(24, 244, 332, 40), 25 if open else 17, GOLD if open else MUTED, open)
	_label(stage, "10 małych gwiazdek po drodze + wielka gwiazda na mecie!", Rect2(67, 638, 1100, 35), 21, INK)

func start_level(index: int) -> void:
	_leave_world()
	_clear()
	screen = "game"
	level_index = index
	backdrop.theme_id = index
	backdrop.tint = LEVELS[index].tint
	world = PenguinWorld.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.character_id = Progress.selected_character
	world.definition = LEVELS[index]
	world.profile = PROFILES[difficulty]
	world.stars_changed.connect(_stars_changed)
	world.completed.connect(_won)
	world.island_reached.connect(_island_reached)
	world.retry_started.connect(func(): if is_instance_valid(hint_panel): hint_panel.visible = level_index == 0)
	add_child(world)
	_build_hud()

func _build_hud() -> void:
	_panel(stage, Rect2(44, 27, 410, 79), Color(1, 0.995, 0.97, 0.94), 23)
	_label(stage, LEVELS[level_index].title, Rect2(67, 37, 370, 35), 24, INK, true)
	_label(stage, "%s  ·  Wyprawa %d / 3" % [PROFILES[difficulty].title, level_index + 1], Rect2(68, 74, 370, 25), 16, MUTED)
	_panel(stage, Rect2(896, 29, 160, 67))
	_picture(stage, "star", Rect2(911, 44, 36, 36))
	star_label = _label(stage, "0 / 11", Rect2(961, 44, 85, 40), 25, INK, true)
	var pause_button := _button(stage, "Ⅱ", Rect2(1152, 29, 75, 67), pause_game)
	pause_button.name = "PauseButton"
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(478, 46)
	progress_bar.size = Vector2(370, 13)
	progress_bar.show_percentage = false
	progress_bar.max_value = 20
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.65), 7, false))
	progress_bar.add_theme_stylebox_override("fill", _box(TEAL, 7, false))
	stage.add_child(progress_bar)
	_label(stage, "Twoja droga do wielkiej gwiazdy", Rect2(478, 68, 370, 26), 15, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel = _panel(stage, Rect2(354, 534, 572, 120), Color(1, 0.995, 0.97, 0.93), 22)
	hint_panel.visible = level_index == 0
	_label(hint_panel, "●    ↗    ✧", Rect2(24, 22, 164, 54), 34, TEAL, true)
	hint_label = _label(hint_panel, "Przeciągnij w górę i w prawo.\nPuść palec, żeby skoczyć!", Rect2(193, 26, 370, 73), 23, INK, true)
	power_bar = ProgressBar.new()
	power_bar.position = Vector2(465, 664)
	power_bar.size = Vector2(350, 12)
	power_bar.show_percentage = false
	power_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.7), 6, false))
	power_bar.add_theme_stylebox_override("fill", _box(TEAL, 6, false))
	stage.add_child(power_bar)
	power_bar.visible = false
	splash_label = _label(stage, "Plusk! Spróbuj jeszcze raz…", Rect2(280, 286, 720, 65), 38, INK, true)
	splash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash_label.visible = false

func _stars_changed(count: int) -> void:
	if is_instance_valid(star_label):
		star_label.text = "%d / 11" % count

func _island_reached(index: int) -> void:
	if is_instance_valid(progress_bar):
		progress_bar.value = index
	if is_instance_valid(hint_panel):
		hint_panel.visible = level_index == 0 and index < 3
		if index == 0:
			hint_label.text = "Przeciągnij w górę i w prawo.\nPuść palec, żeby skoczyć!"
		elif index == 1:
			hint_label.text = "Dłuższy gest = mocniejszy skok.\nZbieraj gwiazdki po drodze!"
		elif index == 2:
			hint_label.text = "Wyspa się rusza? Wybierz moment.\nMożesz spokojnie poczekać."

func _overlay() -> Control:
	if is_instance_valid(modal):
		stage.remove_child(modal)
		modal.queue_free()
	modal = Control.new()
	modal.size = stage.size
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(modal)
	var shade := ColorRect.new()
	shade.position = -get_viewport_rect().size
	shade.size = get_viewport_rect().size * 3.0
	shade.color = Color(0.16, 0.26, 0.34, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(shade)
	_panel(modal, Rect2(361, 104, 558, 512), CREAM, 34)
	return modal

func _close_overlay() -> void:
	if is_instance_valid(modal):
		stage.remove_child(modal)
		modal.queue_free()
	modal = null

func pause_game() -> void:
	if not is_instance_valid(world) or world.finished or pause_overlay:
		return
	world.cancel_gesture()
	pause_overlay = true
	get_tree().paused = true
	var ui := _overlay()
	_label(ui, "Mała przerwa", Rect2(400, 135, 480, 64), 42, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(ui, "Twoje wyspy poczekają.", Rect2(400, 210, 480, 35), 23, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(ui, "Wracamy do skakania", Rect2(415, 274, 450, 65), resume_game, true)
	_button(ui, "Zacznij planszę od nowa", Rect2(415, 358, 450, 59), func(): start_level(level_index))
	_button(ui, "Wybór wyspy", Rect2(415, 436, 450, 59), show_levels)
	_button(ui, "Dźwięk", Rect2(515, 524, 250, 54), show_settings)

func resume_game() -> void:
	if application_suspended:
		return
	_close_overlay()
	pause_overlay = false
	get_tree().paused = false

func show_settings() -> void:
	var from_pause := pause_overlay
	var ui := _overlay()
	_label(ui, "Dźwięki przygody", Rect2(396, 145, 490, 62), 40, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(ui, "Muzyka: " + ("włączona" if Progress.music_enabled else "wyłączona"), Rect2(416, 265, 450, 70), func(): Progress.music_enabled = not Progress.music_enabled; Progress.save_progress(); Sound.apply_settings(); show_settings())
	_button(ui, "Efekty: " + ("włączone" if Progress.effects_enabled else "wyłączone"), Rect2(416, 357, 450, 70), func(): Progress.effects_enabled = not Progress.effects_enabled; Progress.save_progress(); show_settings())
	_button(ui, "Gotowe", Rect2(416, 481, 450, 66), func():
		_close_overlay()
		if from_pause:
			pause_overlay = false
			pause_game()
	, true)

func _won(count: int) -> void:
	Progress.complete(difficulty, level_index, count)
	_clear()
	screen = "victory"
	modal = Control.new()
	modal.size = stage.size
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.add_child(modal)
	var shade := ColorRect.new()
	shade.position = -get_viewport_rect().size
	shade.size = get_viewport_rect().size * 3
	shade.color = Color(0.08, 0.16, 0.27, 0.76)
	modal.add_child(shade)
	var fireworks := AdventureFireworks.new()
	fireworks.name = "Fireworks"
	modal.add_child(fireworks)
	var card := _panel(modal, Rect2(270, 68, 740, 584), CREAM, 38)
	card.name = "VictoryCard"
	card.pivot_offset = card.size * 0.5
	_label(card, "WYPRAWA UKOŃCZONA", Rect2(30, 27, 680, 30), 17, TEAL, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(card, "Zwycięstwo!", Rect2(25, 66, 690, 66), 48, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_character_picture(card, Progress.selected_character, Rect2(180, 146, 146, 153))
	_picture(card, "star", Rect2(388, 146, 144, 144))
	_label(card, "+", Rect2(337, 180, 52, 65), 40, GOLD, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var score := _label(card, "Zebrane gwiazdki: %d / 11" % count, Rect2(30, 316, 680, 52), 33, INK, true)
	score.name = "VictoryScore"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := "Wszystkie gwiazdki są Twoje!" if count == 11 else "Wielka gwiazda zdobyta. Brawo!"
	_label(card, subtitle, Rect2(35, 374, 670, 36), 23, TEAL).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(card, "Następna wyspa   →" if level_index < 2 else "Wybór wyspy", Rect2(55, 431, 630, 62), func():
		if level_index < 2: start_level(level_index + 1)
		else: show_levels()
	, true).name = "NextLevelButton"
	_button(card, "Jeszcze raz", Rect2(55, 510, 303, 52), func(): start_level(level_index))
	_button(card, "Menu", Rect2(382, 510, 303, 52), show_home)
	card.scale = Vector2.ONE * 0.82
	card.modulate.a = 0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.3)

func _process(delta: float) -> void:
	menu_clock += delta
	if is_instance_valid(hero):
		hero.position.y = hero_base_y + sin(menu_clock * 2.0) * 5.0
	if is_instance_valid(world):
		backdrop.scroll = world.camera.position.x - get_viewport_rect().size.x * 0.5
		if is_instance_valid(power_bar):
			power_bar.visible = world.gesture.pointer != -99 and not pause_overlay
			power_bar.value = world.player.aim.length() / JumpGesture.MAX_SPEED * 100
		if is_instance_valid(splash_label):
			splash_label.visible = world.splash_time >= 0.0
			if splash_label.visible and is_instance_valid(hint_panel): hint_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(world):
			if pause_overlay: resume_game()
			else: pause_game()
		elif screen in ["levels", "characters"]: show_home()
		get_viewport().set_input_as_handled()
	# Complete a gesture even when the finger ends on top of a HUD button.
	if is_instance_valid(world) and not get_tree().paused and world.gesture.pointer != -99:
		if event is InputEventScreenTouch and not event.pressed:
			if event.canceled and event.index == world.gesture.pointer: world.cancel_gesture()
			else: world._end(event.index, event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			world._end(-1, event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenDrag:
			world._drag(event.index, event.position)
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			world._drag(-1, event.position)
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		application_suspended = true
		pause_game()
		Sound.suspend_audio(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_suspended = false
		Sound.suspend_audio(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(world): pause_game()
		elif screen in ["levels", "characters"]: show_home()
