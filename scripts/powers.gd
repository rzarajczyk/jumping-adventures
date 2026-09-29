class_name AdventurePowers
extends RefCounted

signal changed

enum Kind { NONE, JETPACK }
const CHARGES := 3
const JETPACK_SPEED := JumpGesture.MAX_SPEED * 0.5
const JETPACK_ANGLE := PI / 3.0
const JETPACK_DURATION := 0.45
const JETPACK_COLOR := Color("858bdd")

var jetpack: int = 0

static func launch_vector(facing: float) -> Vector2:
	return Vector2(cos(JETPACK_ANGLE) * (-1.0 if facing < 0.0 else 1.0), -sin(JETPACK_ANGLE)) * JETPACK_SPEED

func reset() -> void:
	jetpack = 0
	changed.emit()

func grant(kind: Kind) -> void:
	if kind != Kind.JETPACK:
		return
	jetpack = CHARGES
	changed.emit()

func consume_jetpack() -> void:
	assert(jetpack > 0)
	jetpack -= 1
	changed.emit()
