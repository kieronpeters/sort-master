extends Control

## Screen shell for Sort Master — Prism Garden.
##
## Presentation only: every rule decision comes from PuzzleState, and progress
## lives in ProgressStore. Screens are built in code so there is one place to
## change the look, and all of them share Palette / UIKit.

const PuzzleStateScript = preload("res://scripts/domain/puzzle_state.gd")
const ProgressStoreScript = preload("res://scripts/domain/progress_store.gd")
const LevelValidatorScript = preload("res://scripts/domain/level_validator.gd")
const VesselViewScript = preload("res://scripts/ui/vessel_view.gd")
const Board3DScript = preload("res://scripts/presentation/board_3d.gd")
const LayoutScript = preload("res://scripts/presentation/board_layout.gd")
const BackdropScript = preload("res://scripts/ui/backdrop.gd")
const AudioDirectorScript = preload("res://scripts/audio/audio_director.gd")
const EmblemScript = preload("res://scripts/ui/emblem.gd")
const IconButtonScript = preload("res://scripts/ui/icon_button.gd")
const LevelTileScript = preload("res://scripts/ui/level_tile.gd")
const UIKit = preload("res://scripts/ui/ui_kit.gd")
const P = preload("res://scripts/ui/palette.gd")

## Undo history is a session aid, not a log: cap it so a wandering player
## cannot grow memory without bound.
const MAX_HISTORY := 200

## Fallback switch: false renders the old 2D vessel row.
const USE_3D := true

## The M8-06 overlay is a dev-build facility. Release exports carry the
## release_build feature and never contain scripts/debug.
var DEBUG_OVERLAY_AVAILABLE: bool = not OS.has_feature("release_build") and (OS.is_debug_build() or OS.has_feature("dev_build"))
const FADE_TIME := 0.18

const STAGES := [
	[1, "Discovery"],
	[7, "Growing complexity"],
	[16, "Strategy"],
	[19, "Mastery"],
	[25, "Expert"],
]

var levels: Array = []
var level_index := 0
var state = null
var history: Array = []
var selected := -1
var moves := 0
## True while the pour animation owns the board. Input is ignored until the
## vessel is home; the game state has already committed by then.
var _pouring := false
var unlocked := 0
var best: Dictionary = {}
var load_errors: Array = []

var screen_root: Control
var board_3d: Node3D
var hit_layer: Control
var sub_viewport: SubViewport
var vessels_row: HBoxContainer
var status_label: Label
var moves_label: Label
var undo_button: IconButton
var sound_button: IconButton
var win_layer: Control
var modal_layer: Control
var audio: AudioDirector
var debug_overlay = null
var layout: Dictionary = {}

var _screen := "home"
var _debug_visible := false
var _safe := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	_load_levels()
	var data: Dictionary = ProgressStoreScript.load_data()
	best = data.get("best", {})
	unlocked = int(data.get("unlocked", 0))
	# a completed level is always unlocked, even if the save was written by an
	# older build that only advanced one counter
	for key in best.keys():
		var idx := str(key)
		if not idx.is_valid_int() or int(idx) < 0 or int(idx) >= levels.size():
			best.erase(key)
			continue
		unlocked = maxi(unlocked, int(idx))
	unlocked = clampi(unlocked, 0, maxi(0, levels.size() - 1))
	audio = AudioDirectorScript.new()
	audio.muted = bool(data.get("muted", false))
	add_child(audio)
	_refresh_safe_area()
	get_viewport().size_changed.connect(_refresh_safe_area)
	_build_ui()
	_show_home()


# ---------- data ----------

func _load_levels() -> void:
	levels.clear()
	load_errors.clear()
	for i in range(1, 31):
		var path := "res://levels/level_%d.json" % i
		if not FileAccess.file_exists(path):
			load_errors.append("level_%d.json is missing" % i)
			continue
		var text := FileAccess.get_file_as_string(path)
		var data = JSON.parse_string(text)
		var problem: String = LevelValidatorScript.validate(data)
		if problem != "":
			load_errors.append("level_%d.json: %s" % [i, problem])
			continue
		levels.append(data)
	if not load_errors.is_empty():
		push_warning("%d level file(s) rejected: %s" % [load_errors.size(), "; ".join(load_errors)])


