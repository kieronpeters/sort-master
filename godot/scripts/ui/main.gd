extends Control

## M3/M6 minimal playable shell: home, level select, gameplay, win.
## Deliberately plain - polish is deferred (see docs/deferred-work.md).

const PuzzleStateScript = preload("res://scripts/domain/puzzle_state.gd")
const VesselViewScript = preload("res://scripts/ui/vessel_view.gd")
const Board3DScript = preload("res://scripts/presentation/board_3d.gd")
const BackdropScript = preload("res://scripts/ui/backdrop.gd")
const LevelValidatorScript = preload("res://scripts/domain/level_validator.gd")

## Rendering switch. Set to false to fall back to the 2D VesselView board.
const USE_3D := true

# Design space shared with board_3d.gd
const DESIGN_W := 1080.0
const VESSEL_PX_W := 132.0
const GAP_PX := 14.0
const HIT_TOP := 0.14
const HIT_BOTTOM := 0.90

const BG := Color("#0B1F27")
const PANEL := Color("#13272F")
const TEXT := Color("#EAF7FF")
const ACCENT := Color("#46D8D0")
const GOLD := Color("#FFC24B")

var levels: Array = []
var level_index: int = 0
var state = null
var history: Array = []
var selected: int = -1
var moves: int = 0
var unlocked: int = 0

var screen_root: Control
var vessels_row: HBoxContainer
var board_3d: Node3D
var hit_layer: Control
var sub_viewport: SubViewport
var status_label: Label
var header_label: Label
var moves_label: Label
var win_panel: Panel
var win_label: Label
var next_button: Button

func _ready() -> void:
	_load_levels()
	_load_progress()
	_build_ui()
	_show_home()

# ---------- data ----------

func _load_levels() -> void:
	levels.clear()
	var i := 1
	while true:
		var path := "res://levels/level_%d.json" % i
		if not FileAccess.file_exists(path):
			break
		var text := FileAccess.get_file_as_string(path)
		var data = JSON.parse_string(text)
		var problem: String = LevelValidatorScript.validate(data)
		if problem != "":
			push_warning("Rejected level %s: %s" % [path, problem])
			i += 1
			continue
		levels.append(data)
		i += 1
	if levels.is_empty():
		push_warning("No levels found in res://levels/")

func _load_progress() -> void:
	var path := "user://progress.json"
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			unlocked = int(data.get("unlocked", 0))

func _save_progress() -> void:
	var f := FileAccess.open("user://progress.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": unlocked}))
		f.close()

# ---------- ui ----------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var backdrop = BackdropScript.new()
	add_child(backdrop)

	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)

func _clear_screen() -> void:
	for child in screen_root.get_children():
		child.queue_free()
	board_3d = null
	hit_layer = null
	vessels_row = null

