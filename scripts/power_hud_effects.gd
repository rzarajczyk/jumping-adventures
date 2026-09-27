class_name PowerHudEffects
extends Node2D

var motes: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func send(at: Vector2, target: Vector2, color: Color) -> void:
	for i in 3:
		motes.append({"from": at, "to": target + Vector2(i * 32, 0), "age": -i * 0.1, "color": color})

func _process(delta: float) -> void:
	for i in range(motes.size() - 1, -1, -1):
		motes[i].age += delta
		if motes[i].age > 0.7:
			motes.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		if mote.age < 0.0:
			continue
		var t: float = clampf(mote.age / 0.7, 0.0, 1.0)
		var at: Vector2 = mote.from.lerp(mote.to, t * t * (3.0 - 2.0 * t)) + Vector2(0, -sin(t * PI) * 85)
		var color: Color = mote.color
		color.a = 0.2
		draw_circle(at, 14, color)
		color.a = 1.0
		draw_circle(at, 6, color)
		draw_circle(at + Vector2(-2, -2), 2, Color("fffdf6"))
