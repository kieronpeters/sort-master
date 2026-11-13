extends SceneTree

## Integration test: drives the real game screens through all 30 levels using
## the solver's verified move lists. This exercises selection, transfer, move
## counting, win detection, progression, best-move recording and undo through
## the same code paths the player touches (minus mouse hit-testing).
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot \
##       --script res://tests/test_flow.gd

var passed := 0
var failed := 0
var main: Control
var save_backup = null
var save_path := "user://progress.json"


func check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", name)


func _initialize() -> void:
	_run()


func _run() -> void:
	if FileAccess.file_exists(save_path):
		save_backup = FileAccess.get_file_as_string(save_path)

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	check("30 levels loaded", main.levels.size() == 30)
	if main.levels.size() != 30:
		_finish()
		return

	var solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	check("solutions parse", solutions is Dictionary)

	var all_solved := true
	for i in main.levels.size():
		main.unlocked = i
		main._start_level(i)
		await process_frame

		var key := "level_%d" % (i + 1)
		var expected: int = int(solutions[key]["moves"].size())
		for move in solutions[key]["moves"]:
			main._on_vessel_tapped(int(move["from"]))
			main._on_vessel_tapped(int(move["to"]))
		await process_frame

		var won: bool = main.state.is_won()
		if not won:
			all_solved = false
		check("%s completes through the game" % key, won)
		check("%s move count is %d" % [key, expected], main.moves == expected)
		check("%s records a best" % key, main.best.has(str(i)))
		check("%s win card shown" % key, main.win_layer != null)
		main._close_win()

	check("every level completes", all_solved)
	check("all 30 bests recorded", main.best.size() == 30)
	check("progression reached the last level", main.unlocked == 29)
	check("save file written", FileAccess.file_exists(save_path))

	var stored: Dictionary = load("res://scripts/domain/progress_store.gd").load_data()
	check("save holds all bests", stored.best.size() == 30)
	check("save holds the unlocked level", int(stored.unlocked) == 29)

	# --- undo restores the exact board, not just the move count -----------
	main._start_level(1)
	await process_frame
	var before: String = main.state.signature()
	var first: Dictionary = solutions["level_2"]["moves"][0]
	main._on_vessel_tapped(int(first["from"]))
	main._on_vessel_tapped(int(first["to"]))
	check("a move changes the board", main.state.signature() != before)
	check("a move increments the counter", main.moves == 1)
	main._on_undo()
	check("undo restores the board", main.state.signature() == before)
	check("undo restores the counter", main.moves == 0)
	main._on_undo()
	check("undo at the start is harmless", main.state.signature() == before)

	# --- restart asks before discarding moves -----------------------------
	main._on_vessel_tapped(int(first["from"]))
	main._on_vessel_tapped(int(first["to"]))
	main._on_restart()
	check("restart asks for confirmation", main.modal_layer != null)
	if main.modal_layer != null:
		main.modal_layer.queue_free()
		main.modal_layer = null

	# --- invalid input ----------------------------------------------------
	main._start_level(1)
	await process_frame
	var empty_tube := -1
	for t in main.state.tube_count():
		if main.state.count_at(t) == 0:
			empty_tube = t
			break
	check("fixture has an empty tube", empty_tube >= 0)
	main._on_vessel_tapped(empty_tube)
	check("empty tube cannot be selected", main.selected == -1)

	_finish()


func _finish() -> void:
	if save_backup != null:
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		f.store_string(String(save_backup))
		f.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	print("")
	print("FLOW PASSED: ", passed, "  FAILED: ", failed)
	quit(0 if failed == 0 else 1)