func _save_progress() -> void:
	var ok: bool = ProgressStoreScript.save_data({"unlocked": unlocked, "best": best, "muted": audio.muted if audio else false})
	if not ok:
		push_warning("Progress save failed; the session continues in memory.")


func _stage_name(index: int) -> String:
	var level := index + 1
	var name := STAGES[0][1]
	for entry in STAGES:
		if level >= int(entry[0]):
			name = entry[1]
	return str(name)


# ---------- shell ----------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = P.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	add_child(BackdropScript.new())

	screen_root = Control.new()
	screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)


func _clear_screen() -> void:
	for child in screen_root.get_children():
		screen_root.remove_child(child)
		child.queue_free()
	board_3d = null
	hit_layer = null
	sub_viewport = null
	vessels_row = null
	win_layer = null
	modal_layer = null
	debug_overlay = null
	layout = {}
	selected = -1
	moves_label = null
	status_label = null
	undo_button = null
	sound_button = null
	if _toast != null:
		_toast.modulate.a = 0.0


## Insets from the Android safe area, converted to design pixels. Zero on
## desktop and on devices without a cutout.
func _refresh_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var area := DisplayServer.get_display_safe_area()
	if win.x < 1 or win.y < 1 or area.size.x < 1 or area.size.y < 1:
		return
	var k := 1080.0 / float(win.x)
	_safe["top"] = maxf(0.0, float(area.position.y)) * k
	_safe["bottom"] = maxf(0.0, float(win.y - area.position.y - area.size.y)) * k
	_safe["left"] = maxf(0.0, float(area.position.x)) * k
	_safe["right"] = maxf(0.0, float(win.x - area.position.x - area.size.x)) * k


func _page(margin_x: int = 64, margin_top: int = 48, margin_bottom: int = 44) -> MarginContainer:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(page)

	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", margin_x + int(_safe.left))
	m.add_theme_constant_override("margin_right", margin_x + int(_safe.right))
	m.add_theme_constant_override("margin_top", margin_top + int(_safe.top))
	m.add_theme_constant_override("margin_bottom", margin_bottom + int(_safe.bottom))
	page.add_child(m)

	page.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(page, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	return m


func _status(text: String, colour: Color = P.MUTED) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override("font_color", colour)


func _show_toast(text: String, colour: Color = P.GOLD) -> void:
	if _toast == null:
		_toast = UIKit.label("", 26, colour)
		_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_toast.offset_left = 60
		_toast.offset_right = -60
		_toast.offset_top = -220
		_toast.offset_bottom = -170
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toast)
	_toast.text = text
	_toast.add_theme_color_override("font_color", colour)
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)


# ---------- home ----------

func _continue_index() -> int:
	if levels.is_empty():
		return 0
	if best.size() >= levels.size():
		return 0
	for i in levels.size():
		if i <= unlocked and not best.has(str(i)):
			return i
	# every accessible level is restored: replay the highest one
	return mini(unlocked, levels.size() - 1)


func _play_label() -> String:
	if levels.is_empty():
		return "Begin"
	if best.size() >= levels.size():
		return "Play again"
	if unlocked == 0 and best.is_empty():
		return "Begin"
	return "Continue · Level %d" % (_continue_index() + 1)


