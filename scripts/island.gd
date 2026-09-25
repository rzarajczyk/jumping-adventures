class_name SkyIsland
extends AnimatableBody2D

var base_position := Vector2.ZERO
var amplitude := Vector2.ZERO
var period: float = 6.0
var phase: float = 0.0
var width: float = 240.0
var index: int = 0
var goal := false
var art_name := "garden"
var texture: Texture2D
var time: float = 0.0

func configure(data: Dictionary, number: int, art: String) -> void:
	base_position = data.position
	amplitude = data.amplitude
	period = data.period
	phase = data.phase
	width = data.width
	goal = data.goal
	index = number
	art_name = art
	position = position_at(0.0)

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width, 22.0)
	shape.shape = box
	shape.position.y = 11.0
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	add_child(shape)
	texture = PenguinArt.texture(art_name)
	queue_redraw()

func position_at(seconds: float) -> Vector2:
	return base_position + amplitude * sin(TAU * seconds / period + phase)

func advance(seconds: float) -> void:
	time = seconds
	position = position_at(seconds)
	if goal:
		queue_redraw()

func _draw() -> void:
	if texture:
		var h := width * texture.get_height() / texture.get_width()
		draw_texture_rect(texture, Rect2(-width * 0.53, -18.0, width * 1.06, h * 1.06), false)
	# A soft rim marks the exact physical landing surface across every art variant.
	draw_line(Vector2(-width / 2.0 + 7.0, 1), Vector2(width / 2.0 - 7.0, 1), Color("f3fff0"), 5.0, true)