func _label(text: String, size: int, colour: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _button(text: String, size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.custom_minimum_size = Vector2(300, 68)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#16323c")
	sb.border_color = Color("#2f6b74")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(12)
	var hover := sb.duplicate()
	hover.bg_color = Color("#1d4450")
	hover.border_color = ACCENT
	var pressed := sb.duplicate()
	pressed.bg_color = Color("#0f242c")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	return b

func _show_home() -> void:
	_clear_screen()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(320, 0)
	center.add_child(box)

	box.add_child(_label("SORT MASTER", 56, GOLD))
	box.add_child(_label("Prism Garden", 28, ACCENT))

	var play := _button("Play")
	play.pressed.connect(_on_play_pressed)
	box.add_child(play)

	var pick := _button("Levels")
	pick.pressed.connect(_show_level_select)
	box.add_child(pick)

func _on_play_pressed() -> void:
	_start_level(min(unlocked, levels.size() - 1))

func _show_level_select() -> void:
	_clear_screen()
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 60
	outer.offset_right = -60
	outer.offset_top = 60
	outer.offset_bottom = -40
	outer.add_theme_constant_override("separation", 18)
	screen_root.add_child(outer)

	outer.add_child(_label("Levels", 40, GOLD))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for i in levels.size():
		var b := Button.new()
		b.text = str(i + 1)
		b.disabled = i > unlocked
		b.custom_minimum_size = Vector2(150, 96)
		b.add_theme_font_size_override("font_size", 30)
		if i == unlocked:
			b.add_theme_color_override("font_color", GOLD)
		var idx: int = i
		b.pressed.connect(func(): _start_level(idx))
		grid.add_child(b)

	var back := _button("Back", 22)
	back.pressed.connect(_show_home)
	outer.add_child(back)

func _start_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	level_index = index
	var data: Dictionary = levels[index]
	state = PuzzleStateScript.new(int(data.get("capacity", 4)), data.get("tubes", []))
	history.clear()
	selected = -1
	moves = 0
	_show_game()

func _show_game() -> void:
	_clear_screen()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	screen_root.add_child(root)

	# header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)

	var back := _button("Back", 20)
	back.custom_minimum_size = Vector2(110, 56)
	back.pressed.connect(_show_home)
	header.add_child(back)

	header_label = _label("Level %d" % (level_index + 1), 26)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_label)

	moves_label = _label("Moves: 0", 22)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	moves_label.custom_minimum_size = Vector2(160, 0)
	header.add_child(moves_label)

	var undo := _button("Undo", 20)
	undo.custom_minimum_size = Vector2(110, 56)
	undo.pressed.connect(_on_undo)
	header.add_child(undo)

	var restart := _button("Restart", 20)
	restart.custom_minimum_size = Vector2(120, 56)
	restart.pressed.connect(_on_restart)
	header.add_child(restart)

	# board
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(holder)

	if USE_3D:
		var svc := SubViewportContainer.new()
		svc.set_anchors_preset(Control.PRESET_FULL_RECT)
		svc.stretch = true
		holder.add_child(svc)

		sub_viewport = SubViewport.new()
		sub_viewport.size = Vector2i(int(DESIGN_W), 820)
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sub_viewport.transparent_bg = false
		svc.add_child(sub_viewport)

		# render at the container's true pixel size: a fixed 1080-wide target was
		# being upscaled and softened the liquid edges and glyphs
		svc.resized.connect(func():
			if sub_viewport != null and svc.size.x > 2 and svc.size.y > 2:
				sub_viewport.size = Vector2i(int(svc.size.x), int(svc.size.y)))

		board_3d = Board3DScript.new()
		sub_viewport.add_child(board_3d)

		# transparent hit areas keep the existing tap semantics
		hit_layer = Control.new()
		hit_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(hit_layer)
		hit_layer.resized.connect(_layout_hits)
	else:
		var board_center := CenterContainer.new()
		board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(board_center)
		vessels_row = HBoxContainer.new()
		vessels_row.add_theme_constant_override("separation", 16)
		vessels_row.alignment = BoxContainer.ALIGNMENT_CENTER
		board_center.add_child(vessels_row)

	# status
	status_label = _label("", 20, ACCENT)
	status_label.custom_minimum_size = Vector2(0, 44)
	root.add_child(status_label)

	_refresh()

func _refresh() -> void:
	if state == null:
		return
	if USE_3D:
		if board_3d != null:
			board_3d.set_board(state.tubes, state.capacity, selected)
		_layout_hits()
	elif vessels_row != null:
		for child in vessels_row.get_children():
			child.queue_free()
		for i in state.tube_count():
			var v = VesselViewScript.new()
			v.custom_minimum_size = Vector2(116, 300)
			v.size = Vector2(116, 300)
			v.setup(i, state.tubes[i], state.capacity)
			v.selected = (i == selected)
			v.tapped.connect(_on_vessel_tapped)
			vessels_row.add_child(v)
	if moves_label:
		moves_label.text = "Moves: %d" % moves

## Positions transparent hit areas over the 3D vessels, using the same design
## space as board_3d.gd so the tap targets line up with what is drawn.
func _layout_hits() -> void:
	if hit_layer == null or state == null:
		return
	for child in hit_layer.get_children():
		child.queue_free()

	var n: int = state.tube_count()
	var w := hit_layer.size.x
	var h := hit_layer.size.y
	if n == 0 or w <= 1.0 or h <= 1.0:
		return

	var total: float = n * VESSEL_PX_W + (n - 1) * GAP_PX
	var start: float = (DESIGN_W - total) * 0.5
	var sx := w / DESIGN_W

	for i in n:
		var hit := Control.new()
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		var centre_x: float = start + i * (VESSEL_PX_W + GAP_PX) + VESSEL_PX_W * 0.5
		var wpx := (VESSEL_PX_W + GAP_PX) * sx
		hit.size = Vector2(wpx, h * (HIT_BOTTOM - HIT_TOP))
		hit.position = Vector2(centre_x * sx - wpx * 0.5, h * HIT_TOP)
		var idx: int = i
		hit.gui_input.connect(func(event): _on_hit_input(event, idx))
		hit_layer.add_child(hit)

func _on_hit_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_vessel_tapped(index)
		accept_event()

func _on_vessel_tapped(index: int) -> void:
	if state == null:
		return
	if selected == -1:
		if state.count_at(index) == 0:
			_status("Pick a tube with liquid in it.")
			return
		selected = index
		_status("Tube %d selected" % (index + 1))
		_refresh()
		return

	if index == selected:
		selected = -1
		_status("")
		_refresh()
		return

	if state.can_move(selected, index):
		history.append(state.clone())
		state.apply_move(selected, index)
		moves += 1
		selected = -1
		_status("")
		_refresh()
		if state.is_won():
			_on_win()
	else:
		if state.count_at(index) > 0 and state.count_at(selected) > 0:
			selected = index
			_status("That pour is not allowed - switching selection.")
			_refresh()
		else:
			_status("That pour is not allowed.")

func _status(text: String) -> void:
	if status_label:
		status_label.text = text

func _on_undo() -> void:
	if history.is_empty():
		_status("Nothing to undo.")
		return
	state = history.pop_back()
	moves = max(0, moves - 1)
	selected = -1
	_status("")
	_refresh()

func _on_restart() -> void:
	_start_level(level_index)

func _on_win() -> void:
	_status("Level complete.")
	if level_index + 1 > unlocked:
		unlocked = level_index + 1
		_save_progress()

	win_panel = Control.new()
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_root.add_child(win_panel)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_panel.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(560, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", sb)
	win_panel.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)

	box.add_child(_label("Level Complete", 46, GOLD))
	box.add_child(_label("Solved in %d moves" % moves, 24))

	if level_index + 1 < levels.size():
		next_button = _button("Next Level")
		next_button.pressed.connect(func():
			win_panel.queue_free()
			_start_level(level_index + 1))
		box.add_child(next_button)
	else:
		box.add_child(_label("That is all 30 levels.", 22, ACCENT))

	var replay := _button("Replay")
	replay.pressed.connect(func():
		win_panel.queue_free()
		_start_level(level_index))
	box.add_child(replay)

	var menu := _button("Levels")
	menu.pressed.connect(func():
		win_panel.queue_free()
		_show_level_select())
	box.add_child(menu)
