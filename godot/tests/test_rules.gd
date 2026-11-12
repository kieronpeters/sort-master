extends SceneTree

## Headless rules tests. Run:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tests/test_rules.gd
## Exit code 0 = all pass.

var passed := 0
var failed := 0

func check(name: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		print("FAIL: ", name)

func _initialize() -> void:
	var S = load("res://scripts/domain/puzzle_state.gd")

	# --- construction and cloning ---
	var s = S.new(4, [["A", "A", "B", "B"], ["B", "B", "A", "A"], [], []])
	check("tube count", s.tube_count() == 4)
	check("not won at start", not s.is_won())
	var c = s.clone()
	check("clone is independent", c.signature() == s.signature())
	c.apply_move(0, 2)
	check("clone mutation does not leak", s.signature() != c.signature())

	# --- R1 same tube ---
	check("R1 same tube illegal", not s.can_move(0, 0))

	# --- R2 empty source ---
	check("R2 empty source illegal", not s.can_move(2, 0))

	# --- R3 destination full ---
	var full = S.new(4, [["A"], ["B", "B", "B", "B"], [], []])
	check("R3 full destination illegal", not full.can_move(0, 1))

	# --- R4 colour mismatch ---
	var mix = S.new(4, [["A", "B"], ["C"], [], []])
	check("R4 mismatch illegal", not mix.can_move(0, 1))
	check("R4 empty destination legal", mix.can_move(0, 2))

	# --- R5 full-run-only ---
	var r5 = S.new(4, [["B", "A", "A", "A"], ["A", "A"], [], []])
	check("R5 run longer than free is illegal", not r5.can_move(0, 1))
	var r5b = S.new(4, [["B", "A", "A"], ["A", "A"], [], []])
	check("R5 exact fit is legal", r5b.can_move(0, 1))

	# --- R6/R7 whole run, order preserved ---
	var mv = S.new(4, [["B", "A", "A"], ["A"], [], []])
	var ok = mv.apply_move(0, 1)
	check("R6 move applied", ok)
	check("R6 whole run moved", mv.tubes[0] == ["B"])
	check("R7 order preserved", mv.tubes[1] == ["A","A","A"])

	# --- R8 illegal move changes nothing ---
	var before = mv.signature()
	check("R8 illegal returns false", not mv.apply_move(0, 0))
	check("R8 state unchanged", mv.signature() == before)

	# --- W1: single-colour but not full is NOT a win ---
	var split = S.new(4, [["A", "A"], ["A", "A"], ["B", "B", "B", "B"], []])
	check("W1 half tubes is not a win", not split.is_won())

	# --- W1: all full single-colour IS a win ---
	var won = S.new(4, [["A", "A", "A", "A"], ["B", "B", "B", "B"], [], []])
	check("W1 full tubes is a win", won.is_won())

	# --- top run ---
	var tr = S.new(4, [["A", "B", "B", "B"], [], [], []])
	check("top run length", tr.top_run(0) == 3)
	check("top run colour", tr.top_colour(0) == "B")

	# --- capacity is data-driven ---
	var cap5 = S.new(5, [["A"], [], []])
	check("capacity stored", cap5.capacity == 5)

	# --- canonical key ignores tube order ---
	var k1 = S.new(4, [["A"], ["B"], [], []]).canonical_key()
	var k2 = S.new(4, [["B"], [], ["A"], []]).canonical_key()
	check("canonical key ignores order", k1 == k2)


	# --- level validation (BUG-01) ---
	var V = load("res://scripts/domain/level_validator.gd")
	check("valid level accepted", V.validate({"ruleVersion": "rules-v1", "capacity": 4, "tubes": [["A","A","B","B"],["B","B","A","A"],[],[]]}) == "")
	check("wrong ruleVersion rejected", V.validate({"ruleVersion": "rules-v2", "capacity": 4, "tubes": [["A"],["A"],[],[]]}) != "")
	check("wrong capacity rejected", V.validate({"ruleVersion": "rules-v1", "capacity": 5, "tubes": [["A"],["A"],[],[]]}) != "")
	check("wrong colour count rejected", V.validate({"ruleVersion": "rules-v1", "capacity": 4, "tubes": [["A","A"],["A"],[],[]]}) != "")
	check("over-capacity tube rejected", V.validate({"ruleVersion": "rules-v1", "capacity": 4, "tubes": [["A","A","A","A","A"],[],[]]}) != "")
	check("no empty tube rejected", V.validate({"ruleVersion": "rules-v1", "capacity": 4, "tubes": [["A","A","B","B"],["B","B","A","A"]]}) != "")
	check("already won rejected", V.validate({"ruleVersion": "rules-v1", "capacity": 4, "tubes": [["A","A","A","A"],["B","B","B","B"],[]]}) != "")
	check("single tube rejected", V.validate({"ruleVersion": "rules-v1", "capacity": 4, "tubes": [["A","A","A","A"]]}) != "")
	check("non-object rejected", V.validate("nope") != "")

	# every shipped level must pass the game's own validator
	var shipped := 0
	for n in range(1, 31):
		var path := "res://levels/level_%d.json" % n
		if not FileAccess.file_exists(path):
			continue
		shipped += 1
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		var err: String = V.validate(parsed)
		check("shipped level %d validates (%s)" % [n, err], err == "")
	check("all 30 shipped levels present", shipped == 30)
	print("")
	print("PASSED: ", passed, "  FAILED: ", failed)
	quit(0 if failed == 0 else 1)

