class_name JumpingPenguin
extends CharacterBody2D

signal landed(island: SkyIsland)
signal jumped
const GRAVITY: float = 1200.0
enum State { IDLE, AIMING, AIR, FALL, WON }
var state: State = State.AIR
var aim := Vector2.ZERO
var clock: float = 0.0
var squash: float = 0.0
var facing: float = 1.0
var last_island: SkyIsland
var sprite: Texture2D
var blink_sprite: Texture2D
var flying_sprite: Texture2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	platform_floor_layers = 1
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	floor_snap_length = 8.0
	floor_stop_on_slope = true
	safe_margin = 0.05
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 17.0
	capsule.height = 68.0
	shape.shape = capsule
	shape.position = Vector2(0, -34)
	add_child(shape)
	sprite = PenguinArt.texture("penguin")
	blink_sprite = PenguinArt.texture("penguin_blink")
	flying_sprite = PenguinArt.texture("penguin_fly")
	z_index = 5

func can_jump() -> bool:
	return is_on_floor() and (state == State.IDLE or state == State.AIMING)

func jump(vector: Vector2) -> bool:
	if not can_jump() or vector == Vector2.ZERO:
		return false
	velocity = vector
	state = State.AIR
	aim = Vector2.ZERO
	if absf(vector.x) > 1.0:
		facing = signf(vector.x)
	squash = -0.16
	jumped.emit()
	return true

func _physics_process(delta: float) -> void:
	clock += delta
	squash = move_toward(squash, 0.0, delta * 1.5)
	if state == State.FALL or state == State.WON:
		queue_redraw()
		return
	var was_air := state == State.AIR
	if state == State.IDLE or state == State.AIMING:
		velocity = Vector2.ZERO
	velocity.y += GRAVITY * delta
	move_and_slide()
	if is_on_floor():
		velocity = Vector2.ZERO
		if was_air:
			state = State.IDLE
			squash = 0.20
			for i in get_slide_collision_count():
				var hit := get_slide_collision(i)
				if hit.get_normal().y < -0.7 and hit.get_collider() is SkyIsland:
					last_island = hit.get_collider()
					landed.emit(last_island)
					break
	else:
		state = State.AIR
	queue_redraw()

func _draw() -> void:
	if not sprite or state == State.FALL:
		return
	var bob := sin(clock * 2.8) * 1.5
	var angle: float = 0.0
	var stretch := Vector2(1.0 + squash, 1.0 - squash)
	if state == State.AIMING:
		stretch = Vector2(1.10, 0.9)
	elif state == State.AIR:
		angle = clampf(velocity.y / 3500.0, -0.18, 0.20) * facing
		bob = sin(clock * 23.0) * 2.0
	elif state == State.WON:
		bob = -absf(sin(clock * 6.0)) * 20.0
		angle = sin(clock * 6.0) * 0.12
	var frame := sprite
	if blink_sprite and fmod(clock, 4.1) < 0.12 and state != State.AIR:
		frame = blink_sprite
	elif flying_sprite and state == State.AIR and fmod(clock, 0.24) < 0.12:
		frame = flying_sprite
	draw_set_transform(Vector2(0, bob - 43), angle, Vector2(facing, 1) * stretch)
	draw_texture_rect(frame, Rect2(-40, -49, 80, 92), false)
	draw_set_transform(Vector2.ZERO)
	if state == State.AIMING and aim.length() > 0.0:
		var direction := aim.normalized()
		var from := Vector2(0, -56)
		var tip := from + direction * (42.0 + 90.0 * aim.length() / JumpGesture.MAX_SPEED)
		draw_line(from, tip, Color("fffaf0"), 12, true)
		draw_line(from, tip, Color("368d89"), 7, true)
		var normal := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip + direction * 13, tip - direction * 13 + normal * 12, tip - direction * 13 - normal * 12]), Color("368d89"))
