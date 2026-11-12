extends SceneTree

## M4-02 parity harness (direction 1: solver -> game).
##
## Replays the independent Python solver's solution for every level through the
## game's own PuzzleState. A move the solver considers legal that the game
## rejects (or a final board the game does not call a win) is a parity failure.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tests/parity.gd
## Exit code 0 = parity holds.

const PuzzleStateScript = preload("res://scripts/domain/puzzle_state.gd")

var passed := 0
var failed := 0

func check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", name)

func _initialize() -> void:
	var solutions_path := "res://tests/solutions.json"
	check("solutions file exists", FileAccess.file_exists(solutions_path))
	if not FileAccess.file_exists(solutions_path):
		_finish()
		return

	var solutions = JSON.parse_string(FileAccess.get_file_as_string(solutions_path))
	check("solutions parse", solutions is Dictionary)
	if not (solutions is Dictionary):
		_finish()
		return

	var levels_checked := 0
	for key in solutions.keys():
		var entry: Dictionary = solutions[key]
		check(key + ": ruleVersion", entry.get("ruleVersion", "") == "rules-v1")

		var level_path := "res://levels/%s.json" % key
		if not FileAccess.file_exists(level_path):
			check(key + ": level file present", false)
			continue
		var level = JSON.parse_string(FileAccess.get_file_as_string(level_path))
		if not (level is Dictionary):
			check(key + ": level parse", false)
			continue

		var state = PuzzleStateScript.new(int(level.get("capacity", 4)), level.get("tubes", []))
		check(key + ": not won at load", not state.is_won())

		var moves: Array = entry.get("moves", [])
		var legal := true
		for i in moves.size():
			var m: Dictionary = moves[i]
			var from_i := int(m.get("from", -1))
			var to_i := int(m.get("to", -1))
			if not state.can_move(from_i, to_i):
				legal = false
				print("  %s move %d (%d->%d) rejected by the game" % [key, i + 1, from_i, to_i])
				break
			# units reported by the solver must match the game's top run
			if int(m.get("units", -1)) != state.top_run(from_i):
				legal = false
				print("  %s move %d unit count mismatch" % [key, i + 1])
				break
			state.apply_move(from_i, to_i)

		check(key + ": every solver move is legal in the game", legal)
		check(key + ": solver move count matches minimum", moves.size() == int(entry.get("minimumMoves", -1)))
		check(key + ": replay reaches a win", state.is_won())
		levels_checked += 1

	check("all 30 levels replayed", levels_checked == 30)
	print("levels replayed: ", levels_checked)
	_finish()

func _finish() -> void:
	print("")
	print("PARITY PASSED: ", passed, "  FAILED: ", failed)
	quit(0 if failed == 0 else 1)
