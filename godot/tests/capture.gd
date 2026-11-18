extends SceneTree

## Development capture harness: drives the real game scene through its screens
## and writes evidence PNGs. Not part of the game or the release export.
##
## Run (windowed, not headless, so the viewport renders):
##   Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 720x1280 \
##       --script res://tests/capture.gd

const EVIDENCE := "res://../docs/evidence/"

var main: Control
var saves: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	# keep the player's real save untouched
	var path := "user://progress.json"
	if FileAccess.file_exists(path):
		saves[path] = FileAccess.get_file_as_string(path)

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(4)

	main.unlocked = 0
	main.best = {}
	main._show_home()
	await _settle()
	await _shot("rc-home")

	# a realistic map: six restored gardens and level 7 current
	main.unlocked = 6
	main.best = {"0": 3, "1": 6, "2": 6, "3": 7, "4": 7, "5": 8}
	main._show_home()
	await _settle()
	await _shot("rc-levels")

	main._show_credits()
	await _settle()
	await _shot("rc-credits")

	main._show_settings()
	await _settle()
	await _shot("rc-settings")

	main.unlocked = 6
	main._start_level(1)
	await _settle()
	await _shot("rc-gameplay")

	main._on_vessel_tapped(0)
	await _settle()
	await _shot("rc-selected")

	# clear the selection, then play the first move of level 2's verified solution
	main._on_vessel_tapped(0)
	await _frames(2)
	var solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	var first: Dictionary = solutions["level_2"]["moves"][0]
	main._on_vessel_tapped(int(first["from"]))
	await _frames(2)
	main._on_vessel_tapped(int(first["to"]))
	# Catch the pour mid-flight: the source tilt, the stream and the liquid
	# rising in the destination all happen inside ~0.3 s.
	await _frames(6)
	await _shot("rc-pour-early")
	await _frames(14)
	await _shot("rc-pour-mid")
	await _frames(16)
	await _shot("rc-pour-late")
	await _wait_pour()
	await _settle()
	await _shot("rc-transfer")

	main._on_undo()
	await _settle()
	await _shot("rc-undo")

	# complete level 2 for the completion card
	await _solve(1, solutions)
	await _settle()
	await _shot("rc-complete")

	# dense board with the development overlay
	main.unlocked = 29
	main._start_level(5)
	main._debug_visible = true
	await _frames(6)
	main._refresh()
	await _settle()
	await _shot("rc-debug")

	main._debug_visible = false
	main.unlocked = 29
	main._start_level(29)
	await _frames(4)
	await _solve(29, solutions)
	await _settle()
	await _shot("rc-final")

	# restore the player's save
	if saves.has(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(String(saves[path]))
		f.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("capture complete")
	quit()


func _solve(level_index: int, solutions: Dictionary) -> void:
	var key := "level_%d" % (level_index + 1)
	if not solutions.has(key):
		return
	for move in solutions[key]["moves"]:
		main._on_vessel_tapped(int(move["from"]))
		await _frames(1)
		main._on_vessel_tapped(int(move["to"]))
		# input is locked while the vessel is pouring, so wait for it to finish
		await _wait_pour()
		await _frames(1)


func _wait_pour() -> void:
	var guard := 0
	while main._pouring and guard < 400:
		await process_frame
		guard += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle() -> void:
	await create_timer(0.40).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(EVIDENCE + name + ".png")
	print("shot ", name, "  ", img.get_size())