func _show_home() -> void:
	_screen = "home"
	_clear_screen()
	var m := _page(72, 56, 48)

	var center := CenterContainer.new()
	m.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(780, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var emblem := EmblemScript.new()
	emblem.custom_minimum_size = Vector2(320, 320)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(emblem)

	col.add_child(UIKit.label("S O R T   M A S T E R", 50, P.GOLD))
	col.add_child(UIKit.label("P R I S M   G A R D E N", 26, P.ACCENT))
	col.add_child(UIKit.label("A midnight greenhouse of colours", 25, P.MUTED))
	if not load_errors.is_empty():
		col.add_child(UIKit.label("%d level file(s) could not be loaded." % load_errors.size(), 22, P.PINK))
	col.add_child(UIKit.spacer(26))

	var play := UIKit.primary_button(_play_label())
	play.pressed.connect(_on_play_pressed)
	col.add_child(play)

	var pick := UIKit.ghost_button("Levels")
	pick.pressed.connect(_show_level_select)
	col.add_child(pick)

	col.add_child(UIKit.spacer(10))

	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 22)
	col.add_child(tools)

	var credits := UIKit.text_button("Credits & licences", 23)
	credits.pressed.connect(_show_credits)
	tools.add_child(credits)

	sound_button = IconButtonScript.new("sound_off" if audio.muted else "sound_on", "", 96)
	sound_button.pressed.connect(_toggle_audio)
	tools.add_child(sound_button)

	col.add_child(UIKit.spacer(16))
	var footer := UIKit.label("v%s  ·  offline  ·  no ads" % ProjectSettings.get_setting("application/config/version", "0.1.0"), P.TINY_SIZE, P.DIM)
	col.add_child(footer)


func _on_play_pressed() -> void:
	if levels.is_empty():
		return
	audio.play("ui")
	_start_level(_continue_index())


func _toggle_audio() -> void:
	audio.set_muted(not audio.muted)
	if sound_button != null:
		sound_button.kind = "sound_off" if audio.muted else "sound_on"
		sound_button.queue_redraw()
	_save_progress()
	if not audio.muted:
		audio.play("ui")


# ---------- level select ----------

func _show_level_select() -> void:
	_screen = "levels"
	_clear_screen()
	var m := _page(52, 44, 36)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	m.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	col.add_child(header)

	var back := IconButtonScript.new("back", "", 96)
	back.pressed.connect(_show_home)
	header.add_child(back)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)
	var map_eyebrow := UIKit.eyebrow("THE GARDEN MAP")
	map_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(map_eyebrow)
	var heading := UIKit.label("Levels", 46, P.TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(heading)

	var chip := UIKit.panel(P.PANEL, P.LINE, 2, 18)
	chip.custom_minimum_size = Vector2(170, 76)
	header.add_child(chip)
	var chip_box := VBoxContainer.new()
	chip_box.add_theme_constant_override("separation", 0)
	chip.add_child(chip_box)
	chip_box.add_child(UIKit.label("RESTORED", P.TINY_SIZE - 2, P.MUTED))
	chip_box.add_child(UIKit.label("%d / %d" % [mini(best.size(), levels.size()), levels.size()], 30, P.GOLD))

	if not load_errors.is_empty():
		col.add_child(UIKit.label("%d level file(s) could not be loaded." % load_errors.size(), 22, P.PINK))

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)

	for i in levels.size():
		var tile = LevelTileScript.new(i + 1)
		var tile_state := "locked"
		if best.has(str(i)):
			tile_state = "done"
		elif i <= unlocked:
			tile_state = "open"
		tile.set_tile(tile_state, i == unlocked)
		var idx: int = i
		tile.pressed.connect(func(): _on_level_pressed(idx))
		grid.add_child(tile)

	col.add_child(UIKit.spacer(4))
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 34)
	col.add_child(legend)
	legend.add_child(UIKit.label("●  Restored", 21, P.GOLD))
	legend.add_child(UIKit.label("●  In bloom", 21, P.ACCENT))
	legend.add_child(UIKit.label("●  Locked", 21, P.DIM))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	col.add_child(footer)
	var home := IconButtonScript.new("home", "", 96)
	home.pressed.connect(_show_home)
	footer.add_child(home)
	var hint := UIKit.label("Restore a garden to open the next one.", 24, P.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)


func _on_level_pressed(index: int) -> void:
	if index > unlocked:
		audio.play("invalid")
		_show_toast("Restore level %d first." % index, P.PINK)
		return
	audio.play("ui")
	_start_level(index)


# ---------- credits ----------

