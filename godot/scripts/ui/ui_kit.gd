class_name UIKit
extends RefCounted

## Small builders shared by every screen. Keeping button and panel styling in
## one place is what makes the HUD, home and completion card look related.

const P = preload("res://scripts/ui/palette.gd")

static func label(text: String, size: int, colour: Color = P.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

static func eyebrow(text: String, colour: Color = P.MUTED) -> Label:
	return label(text.to_upper(), P.TINY_SIZE, colour)

static func panel_style(bg: Color = P.PANEL, border: Color = P.LINE, width: int = 2, radius: int = 24) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(20)
	sb.anti_aliasing = true
	return sb

static func panel(bg: Color = P.PANEL, border: Color = P.LINE, width: int = 2, radius: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border, width, radius))
	return p

static func _button_style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	sb.anti_aliasing = true
	return sb

static func _style_button(b: Button, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, disabled: StyleBoxFlat, text_colour: Color) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", text_colour)
	b.add_theme_color_override("font_hover_color", text_colour)
	b.add_theme_color_override("font_pressed_color", text_colour)
	b.add_theme_color_override("font_disabled_color", P.DIM)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func primary_button(text: String, font_size: int = 36) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 120)
	_style_button(
		b,
		_button_style(P.ACCENT_DARK, P.ACCENT, 2, 26),
		_button_style(Color("#27A9A4"), P.ACCENT, 2, 26),
		_button_style(Color("#17706E"), P.ACCENT, 2, 26),
		_button_style(P.PANEL_LO, P.LINE, 2, 26),
		P.TEXT
	)
	return b

static func ghost_button(text: String, font_size: int = 32) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, 104)
	_style_button(
		b,
		_button_style(P.PANEL, P.LINE, 2, 24),
		_button_style(P.PANEL_HI, P.ACCENT, 2, 24),
		_button_style(P.PANEL_LO, P.ACCENT, 2, 24),
		_button_style(P.PANEL_LO, P.LINE, 2, 24),
		P.TEXT
	)
	return b

static func text_button(text: String, font_size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", P.MUTED)
	b.add_theme_color_override("font_hover_color", P.TEXT)
	b.add_theme_color_override("font_pressed_color", P.ACCENT)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.flat = true
	return b

static func spacer(height: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func divider() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(P.LINE.r, P.LINE.g, P.LINE.b, 0.55)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
