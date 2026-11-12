extends Control

## M3/M6 minimal playable shell: home, level select, gameplay, win.
## Deliberately plain - polish is deferred (see docs/deferred-work.md).

const PuzzleStateScript = preload("res://scripts/domain/puzzle_state.gd")
const VesselViewScript = preload("res://scripts/ui/vessel_view.gd")

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
	for i in range(1, 6):
		var path := "res://levels/level_%d.json" % i
		if not FileAccess.file_exists(path):
			push_warning("Missing level: " + path)
			continue
		var text := FileAccess.get_file_as_string(path)
		var data = JSON.parse_string(text)
		if data == null or not (data is Dictionary):
			push_warning("Invalid level JSON: " + path)
			continue
		levels.append(data)

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

	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen_root)

func _clear_screen() -> void:
	for child in screen_root.get_children():
		child.queue_free()

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
	b.custom_minimum_size = Vector2(300, 64)
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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(320, 0)
	center.add_child(box)

	box.add_child(_label("Levels", 40, GOLD))
	for i in levels.size():
		var b := _button("Level %d%s" % [i + 1, "" if i <= unlocked else "  (locked)"], 24)
		b.disabled = i > unlocked
		var idx := i
		b.pressed.connect(func(): _start_level(idx))
		box.add_child(b)

	var back := _button("Back", 22)
	back.pressed.connect(_show_home)
	box.add_child(back)

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
	if vessels_row == null or state == null:
		return
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

func _on_vessel_tapped(index: int) -> void:
	if state == null:
		return
	if selected == -1:
		if state.count_at(index) == 0:
			_status("Pick a tube with liquid in it.")
			return
		selected = index
		_refresh()
		return

	if index == selected:
		selected = -1
		_refresh()
		return

	if state.can_move(selected, index):
		history.append(state.clone())
		state.apply_move(selected, index)
		moves += 1
		selected = -1
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

	win_panel = Panel.new()
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.modulate = Color(0, 0, 0, 0.75)
	screen_root.add_child(win_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(340, 0)
	center.add_child(box)

	box.add_child(_label("Level Complete", 46, GOLD))
	box.add_child(_label("Solved in %d moves" % moves, 24))

	if level_index + 1 < levels.size():
		next_button = _button("Next Level")
		next_button.pressed.connect(func():
			win_panel.queue_free()
			_start_level(level_index + 1))
		box.add_child(next_button)
	else:
		box.add_child(_label("That is all five levels.", 22, ACCENT))

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
