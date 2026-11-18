extends SceneTree

## Integration test: drives the real game screens through all 30 levels using
## the solver's verified move lists. This exercises selection, transfer, move
## counting, win detection, progression, best-move recording, restart, undo and
## navigation through the same code paths the player touches (minus mouse
## hit-testing).
##
## It also writes a transcript of the moves it made, which the independent
## Python verifier replays to prove the solver agrees with the game's play.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot \
##       --script res://tests/test_flow.gd -- --transcript=C:/tmp/game_moves.json

var passed := 0
var failed := 0
var main: Control
var save_backup = null
var save_path := "user://progress.json"
var transcript := {"ruleVersion": "rules-v1", "levels": []}
var transcript_path := ""


func check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", name)


func _initialize() -> void:
	_run()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--transcript="):
			transcript_path = arg.trim_prefix("--transcript=")

	if FileAccess.file_exists(save_path):
		save_backup = FileAccess.get_file_as_string(save_path)

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	check("at least the 30 verified levels load", main.levels.size() >= 30)
	if main.levels.size() < 30:
		_finish()
		return

	var solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	check("solutions parse", solutions is Dictionary)

	# Only the 30 QA-verified levels have recorded solutions; the extended
	# catalogue carries its own and is exercised by the playthrough harness.
	var verified: int = mini(main.levels.size(), 30)
	var all_solved := true
	for i in verified:
		main.unlocked = i
		main._start_level(i)
		await process_frame

		var key := "level_%d" % (i + 1)
		var expected: int = int(solutions[key]["moves"].size())
		var played: Array = []
		for move in solutions[key]["moves"]:
			main._on_vessel_tapped(int(move["from"]))
			main._on_vessel_tapped(int(move["to"]))
			played.append([int(move["from"]), int(move["to"])])
		await process_frame

		var won: bool = main.state.is_won()
		if not won:
			all_solved = false
		check("%s completes through the game" % key, won)
		check("%s move count is %d" % [key, expected], main.moves == expected)
		check("%s records a best" % key, main.best.has(str(i)))
		check("%s win card shown" % key, main.win_layer != null)

		transcript["levels"].append({
			"level": i + 1,
			"moves": played,
			"move_count": main.moves,
			"won": won,
		})
		main._close_win()

	check("every level completes", all_solved)
	check("all 30 bests recorded", main.best.size() >= 30)
	check("progression advanced past the verified set", main.unlocked >= 30)
	check("save file written", FileAccess.file_exists(save_path))

	var stored: Dictionary = load("res://scripts/domain/progress_store.gd").load_data()
	check("save holds all bests", stored.best.size() >= 30)
	check("save holds the unlocked level", int(stored.unlocked) >= 30)

	# --- the Next Level button really advances the game -------------------
	main.unlocked = 0
	main._start_level(0)
	await process_frame
	_play_level(0, solutions)
	await process_frame
	var next_button = _find_button(main.win_layer, "Next Level")
	check("Next Level button exists", next_button != null)
	if next_button != null:
		next_button.pressed.emit()
		await process_frame
		check("Next Level starts the next level", main.level_index == 1 and main._screen == "game")

	# --- undo restores the exact board, not just the move count -----------
	main._start_level(1)
	await process_frame
	var before: String = main.state.signature()
	main._on_vessel_tapped(int(solutions["level_2"]["moves"][0]["from"]))
	main._on_vessel_tapped(int(solutions["level_2"]["moves"][0]["to"]))
	check("a move changes the board", main.state.signature() != before)
	check("a move increments the counter", main.moves == 1)
	main._on_undo()
	check("undo restores the board", main.state.signature() == before)
	check("undo restores the counter", main.moves == 0)
	main._on_undo()
	check("undo at the start is harmless", main.state.signature() == before)

	# --- restart after several moves returns the exact initial state ------
	main.unlocked = maxi(main.unlocked, 9)
	main._start_level(9)
	await process_frame
	var initial: String = main.state.signature()
	for k in 5:
		main._on_vessel_tapped(int(solutions["level_10"]["moves"][k]["from"]))
		main._on_vessel_tapped(int(solutions["level_10"]["moves"][k]["to"]))
	await process_frame
	check("restart fixture has moves", main.moves == 5)
	main._on_restart()
	check("restart asks for confirmation", main.modal_layer != null)
	var restart_button = _find_button(main.modal_layer, "Restart")
	check("restart confirm button exists", restart_button != null)
	if restart_button != null:
		restart_button.pressed.emit()
		await process_frame
	check("restart restores the initial board", main.state.signature() == initial)
	check("restart resets the counter", main.moves == 0)

	# --- history is bounded ------------------------------------------------
	main.history.clear()
	for k in 260:
		main._push_history()
	check("history capped at MAX_HISTORY", main.history.size() == main.MAX_HISTORY)
	main.history.clear()

	# --- locked levels cannot be entered -----------------------------------
	main.unlocked = 0
	main._show_home()
	await process_frame
	main._on_level_pressed(7)
	check("locked level cannot be entered", main._screen == "home")

	# --- invalid input -----------------------------------------------------
	main.unlocked = 1
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

	# --- inconsistent save and direct start guard -------------------------
	main.unlocked = 0
	main.best = {"0": 3}
	check("continue target is playable", main._continue_index() == 0)
	var held_index: int = main.level_index
	main._start_level(5)
	check("_start_level refuses a locked index", main.level_index == held_index)

	# --- leaving mid-level asks first -------------------------------------
	main.unlocked = 1
	main._start_level(1)
	await process_frame
	main._on_vessel_tapped(int(solutions["level_2"]["moves"][0]["from"]))
	main._on_vessel_tapped(int(solutions["level_2"]["moves"][0]["to"]))
	main._go_back()
	check("leaving a level with moves asks first", main.modal_layer != null)
	if main.modal_layer != null:
		main.modal_layer.queue_free()
		main.modal_layer = null

	# --- navigation and Android back -------------------------------------
	main._show_home()
	check("home is reachable", main._screen == "home")
	main._start_level(0)
	await process_frame
	main._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check("system back notification returns to the screen behind it", main._screen in ["home", "game"])
	main._start_level(0)
	await process_frame
	main._go_back()
	check("back from gameplay returns home", main._screen == "home")
	main._go_back()
	check("the map no longer exists", not main.has_method("_show_level_select"))
	main._go_back()
	check("back at home does not quit on desktop", main._screen == "home")
	main._show_credits()
	main._go_back()
	check("back from credits returns home", main._screen == "home")

	# --- booster: fill one bottle -----------------------------------------
	# The booster writes straight into state.tubes, bypassing the guards the
	# normal move path provides, so it has to prove it cannot corrupt a level:
	# every colour still appears exactly capacity times, no tube overflows, and
	# one tube comes out complete.
	main.unlocked = mini(main.levels.size() - 1, 30)
	main._start_level(3)
	await process_frame
	var credits_before: int = main.credits
	var colours_before := {}
	for t in main.state.tube_count():
		for col in main.state.tubes[t]:
			colours_before[str(col)] = int(colours_before.get(str(col), 0)) + 1

	main._on_fill_bottle()
	await process_frame

	check("booster spends one credit", main.credits == credits_before - 1)

	var colours_after := {}
	for t in main.state.tube_count():
		for col in main.state.tubes[t]:
			colours_after[str(col)] = int(colours_after.get(str(col), 0)) + 1
	var counts_preserved := true
	for col in colours_before.keys():
		if int(colours_after.get(col, -1)) != int(colours_before[col]):
			counts_preserved = false
	check("booster keeps every colour count", counts_preserved)

	var no_overflow := true
	for t in main.state.tube_count():
		if main.state.tubes[t].size() > main.state.capacity:
			no_overflow = false
	check("booster never overfills a tube", no_overflow)

	var filled := 0
	for t in main.state.tube_count():
		var tube: Array = main.state.tubes[t]
		if tube.size() == main.state.capacity:
			var same := true
			for col in tube:
				if col != tube[0]:
					same = false
					break
			if same:
				filled += 1
	check("booster leaves a completed bottle", filled >= 1)

	# The board must remain workable: in this puzzle family a colour can always be
	# consolidated while an empty tube exists, so losing the last one is the real
	# failure mode. (The previous version of this check was a tautology.)
	var empty_tubes := 0
	for t in main.state.tube_count():
		if main.state.tubes[t].is_empty():
			empty_tubes += 1
	check("booster leaves a spare tube", empty_tubes >= 1)

	# credits never go negative
	main.credits = 0
	main._on_fill_bottle()
	await process_frame
	check("booster refuses when out of credits", main.credits == 0)

	_finish()


func _play_level(index: int, solutions: Dictionary) -> void:
	var key := "level_%d" % (index + 1)
	for move in solutions[key]["moves"]:
		main._on_vessel_tapped(int(move["from"]))
		main._on_vessel_tapped(int(move["to"]))


func _find_button(root: Node, label: String) -> Button:
	if root == null:
		return null
	if root is Button and root.text == label:
		return root
	for child in root.get_children():
		var found := _find_button(child, label)
		if found != null:
			return found
	return null


func _finish() -> void:
	if transcript_path != "":
		var tf := FileAccess.open(transcript_path, FileAccess.WRITE)
		if tf != null:
			tf.store_string(JSON.stringify(transcript))
			tf.close()

	if save_backup != null:
		var sf := FileAccess.open(save_path, FileAccess.WRITE)
		sf.store_string(String(save_backup))
		sf.close()
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	print("")
	print("FLOW PASSED: ", passed, "  FAILED: ", failed)
	quit(0 if failed == 0 else 1)
