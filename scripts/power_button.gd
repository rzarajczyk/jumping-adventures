class_name PowerButton
extends Button

var charges: int = 0
var available := false
var ui_font: Font
var power_icon: Texture2D

func _ready() -> void:
	text = ""
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	power_icon = PenguinArt.texture("cloud_pack")
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	tooltip_text = "Wybij się pod kątem 60° — także w powietrzu!"

func update_state(count: int, enabled: bool) -> void:
	if charges == count and available == enabled and disabled == not enabled:
		return
	charges = count
	available = enabled
	disabled = not enabled
	queue_redraw()

func _draw() -> void:
	var accent := AdventurePowers.JETPACK_COLOR
	var box := StyleBoxFlat.new()
	box.bg_color = Color("edf1ff") if is_pressed() else Color("fffdf6")
	box.bg_color.a = 0.96 if charges > 0 else 0.8
	box.set_corner_radius_all(22)
	box.set_border_width_all(2 if available else 1)
	box.border_color = accent if available else Color(0.75, 0.80, 0.85, 0.35)
	box.shadow_color = Color(0.19, 0.28, 0.35, 0.10)
	box.shadow_size = 7
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var ink := Color("31485b") if charges > 0 else Color("82949e")
	if power_icon:
		draw_texture_rect(power_icon, Rect2(13, 16, 51, 57), false, Color(1, 1, 1, 1 if charges > 0 else 0.38))
	if ui_font:
		draw_string(ui_font, Vector2(74, 33), "Jetpack", HORIZONTAL_ALIGNMENT_LEFT, 111, 18, ink)
		var status := "Wybij się!" if available else ("Znajdź skarb" if charges == 0 else "Chwila…")
		draw_string(ui_font, Vector2(74, 55), status, HORIZONTAL_ALIGNMENT_LEFT, 112, 14, accent if charges > 0 else ink)
	for i in AdventurePowers.CHARGES:
		var at := Vector2(88 + 32 * i, 83)
		draw_circle(at, 8, accent if i < charges else Color("e2e6e9"))
		draw_arc(at, 8, 0, TAU, 24, accent if i < charges else Color("aebbc4"), 1.5, true)
		if i < charges:
			draw_circle(at + Vector2(-2, -2), 2.3, Color("fffdf6"))
