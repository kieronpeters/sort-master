class_name IconButton
extends BaseButton

## A button that draws its own chrome and a vector icon, optionally with a
## label. Used for every control in the game so the interaction states stay
## identical across Home, Levels and the gameplay HUD.

const P = preload("res://scripts/ui/palette.gd")
const Glyphs = preload("res://scripts/ui/icon_glyphs.gd")

var kind := "undo"
var label_text := ""
var diameter := 72.0
var font_size := P.type_size(28)
var tint := P.TEXT
var accent := P.ACCENT


func _init(p_kind := "undo", p_label := "", p_diameter := 72.0) -> void:
	kind = p_kind
	label_text = p_label
	diameter = p_diameter
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if label_text == "":
		custom_minimum_size = Vector2(diameter, diameter)
	else:
		custom_minimum_size = Vector2(0, diameter)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = label_text


func _draw() -> void:
	var mode := get_draw_mode()
	var rect := Rect2(Vector2(1.5, 1.5), size - Vector2(3.0, 3.0))
	var bg := P.PANEL
	var border := Color(P.LINE.r, P.LINE.g, P.LINE.b, 0.9)
	var col := tint

	if mode == BaseButton.DRAW_DISABLED:
		bg = P.PANEL_LO
		border = Color(P.LINE.r, P.LINE.g, P.LINE.b, 0.28)
		col = Color(P.DIM.r, P.DIM.g, P.DIM.b, 0.55)
	elif mode == BaseButton.DRAW_PRESSED:
		bg = P.PANEL_LO
		border = accent
	elif mode == BaseButton.DRAW_HOVER:
		bg = P.PANEL_HI
		border = accent

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(minf(size.y * 0.5, 24.0)))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)

	if label_text == "":
		var s: float = minf(size.x, size.y) * 0.44
		Glyphs.draw(self, kind, Vector2((size.x - s) * 0.5, (size.y - s) * 0.5), s, col)
	else:
		var s: float = minf(size.y * 0.40, 38.0)
		var icon_x: float = 26.0
		Glyphs.draw(self, kind, Vector2(icon_x, (size.y - s) * 0.5), s, col)
		var font := ThemeDB.fallback_font
		var tx: float = icon_x + s + 20.0
		draw_string(font, Vector2(tx, size.y * 0.5 + font_size * 0.35), label_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