func _show_credits() -> void:
	_screen = "credits"
	_clear_screen()
	var m := _page(64, 44, 36)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	m.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	col.add_child(header)
	var back := IconButtonScript.new("back", "", 96)
	back.pressed.connect(_show_home)
	header.add_child(back)
	var heading := UIKit.label("Credits & licences", 42, P.TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	scroll.add_child(body)

	_credits_section(body, "The game",
		"Sort Master — Prism Garden. Designed and built for this project. All 30 levels are solver-verified against the rules-v1 contract.")
	_credits_section(body, "Engine",
		"Godot Engine 4.7.2 — MIT licence. The engine's built-in default font is used for the interface.")
	_credits_section(body, "Artwork",
		"Vessel meshes, liquid symbols, interface icons, the garden backdrop and the application icon are original work generated inside this repository. No third-party artwork is included.")
	_credits_section(body, "Audio",
		"Every sound effect and all three music tracks are synthesised from scratch by the tools in this repository and dedicated to the public domain (CC0 1.0). No sample libraries, purchased audio or licensed music are used anywhere.")
	_credits_section(body, "Privacy",
		"Offline by design. No accounts, no analytics, no advertising, no purchases. Progress is a single local save file.")
	_credits_section(body, "Licence texts",
		"Godot Engine is MIT-licensed and the six sound effects are CC0 1.0. The full licence texts are included with the game under assets/legal.")

	var done := UIKit.ghost_button("Back")
	done.pressed.connect(_show_home)
	col.add_child(done)


func _credits_section(parent: VBoxContainer, title: String, text: String) -> void:
	var panel := UIKit.panel(P.PANEL, P.LINE, 1, 20)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var t := UIKit.label(title, 26, P.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(t)
	var b := UIKit.label(text, 24, P.MUTED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(b)


# ---------- gameplay ----------

func _start_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	if index > unlocked:
		return
	_screen = "game"
	level_index = index
	var data: Dictionary = levels[index]
	state = PuzzleStateScript.new(int(data.get("capacity", 4)), data.get("tubes", []))
	history.clear()
	selected = -1
	moves = 0
	_show_game()


func _show_game() -> void:
	_clear_screen()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root.add_child(root)

	if USE_3D:
		_build_board_layer(root)
	else:
		_build_2d_board(root)

	_build_hud(root)
	_refresh()

	root.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(root, "modulate:a", 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)


func _build_board_layer(parent: Control) -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(svc)

	sub_viewport = SubViewport.new()
	sub_viewport.transparent_bg = false
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sub_viewport)

	board_3d = Board3DScript.new()
	sub_viewport.add_child(board_3d)

	hit_layer = Control.new()
	hit_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hit_layer)
	hit_layer.resized.connect(_layout_hits)


func _build_2d_board(parent: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	vessels_row = HBoxContainer.new()
	vessels_row.add_theme_constant_override("separation", 16)
	vessels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vessels_row)


func _build_hud(parent: Control) -> void:
	var header := MarginContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 40 + int(_safe.left)
	header.offset_right = -40 - int(_safe.right)
	header.offset_top = 30 + int(_safe.top)
	header.offset_bottom = 156 + int(_safe.top)
	parent.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	header.add_child(row)

	var back := IconButtonScript.new("back", "", 96)
	back.pressed.connect(_go_back)
	row.add_child(back)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	row.add_child(titles)
	var eyebrow := UIKit.eyebrow("LEVEL %02d OF %d" % [level_index + 1, levels.size()])
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(eyebrow)
	var stage := UIKit.label(_stage_name(level_index), 36, P.TEXT)
	stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(stage)

	var chip := UIKit.panel(P.PANEL, P.LINE, 2, 20)
	chip.custom_minimum_size = Vector2(146, 76)
	row.add_child(chip)
	var chip_box := VBoxContainer.new()
	chip_box.add_theme_constant_override("separation", 0)
	chip.add_child(chip_box)
	chip_box.add_child(UIKit.label("MOVES", P.TINY_SIZE - 2, P.MUTED))
	moves_label = UIKit.label("0", 36, P.TEXT)
	chip_box.add_child(moves_label)

	status_label = UIKit.label("", 26, P.MUTED)
	status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status_label.offset_left = 50 + int(_safe.left)
	status_label.offset_right = -50 - int(_safe.right)
	status_label.offset_top = -206 - int(_safe.bottom)
	status_label.offset_bottom = -164 - int(_safe.bottom)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(status_label)

	var bottom := MarginContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40 + int(_safe.left)
	bottom.offset_right = -40 - int(_safe.right)
	bottom.offset_top = -158 - int(_safe.bottom)
	bottom.offset_bottom = -26 - int(_safe.bottom)
	parent.add_child(bottom)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	bottom.add_child(bar)

	undo_button = IconButtonScript.new("undo", "Undo", 120)
	undo_button.pressed.connect(_on_undo)
	bar.add_child(undo_button)

	var restart := IconButtonScript.new("restart", "Restart", 120)
	restart.pressed.connect(_on_restart)
	bar.add_child(restart)


func _refresh() -> void:
	if state == null:
		return
	if USE_3D:
		if board_3d != null:
			board_3d.set_board(state.tubes, state.capacity, selected)
		_layout_hits()
	elif vessels_row != null:
		for child in vessels_row.get_children():
			vessels_row.remove_child(child)
			child.queue_free()
		for i in state.tube_count():
			var v = VesselViewScript.new()
			v.custom_minimum_size = Vector2(116, 300)
			v.size = Vector2(116, 300)
			v.setup(i, state.tubes[i], state.capacity)
			v.selected = (i == selected)
			v.tapped.connect(_on_vessel_tapped)
			vessels_row.add_child(v)

	if moves_label != null:
		moves_label.text = str(moves)
	if undo_button != null:
		undo_button.disabled = history.is_empty()
		undo_button.queue_redraw()
	_update_debug()


## Builds the transparent tap strips from the same BoardLayout used by the 3D
## vessels. This is the only place screen space and world space are bridged.
func _layout_hits() -> void:
	if hit_layer == null or state == null:
		return
	for child in hit_layer.get_children():
		hit_layer.remove_child(child)
		child.queue_free()

	var n: int = state.tube_count()
	var vp := hit_layer.size
	if n == 0 or vp.x <= 1.0 or vp.y <= 1.0:
		return

	layout = LayoutScript.compute(n, vp)
	if layout.is_empty():
		return

	var sx: float = layout.scale
	var slot: float = layout.slot
	var top: float = layout.hit_top * sx
	var bottom: float = (layout.baseline + 16.0) * sx
	var centres: Array = layout.centres

	for i in n:
		var hit := Control.new()
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.position = Vector2((centres[i] - slot * 0.5) * sx, top)
		hit.size = Vector2(slot * sx, bottom - top)
		var idx: int = i
		hit.gui_input.connect(func(event): _on_hit_input(event, idx))
		hit_layer.add_child(hit)

	_update_debug()


func _on_hit_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_vessel_tapped(index)


## The pour animation is presentation only, so headless runs (the test suites)
## must not take it: the flow suite asserts the move counter one frame after a tap.
func _animations_on() -> bool:
	return DisplayServer.get_name() != "headless" and board_3d != null


func _on_vessel_tapped(index: int) -> void:
	if state == null or win_layer != null or modal_layer != null or _pouring:
		return

	if selected == -1:
		if state.count_at(index) == 0:
			audio.play("invalid")
			if board_3d != null:
				board_3d.reject(index)
			_status("Pick a tube with liquid in it.", P.PINK)
			return
		selected = index
		audio.play("select")
		_status("")
		_refresh()
		return

	if index == selected:
		selected = -1
		audio.play("ui")
		_status("")
		_refresh()
		return

	if state.can_move(selected, index):
		var from_i: int = selected
		var poured_colour: String = state.top_colour(selected)
		var poured_units: int = state.top_run(selected)
		_push_history()
		state.apply_move_in_place(from_i, index)
		moves += 1
		selected = -1
		audio.play("pour")
		_status("")
		if _animations_on():
			# The board still shows the pre-pour vessels; rebuilding waits until
			# the vessel has finished pouring and returned home.
			_pouring = true
			board_3d.pour(from_i, index, poured_units, poured_colour, func():
				_pouring = false
				_refresh()
				if state != null and state.is_won():
					_on_win())
		else:
			_refresh()
			if state.is_won():
				_on_win()
		return

	var reason := _move_error(selected, index)
	audio.play("invalid")
	if board_3d != null:
		board_3d.reject(index)
	_status(reason, P.PINK)

	# selecting another filled tube is a natural retry; stay selected on it
	if state.count_at(index) > 0:
		selected = index
		_refresh()


func _move_error(from_i: int, to_i: int) -> String:
	if state.count_at(to_i) >= state.capacity:
		return "That tube is full."
	if state.count_at(to_i) > 0 and state.top_colour(from_i) != state.top_colour(to_i):
		return "Colours must match."
	if state.top_run(from_i) > state.capacity - state.count_at(to_i):
		return "Not enough room for that pour."
	return "That pour is not allowed."


func _push_history() -> void:
	history.append(state.clone())
	if history.size() > MAX_HISTORY:
		history.pop_front()


func _on_undo() -> void:
	if _pouring:
		return
	if history.is_empty():
		_status("Nothing to undo.", P.MUTED)
		return
	state = history.pop_back()
	moves = maxi(0, moves - 1)
	selected = -1
	audio.play("undo")
	_status("")
	_refresh()


func _on_restart() -> void:
	if _pouring:
		return
	if history.is_empty():
		_start_level(level_index)
		return
	_confirm_restart()


func _confirm_restart() -> void:
	if modal_layer != null:
		return
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_root.add_child(modal_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.04, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)

	var card := UIKit.panel(P.PANEL, P.LINE, 2, 28)
	card.custom_minimum_size = Vector2(660, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	box.add_child(UIKit.label("Restart level?", 34, P.TEXT))
	box.add_child(UIKit.label("Your %d moves so far will be discarded." % moves, 21, P.MUTED))
	box.add_child(UIKit.spacer(4))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var cancel := UIKit.ghost_button("Keep playing")
	cancel.pressed.connect(func():
		modal_layer.queue_free()
		modal_layer = null)
	buttons.add_child(cancel)
	var confirm := UIKit.primary_button("Restart")
	confirm.pressed.connect(func():
		modal_layer.queue_free()
		modal_layer = null
		_start_level(level_index))
	buttons.add_child(confirm)


# ---------- completion ----------

func _on_win() -> void:
	audio.play("win")
	var key := str(level_index)
	var previous := int(best.get(key, 0))
	var record: bool = previous == 0 or moves < previous
	if record:
		best[key] = moves
	unlocked = maxi(unlocked, mini(level_index + 1, levels.size() - 1))
	_save_progress()
	_status("")
	_show_win_card(record, previous)


func _show_win_card(record: bool, previous: int) -> void:
	var final_level: bool = level_index >= levels.size() - 1

	win_layer = Control.new()
	win_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_root.add_child(win_layer)
	win_layer.modulate.a = 0.0

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.04, 0.48)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# lift the card into the upper half so the solved vessels stay visible
	center.offset_bottom = -600.0
	win_layer.add_child(center)

	# a warm bloom behind the card: the completion beat
	var glow_tex := GradientTexture2D.new()
	var glow_grad := Gradient.new()
	glow_grad.set_color(0, Color(1.0, 0.82, 0.38, 0.34))
	glow_grad.set_color(1, Color(1.0, 0.82, 0.38, 0.0))
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.texture = glow_tex
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.offset_left = -470
	glow.offset_right = 470
	glow.offset_top = -720
	glow.offset_bottom = -180
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	win_layer.add_child(glow)
	var glow_tween := create_tween()
	glow_tween.tween_property(glow, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

	var card := PanelContainer.new()
	var sb := UIKit.panel_style(P.PANEL_HI, P.GOLD, 2, 32)
	sb.set_content_margin_all(44)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 22
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(760, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	card.add_child(box)

	box.add_child(UIKit.eyebrow("LEVEL %02d OF %d" % [level_index + 1, levels.size()], P.ACCENT))
	box.add_child(UIKit.label("Garden Restored" if final_level else "Level Complete", 50, P.GOLD))
	box.add_child(UIKit.label("Solved in %d moves" % moves, 30, P.TEXT))
	if record and previous > 0:
		box.add_child(UIKit.label("New best — previous was %d" % previous, 22, P.ACCENT))
	elif record:
		box.add_child(UIKit.label("First restoration", 24, P.ACCENT))
	elif previous == moves:
		box.add_child(UIKit.label("Matched your best", 24, P.MUTED))
	else:
		box.add_child(UIKit.label("Best remains %d moves" % previous, 24, P.MUTED))

	if final_level:
		box.add_child(UIKit.label("All 30 gardens are in bloom.", 24, P.MUTED))

	box.add_child(UIKit.divider())
	box.add_child(UIKit.spacer(4))

	if not final_level:
		var next := UIKit.primary_button("Next Level")
		next.pressed.connect(func():
			_close_win()
			_start_level(level_index + 1))
		box.add_child(next)
	else:
		var again := UIKit.primary_button("Replay the Garden")
		again.pressed.connect(func():
			_close_win()
			_start_level(0))
		box.add_child(again)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var replay := UIKit.ghost_button("Replay")
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.pressed.connect(func():
		_close_win()
		_start_level(level_index))
	row.add_child(replay)
	var levels_button := UIKit.ghost_button("Levels")
	levels_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_button.pressed.connect(func():
		_close_win()
		_show_level_select())
	row.add_child(levels_button)

	card.scale = Vector2(0.95, 0.95)
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	card.pivot_offset = card.size * 0.5
	var pop := create_tween()
	pop.tween_property(card, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var t := create_tween()
	t.tween_property(win_layer, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)


func _close_win() -> void:
	if win_layer != null:
		win_layer.queue_free()
		win_layer = null


# ---------- debug overlay ----------

func _update_debug() -> void:
	if not DEBUG_OVERLAY_AVAILABLE or not _debug_visible or state == null or layout.is_empty() or hit_layer == null:
		if debug_overlay != null:
			debug_overlay.queue_free()
			debug_overlay = null
		return

	if debug_overlay == null:
		# loaded dynamically so the release export can exclude the folder
		var script = load("res://scripts/debug/debug_overlay.gd")
		if script == null:
			return
		debug_overlay = script.new()
		screen_root.add_child(debug_overlay)

	debug_overlay.setup(layout, state.tubes, selected, moves, level_index + 1, hit_layer.size)


## Android's system back button arrives as a window notification. Without this
## the app would quit mid-level, which is both surprising and loses progress.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	if modal_layer != null:
		modal_layer.queue_free()
		modal_layer = null
		return
	if win_layer != null:
		_close_win()
		_show_level_select()
		return
	match _screen:
		"game":
			if moves > 0:
				_confirm_leave()
			else:
				_show_level_select()
		"levels", "credits":
			_show_home()
		"home":
			if OS.has_feature("mobile"):
				get_tree().quit()


func _confirm_leave() -> void:
	if modal_layer != null:
		return
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	screen_root.add_child(modal_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.04, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)

	var card := UIKit.panel(P.PANEL, P.LINE, 2, 28)
	card.custom_minimum_size = Vector2(660, 0)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	box.add_child(UIKit.label("Leave level?", 36, P.TEXT))
	box.add_child(UIKit.label("Your %d moves will be discarded." % moves, 22, P.MUTED))
	box.add_child(UIKit.spacer(4))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var stay := UIKit.primary_button("Keep playing")
	stay.pressed.connect(func():
		modal_layer.queue_free()
		modal_layer = null)
	buttons.add_child(stay)
	var leave := UIKit.ghost_button("Leave")
	leave.pressed.connect(func():
		modal_layer.queue_free()
		modal_layer = null
		_show_level_select())
	buttons.add_child(leave)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 and DEBUG_OVERLAY_AVAILABLE and _screen == "game":
			_debug_visible = not _debug_visible
			_update_debug()
			return
		if event.keycode == KEY_ESCAPE:
			_go_back()
			return
		if _screen != "game" or win_layer != null or modal_layer != null:
			return
		if event.keycode == KEY_U:
			_on_undo()
		elif event.keycode == KEY_R:
			_on_restart()
