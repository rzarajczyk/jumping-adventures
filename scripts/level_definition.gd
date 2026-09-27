class_name LevelDefinition
extends Resource

@export var id: int = 0
@export var title: String = "Chmurkowy Ogród"
@export var subtitle: String = "Tam, gdzie zaczyna się przygoda"
@export var art: String = "garden"
@export var tint: Color = Color.WHITE
@export var heights: PackedFloat32Array
@export var gaps: PackedFloat32Array
@export var widths: PackedFloat32Array
@export var motion_axes: PackedInt32Array
@export var wind_island: int = 2
@export var anchor_island: int = 4

func layout(profile: DifficultyProfile) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var x: float = 220.0
	for i in heights.size():
		if i > 0:
			x += gaps[i - 1] * profile.spacing
			if i == 1:
				x += 40.0
		var width := profile.island_width * widths[i]
		if i == 0:
			width = 300.0
		elif i == heights.size() - 1:
			width = 280.0
		var moving := i > 2 and i < heights.size() - 1 and i % profile.moving_every == 0
		var axis := Vector2.RIGHT if motion_axes[i] == 0 else Vector2.UP
		result.append({
			"position": Vector2(x, 454.0 + heights[i] * profile.height_scale),
			"width": width,
			"amplitude": axis * profile.movement_amplitude if moving else Vector2.ZERO,
			"period": profile.movement_period + float(i % 3) * 0.45,
			"phase": float(i) * 0.71,
			"star": i > 0 and i % 2 == 1,
			"goal": i == heights.size() - 1,
			"artifact": AdventurePowers.Kind.WIND if i == wind_island else (AdventurePowers.Kind.ANCHOR if i == anchor_island else AdventurePowers.Kind.NONE),
		})
	return result
