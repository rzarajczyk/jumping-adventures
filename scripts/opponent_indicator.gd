class_name OpponentIndicator
extends Control

var world: Node2D
var shown := false
var target := Vector2.ZERO
var respawn_seconds := 0
var stale := false
var character := "penguin"
var color := Color("9b75cc")
var ui_font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_target(at: Vector2, seconds: int, connection_stale: bool) -> void:
	target = world.get_canvas_transform() * at
	respawn_seconds = seconds
	stale = connection_stale
	var visible_area := get_viewport_rect()
	if shown:
		if visible_area.grow(-24).has_point(target): shown = false
	elif not visible_area.has_point(target): shown = true
	queue_redraw()

func _draw() -> void:
	if not shown and respawn_seconds == 0 and not stale: return
	var bounds := get_viewport_rect().grow(-70)
	bounds.position.y += 65
	bounds.size.y -= 155
	if OS.get_name() == "Android":
		var screen := Vector2(DisplayServer.screen_get_size())
		if screen.x > 0.0 and screen.y > 0.0:
			var safe := Rect2(DisplayServer.get_display_safe_area())
			var factor := get_viewport_rect().size / screen
			bounds = bounds.intersection(Rect2(safe.position * factor, safe.size * factor).grow(-35))
	var origin := bounds.get_center()
	var direction := (target - origin).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var extent := bounds.size * 0.5
	var distance := minf(extent.x / maxf(absf(direction.x), 0.001), extent.y / maxf(absf(direction.y), 0.001))
	var at := origin + direction * distance if shown else target.clamp(bounds.position, bounds.end)
	draw_circle(at, 29, Color(1, 0.99, 0.96, 0.96))
	draw_arc(at, 29, 0, TAU, 32, color, 3, true)
	draw_texture_rect(AdventureCharacters.frame(character), Rect2(at - Vector2(21, 23), Vector2(42, 46)), false)
	if shown:
		var tip := at + direction * 43
		var side := direction.orthogonal() * 9
		draw_colored_polygon(PackedVector2Array([tip + direction * 11, tip - direction * 7 + side, tip - direction * 7 - side]), color)
	if ui_font and (respawn_seconds > 0 or stale):
		var text := "%d s" % respawn_seconds if respawn_seconds > 0 else "Łączenie…"
		draw_string(ui_font, at + Vector2(-46, 51), text, HORIZONTAL_ALIGNMENT_CENTER, 92, 18, Color("31485b"))
