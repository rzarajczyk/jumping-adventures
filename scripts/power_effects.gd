class_name PowerEffects
extends Node2D

var clock: float = 0.0
var puffs: Array[Dictionary] = []
var bursts: Array[Dictionary] = []
var catches: Array[Dictionary] = []
var anchor_texture: Texture2D

func _ready() -> void:
	z_index = 6
	anchor_texture = PenguinArt.texture("anchor")

func clear() -> void:
	puffs.clear()
	bursts.clear()
	catches.clear()
	clock = 0.0
	queue_redraw()

func puff(at: Vector2, size: float = 16.0) -> void:
	puffs.append({"at": at, "born": clock, "size": size})

func burst(at: Vector2, color: Color) -> void:
	bursts.append({"at": at, "born": clock, "color": color})

func catch_air(at: Vector2, facing: float) -> void:
	catches.append({"at": at, "born": clock, "facing": facing})

func _physics_process(delta: float) -> void:
	clock += delta
	while not puffs.is_empty() and clock - puffs[0].born > 0.65:
		puffs.pop_front()
	while not bursts.is_empty() and clock - bursts[0].born > 0.55:
		bursts.pop_front()
	while not catches.is_empty() and clock - catches[0].born > 0.5:
		catches.pop_front()
	queue_redraw()

func _draw() -> void:
	for p in puffs:
		var age: float = clock - p.born
		var fade := 1.0 - age / 0.65
		var at: Vector2 = p.at + Vector2(-age * 10, age * 25)
		for i in 3:
			draw_circle(at + Vector2((i - 1) * p.size * 0.55, -sin(i * 1.7) * p.size * 0.25), p.size * (0.5 + age), Color(0.91, 0.95, 1, fade * 0.8))
		draw_arc(at, p.size * (0.3 + age), age * 5, age * 5 + PI * 1.4, 20, Color(0.64, 0.70, 0.94, fade), 2, true)
	for b in bursts:
		var age: float = clock - b.born
		var c: Color = b.color
		c.a = 1.0 - age / 0.55
		draw_arc(b.at, 12 + age * 70, 0, TAU, 32, c, 2, true)
		for i in 8:
			var at: Vector2 = b.at + Vector2.from_angle(TAU * i / 8.0) * age * 100
			draw_circle(at, 3 * c.a, c)
	for c in catches:
		var age: float = clock - c.born
		var origin: Vector2 = c.at
		var anchor_at := origin + Vector2(31 * c.facing, 27)
		var fade := clampf(1.0 - (age - 0.20) / 0.30, 0.0, 1.0)
		draw_arc(anchor_at, 10 + age * 80, 0, TAU, 40, Color(0.79, 0.72, 0.94, fade * 0.8), 3, true)
		if age < 0.25:
			var end := origin.lerp(anchor_at, minf(1.0, age / 0.07))
			draw_line(origin + Vector2(0, age * age * 600), end, Color("f6e1ad"), 3, true)
			draw_texture_rect(anchor_texture, Rect2(end - Vector2(12, 0), Vector2(24, 28)), false)
		else:
			for i in 7:
				var at := anchor_at + Vector2.from_angle(TAU * i / 7.0) * (age - 0.25) * 110
				draw_circle(at, 3 * fade, Color(1, 0.80, 0.48, fade))
