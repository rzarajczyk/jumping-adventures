class_name JumpGesture
extends RefCounted

const DEAD_ZONE: float = 16.0
const MAX_DRAG: float = 240.0
const MAX_SPEED: float = 850.0
var pointer: int = -99
var origin := Vector2.ZERO
var displacement := Vector2.ZERO

static func launch_vector(delta: Vector2) -> Vector2:
	if delta.length() < DEAD_ZONE or delta.y >= -6.0:
		return Vector2.ZERO
	return delta.limit_length(MAX_DRAG) * (MAX_SPEED / MAX_DRAG)

func begin(id: int, at: Vector2) -> bool:
	if pointer != -99:
		return false
	pointer = id
	origin = at
	displacement = Vector2.ZERO
	return true

func update(id: int, at: Vector2) -> void:
	if id == pointer:
		displacement = at - origin

func finish(id: int, at: Vector2) -> Vector2:
	if id != pointer:
		return Vector2.ZERO
	var result := launch_vector(at - origin)
	cancel()
	return result

func cancel() -> void:
	pointer = -99
	displacement = Vector2.ZERO
