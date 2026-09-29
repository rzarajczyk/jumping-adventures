class_name RaceActor
extends JumpingPenguin
## Existing character artwork/animation with no independently running physics.
var grounded := true
var correction := Vector2.ZERO
var last_life := -1
var simulation_position := Vector2.ZERO
var correction_remaining := 0.0

func correct(offset: Vector2) -> void:
	if offset.length_squared() < 0.000001: return
	correction = (correction + offset).limit_length(180.0)
	# A 20 Hz snapshot must not restart an existing correction's deadline.
	if correction_remaining <= 0.0: correction_remaining = 0.1

func _ready() -> void:
	super._ready()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape2D: child.disabled = true

func can_jump() -> bool:
	return grounded and state in [State.IDLE, State.AIMING]

func present(p: Dictionary, seconds: float, delta: float, reconcile: bool, snap: bool) -> void:
	if snap or p.life != last_life:
		correction = Vector2.ZERO
		correction_remaining = 0.0
	elif reconcile:
		correct(position - p.position)
	if correction_remaining > 0.0:
		correction *= maxf(0.0, 1.0 - delta / correction_remaining)
		correction_remaining = maxf(0.0, correction_remaining - delta)
	simulation_position = p.position
	position = p.position + correction
	last_life = p.life
	clock = seconds
	velocity = p.velocity
	grounded = p.ground >= 0
	state = State.FALL if p.respawn >= 0 else (State.WON if p.finish >= 0.0 else (State.IDLE if grounded else State.AIR))
	facing = p.facing
	jetpack_flight = p.jetpack_tick >= 0
	jetpack_age = maxf(0.0, seconds - float(p.jetpack_tick) / RaceSimulation.HZ) if jetpack_flight else 10.0
	powers.jetpack = p.jetpack
	squash = -0.20 * maxf(0.0, 1.0 - jetpack_age / 0.15)
	queue_redraw()
