class_name AdventurePowers
extends RefCounted

signal changed

enum Kind { NONE, WIND, ANCHOR }
const CHARGES := 3
const JUMP_MULTIPLIER := sqrt(2.0)
const WIND_COLOR := Color("858bdd")
const ANCHOR_COLOR := Color("d99b45")

var wind: int = 0
var anchor: int = 0
var armed := false
var anchor_used := false

func reset() -> void:
	wind = 0
	anchor = 0
	armed = false
	anchor_used = false
	changed.emit()

func grant(kind: Kind) -> void:
	if kind == Kind.WIND:
		wind = CHARGES
	elif kind == Kind.ANCHOR:
		anchor = CHARGES
	else:
		return
	changed.emit()

func toggle_wind() -> bool:
	if wind <= 0:
		return false
	armed = not armed
	changed.emit()
	return true

func disarm() -> void:
	if armed:
		armed = false
		changed.emit()

func consume_wind() -> void:
	assert(armed and wind > 0)
	wind -= 1
	armed = false
	changed.emit()

func consume_anchor() -> void:
	assert(anchor > 0 and not anchor_used)
	anchor -= 1
	anchor_used = true
	changed.emit()

func landed() -> void:
	anchor_used = false
	changed.emit()
