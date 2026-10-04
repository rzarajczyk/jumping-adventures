class_name CharacterScroll
extends ScrollContainer

var pointer := -1
var touch_origin := Vector2.ZERO
var scroll_origin := 0
var dragging := false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# The game disables mouse emulation from touch. Handle screen gestures directly,
	# while leaving taps, the mouse wheel and the scrollbar to Godot's controls.
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			if Rect2(Vector2.ZERO, size).has_point(local):
				if pointer != -1:
					get_viewport().set_input_as_handled()
					return
				pointer = event.index
				touch_origin = local
				scroll_origin = scroll_horizontal
				dragging = false
		elif event.index == pointer:
			if event.canceled and not dragging:
				propagate_notification(NOTIFICATION_SCROLL_BEGIN)
			if dragging or event.canceled:
				propagate_notification(NOTIFICATION_SCROLL_END)
			pointer = -1
			dragging = false
	elif event is InputEventScreenDrag and pointer != -1:
		if event.index == pointer:
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			var movement := touch_origin - local
			if not dragging and movement.length() > scroll_deadzone:
				dragging = true
				# Cancel any held card before its release can choose a character.
				propagate_notification(NOTIFICATION_SCROLL_BEGIN)
			if dragging:
				scroll_horizontal = scroll_origin + roundi(movement.x)
				get_viewport().set_input_as_handled()
		else:
			get_viewport().set_input_as_handled()
