class_name SkyBackdrop
extends Node2D

var time: float = 0.0
var scroll: float = 0.0
var theme_id: int = 0
var tint := Color.WHITE
var texture: Texture2D

func _ready() -> void:
	texture = PenguinArt.texture("background")

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, tint)
	for i in 6:
		var x := fposmod(float(i) * 331.0 - scroll * 0.12 + time * 5.0, size.x + 280) - 140.0
		var y := 116.0 + float((i * 73) % 190)
		var c := Color(1.0, 0.98, 0.98, 0.37)
		_cloud_ellipse(Vector2(x, y), Vector2(74, 15), c)
		_cloud_ellipse(Vector2(x - 23, y - 12), Vector2(30, 21), c)
		_cloud_ellipse(Vector2(x + 17, y - 16), Vector2(38, 26), c)
	if theme_id == 2:
		for band in 3:
			var points := PackedVector2Array()
			for x in range(0, int(size.x) + 25, 24):
				points.append(Vector2(x, 95.0 + band * 31 + sin(x * 0.004 + time * 0.15 + band) * 40.0))
			draw_polyline(points, Color(0.61, 1.0, 0.84, 0.11), 27.0, true)
	for row in 4:
		for i in 12:
			var x := fposmod(i * 147.0 - scroll * 0.22 + time * (9.0 + row * 2), size.x + 160.0) - 80.0
			var y := size.y - 56.0 + row * 18 + sin(i + time * 0.7) * 3.0
			draw_line(Vector2(x, y), Vector2(x + 40 + row * 9, y), Color(1, 1, 1, 0.28), 2.0, true)

func _cloud_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radius)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO)
