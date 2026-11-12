extends Control

## Draws one vessel and its liquid. Pure view: it never owns state.

signal tapped(index: int)

var index: int = 0
var contents: Array = []
var capacity: int = 4
var selected: bool = false

const GLASS_FILL := Color("#16303a")
const GLASS_EDGE := Color("#9fd9e6")
const GLASS_EDGE_SELECTED := Color("#ffd76a")

const COLOURS := {
	"A": Color("#FFC24B"),   # amber
	"B": Color("#46D8D0"),   # aqua
	"C": Color("#2FA45F"),   # emerald
	"D": Color("#4D7BF1"),   # sapphire
	"E": Color("#D0A2FF"),   # violet
	"F": Color("#F87AA7"),   # rose
}

func setup(p_index: int, p_contents: Array, p_capacity: int) -> void:
	index = p_index
	contents = p_contents.duplicate()
	capacity = p_capacity
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var body_w := w * 0.62
	var x := (w - body_w) * 0.5
	var neck_h := h * 0.10
	var body_y := neck_h
	var body_h := h - neck_h - 4.0

	# glass body
	var body := Rect2(x, body_y, body_w, body_h)
	draw_rect(body, GLASS_FILL, true)
	var edge := GLASS_EDGE_SELECTED if selected else GLASS_EDGE
	draw_rect(body, edge, false, 3.0)

	# neck
	var neck_w := body_w * 0.52
	draw_rect(Rect2((w - neck_w) * 0.5, 0.0, neck_w, neck_h + 2.0), GLASS_FILL, true)
	draw_rect(Rect2((w - neck_w) * 0.5, 0.0, neck_w, neck_h + 2.0), edge, false, 3.0)

	# liquid, bottom up
	var unit_h := body_h / float(capacity)
	for i in contents.size():
		var colour: String = contents[i]
		var c: Color = COLOURS.get(colour, Color.MAGENTA)
		var y := body_y + body_h - unit_h * (i + 1)
		draw_rect(Rect2(x + 4.0, y, body_w - 8.0, unit_h), c, true)

	# meniscus highlight on the top unit
	if contents.size() > 0:
		var top_y := body_y + body_h - unit_h * contents.size()
		draw_line(Vector2(x + 4.0, top_y), Vector2(x + body_w - 4.0, top_y), Color(1, 1, 1, 0.35), 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tapped.emit(index)
		accept_event()
