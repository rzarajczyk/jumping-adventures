class_name AdventureFireworks
extends Control

const COLORS := [Color("ffd77e"), Color("9ee8da"), Color("f5a9be"), Color("bfb3ff"), Color("fff5cf")]
const ORIGINS := [Vector2(135, 182), Vector2(1115, 234), Vector2(228, 498), Vector2(1070, 515), Vector2(610, 48), Vector2(74, 384)]
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	size = Vector2(1280, 720)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	for burst in ORIGINS.size():
		var age := fposmod(time + burst * 0.47, 3.3)
		var origin: Vector2 = ORIGINS[burst]
		var color: Color = COLORS[burst % COLORS.size()]
		if age < 0.38:
			var rocket := origin + Vector2(0, (0.38 - age) * 540)
			draw_line(rocket, rocket + Vector2(0, 35), Color(color, 0.4), 3, true)
			draw_circle(rocket, 4, color)
		elif age < 2.15:
			var t := age - 0.38
			var fade := pow(1.0 - t / 1.77, 1.4)
			for ray in 24:
				var direction := Vector2.from_angle(TAU * ray / 24 + burst * 0.17)
				var speed := 94.0 + float(ray % 3) * 16
				var at := origin + direction * speed * t + Vector2(0, 45 * t * t)
				var trail := at - direction * (8 + 10 * t)
				draw_line(trail, at, Color(color, fade * 0.6), 2.5, true)
				draw_circle(at, 3.4 * fade + 0.5, Color(color, fade))
			if t < 0.22:
				draw_circle(origin, 18 * (1 - t / 0.22), Color(1, 0.98, 0.85, 0.8))
	for i in 36:
		var at := Vector2(fposmod(i * 179.0 + sin(time + i) * 18, 1280), fposmod(time * (24 + i % 5) + i * 71, 760) - 20)
		var color: Color = COLORS[i % COLORS.size()]
		draw_set_transform(at, time * 0.8 + i)
		draw_rect(Rect2(-2, -4, 4, 8), Color(color, 0.75))
	draw_set_transform(Vector2.ZERO)
