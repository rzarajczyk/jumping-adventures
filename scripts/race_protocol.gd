class_name RaceProtocol
extends RefCounted

# Bump whenever simulation or wire rules change. Content fingerprint includes
# every difficulty/layout; build numbers alone must not reject compatible APKs.
const VERSION := 2
const LEVELS := [preload("res://resources/levels/garden.tres"), preload("res://resources/levels/crystal.tres"), preload("res://resources/levels/aurora.tres")]
const PROFILES := [preload("res://resources/difficulties/easy.tres"), preload("res://resources/difficulties/medium.tres"), preload("res://resources/difficulties/hard.tres")]

static func fingerprint() -> String:
	var content: Array = [VERSION, RaceSimulation.HZ, RaceSimulation.GRAVITY, RaceSimulation.MAX_SPEED, RaceSimulation.RESPAWN_TICKS, RaceSimulation.FINISH_TICKS, AdventurePowers.JETPACK_SPEED, AdventurePowers.JETPACK_ANGLE, AdventurePowers.CHARGES]
	for level in LEVELS:
		for profile in PROFILES: content.append(level.layout(profile))
	return var_to_bytes(content).hex_encode().sha256_text()

static func valid_command(c: Dictionary) -> bool:
	for key in ["round", "kind"]:
		if not c.get(key) is String or c[key].length() > 64: return false
	for key in ["epoch", "seq", "tick", "player", "life", "landing", "flight"]:
		if not c.get(key) is int or c[key] < 0 or c[key] > 1000000000: return false
	return c.player < 2 and c.seq > 0 and c.kind in ["jump", "jetpack"] and c.get("vector") is Vector2 and c.vector.is_finite()

static func state_hash(value: Dictionary) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()

static func pack_snapshot(state: Dictionary, decisions: Array, previews: Array) -> PackedByteArray:
	# Repeated field names compress well; keep 20 Hz packets below the LAN MTU
	# so one dropped fragment does not discard an otherwise complete snapshot.
	return var_to_bytes({"state": state, "decisions": decisions, "previews": previews}).compress(FileAccess.COMPRESSION_DEFLATE)

static func unpack_snapshot(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > 8192: return {}
	var raw := packet.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return {}
	var value: Variant = bytes_to_var(raw)
	if not value is Dictionary or not value.get("state") is Dictionary or not value.get("decisions") is Array or not value.get("previews") is Array: return {}
	return value
