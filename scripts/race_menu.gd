class_name RaceMenu
extends Node
## Polish LAN flow; it uses the existing game's typography and controls.
const CREATE_GAME_ICON := preload("res://assets/ui/create_lan_game.svg")
const JOIN_GAME_ICON := preload("res://assets/ui/join_lan_game.svg")

var app: Node2D
var closing := false
var mode := ""
var timer_label: Label
var opponent_score: Label
var message_label: Label
var overlay_label: Label
var code_input: TextEdit
var failure := ""
var address_check_ms := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Race.changed.connect(refresh)
	Lan.scanned.connect(_scanned)
	Lan.scan_failed.connect(_scan_failed)
	Lan.scan_canceled.connect(func(): failure = "Skanowanie anulowane."; refresh())
	refresh()

func shutdown() -> void:
	closing = true
	Race.leave()

func _exit_game() -> void:
	shutdown()
	app.show_home()

func _title(text: String, subtitle: String) -> void:
	app._button(app.stage, "←  Menu", Rect2(55, 30, 158, 57), _exit_game)
	app._label(app.stage, text, Rect2(64, 110, 1120, 64), 43, app.INK, true)
	var label: Label = app._label(app.stage, subtitle, Rect2(65, 181, 1140, 66), 21, app.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func refresh() -> void:
	if closing: return
	if Race.phase in ["loading", "countdown", "race", "paused", "recovering", "results"] and not Race.config.is_empty():
		_ensure_world()
		_refresh_overlay()
		return
	app._leave_world()
	app._clear()
	app.screen = "multiplayer"
	mode = Race.phase
	match Race.phase:
		"idle": _entry()
		"connecting":
			_title("Szukamy drugiego telefonu…", "Oba telefony muszą być w tej samej sieci Wi-Fi lub hotspocie.")
			app._label(app.stage, Race.status, Rect2(80, 300, 1100, 100), 28)
		"lobby":
			if Race.authenticated: _lobby()
			else: _invitation()
		"recovering":
			_title("Odzyskiwanie połączenia", "Twoje miejsce czeka. Sprawdź Wi-Fi na obu telefonach.")
			overlay_label = app._label(app.stage, "", Rect2(80, 300, 1100, 100), 30)
		"aborted":
			_title("Gra została przerwana", Race.status)
			app._button(app.stage, "Spróbuj ponownie", Rect2(390, 345, 500, 75), func(): Race.leave(), true)

func _entry() -> void:
	_title("Przygoda we dwoje", "Połączcie telefony z tym samym Wi-Fi. Możecie też użyć hotspotu jednego z telefonów — Internet nie jest potrzebny.")
	app._panel(app.stage, Rect2(65, 260, 550, 290))
	app._panel(app.stage, Rect2(655, 260, 550, 290))
	_entry_icon(CREATE_GAME_ICON, Rect2(244, 270, 192, 176))
	_entry_icon(JOIN_GAME_ICON, Rect2(834, 270, 192, 176))
	app._button(app.stage, "Utwórz grę", Rect2(109, 452, 462, 65), _choose_network, true).name = "HostRaceButton"
	app._button(app.stage, "Zeskanuj QR", Rect2(699, 452, 462, 65), func(): failure = ""; Lan.scan(), true).name = "ScanRaceButton"
	if OS.get_name() != "Android":
		code_input = TextEdit.new()
		code_input.placeholder_text = "Na komputerze wklej kod połączenia gospodarza"
		code_input.position = Vector2(65, 579)
		code_input.size = Vector2(900, 62)
		code_input.add_theme_font_size_override("font_size", 16)
		app.stage.add_child(code_input)
		app._button(app.stage, "Dołącz", Rect2(990, 579, 215, 62), func(): _scanned(code_input.text))
	if not failure.is_empty():
		var label: Label = app._label(app.stage, failure, Rect2(65, 650, 1140, 60), 18, Color("a35154"))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _entry_icon(texture: Texture2D, rect: Rect2) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = rect.position
	icon.size = rect.size
	app.stage.add_child(icon)

func _choose_network() -> void:
	var addresses: Array[String] = Lan.addresses()
	if addresses.is_empty():
		failure = "Nie znaleziono sieci lokalnej. Włącz Wi-Fi albo hotspot i spróbuj ponownie."
		refresh()
		return
	if addresses.size() == 1:
		_host(addresses[0])
		return
	app._clear()
	_title("Wybierz sieć do gry", "Wybierz adres Wi-Fi lub hotspotu, z którym jest połączony drugi telefon.")
	for i in mini(addresses.size(), 4):
		var ip := addresses[i]
		app._button(app.stage, ip, Rect2(390, 266 + i * 83, 500, 66), func(): _host(ip), true)

func _host(ip: String) -> void:
	var error := Race.host_game(ip, Progress.selected_character)
	if error != OK:
		failure = Race.status
		refresh()

func _scanned(payload: String) -> void:
	if closing or not Race.phase in ["idle", "aborted"]: return
	if Race.join_game(payload, Progress.selected_character) != OK:
		failure = Race.status
		refresh()

func _scan_failed(message: String) -> void:
	failure = message
	refresh()

func _invitation() -> void:
	_title("Zaproś drugiego gracza", "Na drugim telefonie wybierz „Graj we dwoje” → „Zeskanuj QR”.")
	app._panel(app.stage, Rect2(65, 250, 400, 400), Color.WHITE, 24)
	var texture: Texture2D = Lan.qr_texture(Race.pairing_code())
	if texture:
		var qr := TextureRect.new()
		qr.texture = texture
		qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		qr.position = Vector2(85, 270)
		qr.size = Vector2(360, 360)
		qr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		app.stage.add_child(qr)
	else:
		var note: Label = app._label(app.stage, "Na komputerze użyj\nkodu połączenia.", Rect2(92, 365, 350, 130), 27)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app._character_picture(app.stage, Race.characters[0], Rect2(790, 245, 188, 195))
	app._label(app.stage, "Czekamy na przyjaciela…", Rect2(555, 440, 635, 56), 31, app.INK, true)
	app._label(app.stage, "Sieć: " + Race.address, Rect2(555, 507, 635, 40), 22, app.MUTED)
	app._button(app.stage, "Skopiuj kod połączenia", Rect2(555, 573, 410, 62), func(): DisplayServer.clipboard_set(Race.pairing_code()))
	app._button(app.stage, "Zmień sieć", Rect2(982, 573, 220, 62), _choose_network)

func _lobby() -> void:
	_title("Gotowi na wyścig?", "Dwa wyróżnienia: pierwszy na mecie i najwięcej gwiazdek. Po upadku wracasz po 3 sekundach, bez mocy.")
	app._panel(app.stage, Rect2(65, 258, 1140, 395))
	app._label(app.stage, "Trasa", Rect2(89, 273, 120, 33), 19, app.MUTED)
	var route := OptionButton.new()
	route.position = Vector2(89, 310)
	route.size = Vector2(420, 52)
	for level in RaceProtocol.LEVELS: route.add_item(level.title)
	route.selected = Race.level_index
	route.disabled = not Race.hosting
	app.stage.add_child(route)
	route.item_selected.connect(func(index: int): Race.select_route(index, Race.difficulty))
	var profile := OptionButton.new()
	profile.position = Vector2(545, 310)
	profile.size = Vector2(260, 52)
	for value in RaceProtocol.PROFILES: profile.add_item(value.title)
	profile.selected = Race.difficulty
	profile.disabled = not Race.hosting
	app.stage.add_child(profile)
	profile.item_selected.connect(func(index: int): Race.select_route(Race.level_index, index))
	for option in [route, profile]:
		option.add_theme_font_override("font", app.font)
		option.add_theme_font_size_override("font_size", 22)
		for style in ["normal", "hover", "pressed", "disabled"]:
			option.add_theme_stylebox_override(style, app._box(Color("e4efec"), 14, false))
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			option.add_theme_color_override(color, app.INK)
		option.get_popup().add_theme_font_override("font", app.font)
		option.get_popup().add_theme_font_size_override("font_size", 24)
	app._label(app.stage, "Wybierz swoją postać", Rect2(89, 378, 1000, 35), 22, app.INK, true)
	for i in 6:
		var id: String = AdventureCharacters.IDS[i]
		var button: Button = app._button(app.stage, "", Rect2(89 + i * 183, 422, 167, 107), func(): Race.select_character(id), Race.characters[Race.local_player] == id)
		app._character_picture(button, id, Rect2(58, 5, 53, 59))
		var caption: Label = app._label(button, AdventureCharacters.display_name(id), Rect2(4, 65, 159, 31), 18, app.CREAM if Race.characters[Race.local_player] == id else app.INK, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var other := AdventureCharacters.display_name(Race.characters[1 - Race.local_player])
	app._label(app.stage, "Rywal: %s · %s" % [other, "gotowy" if Race.ready_players[1 - Race.local_player] else "wybiera"], Rect2(89, 568, 590, 45), 24, app.TEAL)
	var ready: Button = app._button(app.stage, "Czekamy na rywala…" if Race.ready_players[Race.local_player] else "Gotowy!", Rect2(726, 556, 450, 70), func(): Race.set_ready(), true)
	ready.disabled = Race.ready_players[Race.local_player]

func _ensure_world() -> void:
	if not is_instance_valid(app.world) or not app.world is RaceWorld or app.world.round_id != Race.config.round:
		app._leave_world()
		app._clear()
		app.screen = "race"
		app.level_index = Race.config.level
		app.difficulty = Race.config.difficulty
		app.backdrop.theme_id = app.level_index
		app.backdrop.tint = RaceProtocol.LEVELS[app.level_index].tint
		var world := RaceWorld.new()
		world.definition = RaceProtocol.LEVELS[app.level_index]
		world.profile = RaceProtocol.PROFILES[app.difficulty]
		world.stars_changed.connect(app._stars_changed)
		world.island_reached.connect(app._island_reached)
		world.powers_changed.connect(app._sync_powers)
		world.artifact_collected.connect(app._artifact_collected)
		app.world = world
		app.add_child(world)
		app._build_hud()
		app.star_label.text = "0 / 10"
		timer_label = app._label(app.stage, "", Rect2(476, 103, 400, 34), 21, app.INK, true)
		opponent_score = app._label(app.stage, "", Rect2(892, 104, 345, 34), 20, Color("8562b8"), true)
		message_label = app._label(app.stage, "", Rect2(350, 533, 580, 68), 23, app.INK, true)
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode = "world"

func _refresh_overlay() -> void:
	app._close_overlay()
	app.pause_overlay = Race.phase != "race"
	if Race.phase == "race": return
	var ui: Control = app._overlay()
	var title: String = {"loading": "Przygotowujemy trasę…", "countdown": "Zaczynamy razem!", "paused": "Wspólna przerwa", "recovering": "Odzyskiwanie połączenia", "results": "Wyniki wyścigu"}.get(Race.phase, "")
	var title_label: Label = app._label(ui, title, Rect2(382, 132, 517, 65), 31, app.INK, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label = app._label(ui, "", Rect2(387, 220, 508, 220), 26, app.INK)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Race.phase == "paused":
		overlay_label.text = "Wyspy i zegar czekają.\nWznawiamy, gdy oboje będziecie gotowi."
		var button: Button = app._button(ui, "Czekamy na rywala…" if Race.ready_players[Race.local_player] else "Gotowy do dalszej gry", Rect2(399, 448, 482, 65), func(): Race.set_ready(), true)
		button.disabled = Race.ready_players[Race.local_player]
	elif Race.phase == "results":
		var award: Dictionary = Race.simulation.awards()
		overlay_label.add_theme_font_size_override("font_size", 21)
		var lines: Array[String] = []
		for id in 2:
			var p: Dictionary = Race.confirmed.players[id]
			var time := "%.2f s" % p.finish if p.finish >= 0.0 else "Nie ukończono"
			lines.append("%s: %s · ★ %d" % ["Ty" if id == Race.local_player else "Rywal", time, p.stars])
		lines.append("\nPierwszy na mecie: " + _award_name(award.race))
		lines.append("Najwięcej gwiazdek: " + _award_name(award.stars))
		overlay_label.text = "\n".join(lines)
		var button: Button = app._button(ui, "Czekamy na rywala…" if Race.ready_players[Race.local_player] else "Rewanż", Rect2(399, 448, 482, 65), func(): Race.set_ready(), true)
		button.disabled = Race.ready_players[Race.local_player]
		var fireworks := AdventureFireworks.new()
		ui.add_child(fireworks)
	app._button(ui, "Opuść grę", Rect2(479, 541, 320, 52), _exit_game)

func _award_name(winners: Array) -> String:
	if winners.is_empty(): return "—"
	if winners.size() == 2: return "remis"
	return "Ty" if winners[0] == Race.local_player else "rywal"

func _process(_delta: float) -> void:
	if closing: return
	# Invitations are bound to a local address. Refresh after a Wi-Fi/hotspot
	# change before admission; an established participant keeps its reservation.
	if Race.hosting and Race.phase == "lobby" and not Race.authenticated and LanPairing.now_ms() - address_check_ms >= 2000:
		address_check_ms = LanPairing.now_ms()
		var addresses: Array[String] = Lan.addresses()
		if not Race.address in addresses:
			Race.leave(false)
			if addresses.size() == 1: _host(addresses[0])
			else: _choose_network()
	if is_instance_valid(overlay_label):
		if Race.phase == "countdown": overlay_label.text = "\n%d" % maxi(1, Race.countdown())
		elif Race.phase == "recovering": overlay_label.text = "Sprawdź Wi-Fi na obu telefonach.\n\nPozostało %d s" % maxi(0, int(ceil(float(Race.recovery_deadline - LanPairing.now_ms()) / 1000)))
	if mode != "world" or Race.confirmed.is_empty() or not is_instance_valid(app.world): return
	if is_instance_valid(app.hint_panel): app.hint_panel.visible = false
	var mine: Dictionary = Race.confirmed.players[Race.local_player]
	var other: Dictionary = Race.confirmed.players[1 - Race.local_player]
	if is_instance_valid(opponent_score): opponent_score.text = "Rywal: ★ %d / 10" % other.stars
	if is_instance_valid(timer_label):
		var seconds := float(Race.presentation_tick()) / 60.0
		timer_label.text = "%02d:%04.1f" % [int(seconds) / 60, fmod(seconds, 60)]
		if Race.confirmed.deadline >= 0.0: timer_label.text += " · zostało %d s" % maxi(0, int(ceil(Race.confirmed.deadline - seconds)))
	if is_instance_valid(message_label): message_label.text = "Jesteś na mecie!\nObserwujesz drugiego gracza." if mine.finish >= 0.0 and Race.phase == "race" else ""
	if is_instance_valid(app.splash_label) and app.world.splash_time >= 0.0:
		app.splash_label.text = "Wracasz za %d…" % maxi(1, int(ceil(3.0 - app.world.splash_time)))
