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

	# --- board layout: one source of truth for 3D placement and tap strips ---
	var L = load("res://scripts/presentation/board_layout.gd")
	for n in [3, 4, 5, 6, 8]:
		var lay: Dictionary = L.compute(n, Vector2(1080, 1920))
		check("layout %d tubes not empty" % n, not lay.is_empty())
		check("layout %d vessel width positive" % n, float(lay.vessel_w) > 0.0)
		check("layout %d baseline on the 78%% line" % n, is_equal_approx(float(lay.baseline), 1920.0 * 0.78))
		check("layout %d hit strip starts above the base" % n, float(lay.hit_top) < float(lay.baseline))
		check("layout %d centres ordered" % n, float(lay.centres[0]) < float(lay.centres[n - 1]))
		check("layout %d group inside the design width" % n, float(lay.centres[n - 1]) + float(lay.slot) * 0.5 <= 1080.0)
		check("layout %d group centred" % n, is_equal_approx(float(lay.centres[0]) + float(lay.centres[n - 1]), 1080.0 + float(lay.slot) - float(lay.vessel_w)))

	var tall: Dictionary = L.compute(6, Vector2(1080, 2400))
	check("taller viewport keeps 1:1 design scale", is_equal_approx(float(tall.scale), 1.0))
	check("taller viewport moves the baseline down", float(tall.baseline) > 1920.0 * 0.78)
	check("degenerate layout rejected", L.compute(0, Vector2(1080, 1920)).is_empty())

	# --- progress store: save, load, clamping, corrupt data ----------------
	var PS = load("res://scripts/domain/progress_store.gd")
	var tmp := "user://test_progress.json"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	check("missing save gives a clean profile", int(PS.load_data(tmp).unlocked) == 0)
	check("progress round-trips", PS.save_data({"unlocked": 7, "best": {"0": 3, "2": 9}, "muted": true}, tmp))
	var loaded: Dictionary = PS.load_data(tmp)
	check("unlocked persisted", int(loaded.unlocked) == 7)
	check("best persisted", int(loaded.best.get("2", 0)) == 9)
	check("mute persisted", bool(loaded.muted) == true)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	check("corrupt save falls back to a clean profile", int(PS.load_data(tmp).unlocked) == 0)
	PS.save_data({"unlocked": -5, "best": {"0": -2, "1": 4}}, tmp)
	var clamped: Dictionary = PS.load_data(tmp)
	check("negative unlocked clamped", int(clamped.unlocked) == 0)
	check("non-positive best discarded", not clamped.best.has("0") and int(clamped.best.get("1", 0)) == 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	print("")
	print("PASSED: ", passed, "  FAILED: ", failed)
	quit(0 if failed == 0 else 1)

