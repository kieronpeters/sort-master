class_name LevelTile
extends BaseButton

## One level in the garden map. Locked, open, completed and current states are
## all drawn here so the grid can never drift out of sync with progress data.

const P = preload("res://scripts/ui/palette.gd")
const Glyphs = preload("res://scripts/ui/icon_glyphs.gd")

var number := 1
var tile_state := "locked"   # locked | open | done
var current := false


func _init(p_number := 1) -> void:
	number = p_number
	custom_minimum_size = Vector2(176, 176)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_tile(p_state: String, p_current: bool) -> void:
	tile_state = p_state
	current = p_current
	queue_redraw()


func _draw() -> void:
	var mode := get_draw_mode()
	var rect := Rect2(Vector2(1.5, 1.5), size - Vector2(3.0, 3.0))

	if current:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(P.ACCENT.r, P.ACCENT.g, P.ACCENT.b, 0.10)
		glow.border_color = Color(P.ACCENT.r, P.ACCENT.g, P.ACCENT.b, 0.28)
		glow.set_border_width_all(2)
		glow.set_corner_radius_all(26)
		draw_style_box(glow, rect.grow(6.0))

	var bg := P.PANEL
	var border := P.LINE
	var border_w := 2
	var ink := P.TEXT

	match tile_state:
		"locked":
			bg = P.PANEL_LO
			border = Color(P.LINE.r, P.LINE.g, P.LINE.b, 0.35)
			border_w = 1
			ink = Color(P.DIM.r, P.DIM.g, P.DIM.b, 0.75)
		"done":
			bg = P.PANEL_HI
			border = Color(P.GOLD.r, P.GOLD.g, P.GOLD.b, 0.65)
			ink = P.TEXT
		"open":
			bg = P.PANEL
			border = P.ACCENT if current else P.LINE
			ink = P.ACCENT if current else P.TEXT

	if mode == BaseButton.DRAW_HOVER and tile_state != "locked":
		bg = P.PANEL_HI
		border = P.ACCENT
	elif mode == BaseButton.DRAW_PRESSED and tile_state != "locked":
		bg = P.PANEL_LO
		border = P.ACCENT

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(22)
	sb.anti_aliasing = true
	draw_style_box(sb, rect)

	var font := ThemeDB.fallback_font
	var font_size := 48 if number < 10 else 42
	var baseline: float = size.y * 0.5 + font_size * 0.35
	if tile_state == "done":
		baseline -= 8.0
	draw_string(font, Vector2(0, baseline), str(number), HORIZONTAL_ALIGNMENT_CENTER,
		size.x, font_size, ink)

	if tile_state == "done":
		Glyphs.draw(self, "check", Vector2(size.x * 0.62, size.y * 0.62), size.x * 0.24, P.GOLD)
	elif tile_state == "locked":
		Glyphs.draw(self, "lock", Vector2(size.x * 0.36, size.y * 0.60), size.x * 0.28, Color(P.DIM.r, P.DIM.g, P.DIM.b, 0.7))
