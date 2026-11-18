extends SceneTree

## Exercises every booster on a set of levels, then plays each level to completion.
##
## For each level: use Fill, undo it, add a bottle, shuffle, restart to a clean
## board, then replay the recorded solution. Screenshots are captured at the
## booster moment and at completion.
##
##   Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 720x1280 \
##       --script res://tests/booster_check.gd -- --levels=248,346,428,500

const OUT := "res://../docs/evidence/booster/"

var main: Control
var passed := 0
var failed := 0
var shots: Array = []


func _initialize() -> void:
	_run()


func check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("PASS  ", name)
	else:
		failed += 1
		print("FAIL  ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)

	var levels := [248, 346, 428, 500]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="):
			levels = []
			for part in arg.substr(9).split(","):
				if part.strip_edges().is_valid_int():
					levels.append(int(part.strip_edges()))

	var ext = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions_ext.json"))

	for n in levels:
		print("")
		print("--- level ", n, " ---")
		main.unlocked = maxi(0, main.levels.size() - 1)
		main._start_level(n - 1)
		await _frames(4)

		var colours_before := _counts(main.state)
		var tubes_before: int = main.state.tube_count()
		check("level %d starts with 3 credits" % n, main.credits == 3)

		# --- fill one bottle ------------------------------------------------
		main._on_fill_bottle()
		await _frames(3)
		check("fill spends a credit", main.credits == 2)
		check("fill keeps colour counts", _counts(main.state) == colours_before)
		check("fill completes a bottle", _completed(main.state) >= 1)
		await _shot("L%d_fill" % n)

		# --- undo the fill --------------------------------------------------
		main._on_undo()
		await _frames(3)
		check("undo spends a credit", main.credits == 1)
		check("undo restores the board", _counts(main.state) == colours_before)
		check("undo un-completes the bottle", _completed(main.state) < 1)
		await _shot("L%d_undo" % n)

		# --- add a bottle ---------------------------------------------------
		main._on_add_bottle()
		await _frames(3)
		check("add bottle grows the board", main.state.tube_count() == tubes_before + 1)
		check("add bottle costs a credit", main.credits == 0)
		await _shot("L%d_add" % n)

		# --- out of credits -------------------------------------------------
		main._on_shuffle()
		await _frames(2)
		check("shuffle refuses with no credits", main.credits == 0)

		# --- restart, then shuffle with a fresh board -----------------------
		main._start_level(n - 1)
		await _frames(4)
		var fresh := _counts(main.state)
		main._on_shuffle()
		await _frames(3)
		check("shuffle keeps colour counts", _counts(main.state) == fresh)
		check("shuffle costs a credit", main.credits == 2)
		await _shot("L%d_shuffle" % n)

		# --- clean board, play it out ---------------------------------------
		main._start_level(n - 1)
		await _frames(4)
		var key := "level_%d" % n
		var moves: Array = []
		if ext is Dictionary and ext.has(key):
			moves = ext[key]
		check("solution available for %d" % n, not moves.is_empty())
		for move in moves:
			main._on_vessel_tapped(int(move["from"]))
			await _frames(1)
			main._on_vessel_tapped(int(move["to"]))
			await _wait_pour()
			await _frames(1)
		await create_timer(0.4).timeout
		check("level %d completes" % n, main.state.is_won())
		check("level %d uses the minimum" % n, main.moves == moves.size())
		await _shot("L%d_complete" % n)
		main._close_win()
		await _frames(3)

	print("")
	print("BOOSTER CHECK: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


func _counts(s) -> Dictionary:
	var counts := {}
	for t in s.tube_count():
		for c in s.tubes[t]:
			counts[str(c)] = int(counts.get(str(c), 0)) + 1
	return counts


func _completed(s) -> int:
	var done := 0
	for t in s.tube_count():
		var tube: Array = s.tubes[t]
		if tube.size() == s.capacity and tube.size() > 0:
			var same := true
			for c in tube:
				if c != tube[0]:
					same = false
					break
			if same:
				done += 1
	return done


func _wait_pour() -> void:
	var guard := 0
	while main._pouring and guard < 400:
		await process_frame
		guard += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(OUT + name + ".png")
