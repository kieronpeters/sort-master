class_name DebugOverlay
extends Control

## Development-only M8-06 aid. Draws tube numbers, the tap strips and a compact
## interaction readout so hit-target drift is visible immediately.
##
## This script is excluded from release-candidate exports and is only created
## when the build is a debug/dev build (see main.gd).

const P = preload("res://scripts/ui/palette.gd")

var layout: Dictionary = {}
var tubes: Array = []
var selected := -1
var moves := 0
var level := 1
var screen_size := Vector2(1080, 1920)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(p_layout: Dictionary, p_tubes: Array, p_selected: int, p_moves: int, p_level: int, p_screen: Vector2) -> void:
	layout = p_layout
	tubes = p_tubes
	selected = p_selected
	moves = p_moves
	level = p_level
	screen_size = p_screen
	queue_redraw()


func _draw() -> void:
	if layout.is_empty():
		return
	var sx: float = float(layout.get("scale", 1.0))
	var slot: float = float(layout.get("slot", 0.0)) * sx
	var hit_top: float = float(layout.get("hit_top", 0.0)) * sx
	var base: float = (float(layout.get("baseline", 0.0)) + 16.0) * sx
	var centres: Array = layout.get("centres", [])
	var font := ThemeDB.fallback_font

	for i in centres.size():
		var left: float = (float(centres[i]) * sx) - slot * 0.5
		var rect := Rect2(left + 2.0, hit_top, slot - 4.0, base - hit_top)
		var colour := Color(1.0, 0.36, 0.48, 0.9)
		if i == selected:
			colour = Color(0.28, 0.95, 0.86, 1.0)
		draw_rect(rect, colour, false, 2.0)
		draw_string(font, Vector2(left + 10.0, hit_top + 26.0), "#%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, colour)
		var top_colour := "-"
		if i < tubes.size() and tubes[i].size() > 0:
			top_colour = str(tubes[i][tubes[i].size() - 1])
		draw_string(font, Vector2(left + 10.0, base - 10.0), "%s x%d" % [top_colour, 0 if i >= tubes.size() else tubes[i].size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.95, 1.0, 0.85))

	var lines := [
		"DEBUG  level %d" % level,
		"moves %d   selected %s" % [moves, "-" if selected < 0 else str(selected + 1)],
		"ppu %.0f  slot %.1f" % [float(layout.get("ppu", 0.0)), slot],
		"tap: tube centres at strip midpoints",
		"F1 hides this overlay",
	]
	var box := Rect2(24, 170, 430, 26 + lines.size() * 26)
	draw_rect(box, Color(0.02, 0.06, 0.08, 0.82), true)
	draw_rect(box, Color(0.28, 0.85, 0.82, 0.8), false, 2.0)
	for i in lines.size():
		draw_string(font, Vector2(40, 202 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.97, 1.0))
