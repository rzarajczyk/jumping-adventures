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
var character_id := "penguin"
var sprite: Texture2D
var blink_sprite: Texture2D
var flying_sprite: Texture2D
var powers: AdventurePowers
var boosted_flight := false
var boost_age: float = 10.0
var pack_texture: Texture2D
var anchor_texture: Texture2D

# Coordinates in the character's facing-right accessory space, before mirroring.
const PACK_OFFSETS := {
	"penguin": Vector2(-29, -5), "whale": Vector2(-6, -21),
	"capybara": Vector2(-27, -6), "kitten": Vector2(-25, -5),
	"puppy": Vector2(-27, -5), "panda": Vector2(-29, -5),
}

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
	sprite = AdventureCharacters.frame(character_id)
	blink_sprite = AdventureCharacters.frame(character_id, "blink")
	flying_sprite = AdventureCharacters.frame(character_id, "fly")
	pack_texture = PenguinArt.texture("cloud_pack")
	anchor_texture = PenguinArt.texture("anchor")
	z_index = 5

func can_jump() -> bool:
	return is_on_floor() and (state == State.IDLE or state == State.AIMING)

func jump(vector: Vector2, boosted: bool = false) -> bool:
	if not can_jump() or vector == Vector2.ZERO:
		return false
	velocity = vector
	boosted_flight = boosted
	boost_age = 0.0 if boosted else 10.0
	state = State.AIR
	aim = Vector2.ZERO
	if absf(vector.x) > 1.0:
		facing = signf(vector.x)
	squash = -0.16
	jumped.emit()
	return true

func stop_flight() -> bool:
	if state != State.AIR:
		return false
	velocity = Vector2.ZERO
	squash = 0.16
	return true

func _physics_process(delta: float) -> void:
	clock += delta
	boost_age += delta
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
			boosted_flight = false
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
	elif flying_sprite and (state == State.WON or (state == State.AIR and (character_id != "penguin" or fmod(clock, 0.24) < 0.12))):
		frame = flying_sprite
	draw_set_transform(Vector2(0, bob - 43), angle, Vector2(facing, 1) * stretch)
	_draw_pack()
	draw_set_transform(Vector2(0, bob - 43), angle, Vector2(facing * (-1 if character_id == "whale" else 1), 1) * stretch)
	var frame_size := Vector2(frame.get_size())
	var bounds := Vector2(108, 92) if character_id == "whale" else Vector2(86, 92)
	frame_size *= minf(bounds.x / frame_size.x, bounds.y / frame_size.y)
	draw_texture_rect(frame, Rect2(Vector2(-frame_size.x * 0.5, 43 - frame_size.y), frame_size), false)
	draw_set_transform(Vector2(0, bob - 43), angle, Vector2(facing, 1) * stretch)
	if powers and powers.anchor > 0 and anchor_texture:
		var charm := Vector2(17, 15) if character_id == "whale" else Vector2(13, 12)
		draw_line(charm + Vector2(0, -12), charm, Color("eee3fb"), 2, true)
		draw_texture_rect(anchor_texture, Rect2(charm - Vector2(8, 0), Vector2(16, 19)), false)
	draw_set_transform(Vector2.ZERO)
	if state == State.AIMING and aim.length() > 0.0:
		var direction := aim.normalized()
		var from := Vector2(0, -56)
		var tip := from + direction * (42.0 + 90.0 * aim.length() / JumpGesture.MAX_SPEED)
		draw_line(from, tip, Color("fffaf0"), 12, true)
		var ink := AdventurePowers.WIND_COLOR if powers and powers.armed else Color("368d89")
		draw_line(from, tip, ink, 7, true)
		var normal := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip + direction * 13, tip - direction * 13 + normal * 12, tip - direction * 13 - normal * 12]), ink)

func _draw_pack() -> void:
	if not powers or not pack_texture or (powers.wind == 0 and boost_age > 0.25):
		return
	var center: Vector2 = PACK_OFFSETS.get(character_id, PACK_OFFSETS.penguin)
	var puff := 1.12 + sin(clock * 18.0) * 0.035 if powers.armed else 1.0
	var pack_size := Vector2(38, 43) * puff
	if boost_age < 0.25:
		pack_size *= 1.0 + 0.18 * sin(boost_age / 0.25 * PI)
	draw_texture_rect(pack_texture, Rect2(center - pack_size * 0.5, pack_size), false)
	if powers.armed:
		for i in 2:
			var at := center + Vector2(-9 + 17 * i, -25 - sin(clock * 18.0 + i) * 2)
			draw_line(at, at + Vector2(2, -4), AdventurePowers.WIND_COLOR, 1.6, true)
