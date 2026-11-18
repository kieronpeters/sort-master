extends SceneTree

## Drives the real game scene through a set of levels and proves each one reaches
## a win, capturing what the player sees.
##
## This is a demonstration run, not a substitute for the manual-play sheet: it
## uses the verified solution moves rather than a human deciding what to do. It
## does exercise the same tap path, the pour animation and the completion card.
##
##   Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 720x1280 \
##       --script res://tests/playthrough.gd

const EVIDENCE := "res://../docs/evidence/playthrough/"

var main: Control
var shots: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)

	var solutions = JSON.parse_string(FileAccess.get_file_as_string("res://tests/solutions.json"))
	# 1-10 the tutorial ramp, 16 the palette worst case, 25 six colours, 30 eight tubes.
	# Levels may be narrowed for a quick check: --levels=1 or --levels=1,16,30.
	# Defaults to the whole catalogue. The pour code is shared by every level, so
	# one level exercises the same animation as thirty.
	var subset: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="):
			for part in arg.substr(9).split(","):
				if part.strip_edges().is_valid_int():
					subset.append(int(part.strip_edges()))
	if subset.is_empty():
		subset = range(1, 31)
	var milestone := subset if subset.size() <= 6 else [1, 5, 16, 25, 30]
	var passed := 0

	print("")
	print("level  moves  expected  won    result")
	print("------------------------------------------")
	for n in subset:
		# unlock through the whole catalogue; the extended levels are past 30 now
		main.unlocked = maxi(0, main.levels.size() - 1)
		main.best = {}
		main._start_level(n - 1)
		await _frames(4)

		if n in milestone:
			await create_timer(0.45).timeout
			await _shot("level_%02d_start" % n)

		var key := "level_%d" % n
		# Levels 1-30 keep their solutions in solutions.json; the extended
		# catalogue carries its own, so the harness can play any level.
		var moves: Array = []
		if solutions.has(key):
			moves = solutions[key]["moves"]
		else:
			var path := "res://levels/level_%d.json" % n
			if FileAccess.file_exists(path):
				var lvl = JSON.parse_string(FileAccess.get_file_as_string(path))
				if lvl is Dictionary and lvl.has("solution"):
					moves = lvl["solution"]
		if moves.is_empty():
			print("FAIL   %02d   no recorded solution" % n)
			continue
		var shot_pour: bool = (n == int(subset[0]))
		for mi in moves.size():
			var move: Dictionary = moves[mi]
			main._on_vessel_tapped(int(move["from"]))
			await _frames(1)
			main._on_vessel_tapped(int(move["to"]))
			if shot_pour and mi == 0:
				await _frames(7)
				await _shot("pour_travel")
				await _frames(10)
				await _shot("pour_flow")
				await _frames(10)
				await _shot("pour_late")
			await _wait_pour()
			await _frames(1)

		await create_timer(0.35).timeout
		var won: bool = main.state != null and main.state.is_won()
		var ok: bool = won and main.moves == moves.size()
		if ok:
			passed += 1
		print("%s   %02d   %3d   %3d    %s" % [
			"PASS" if ok else "FAIL", n, main.moves, moves.size(),
			"won" if won else "NOT WON"])

		if n in milestone:
			await _shot("level_%02d_complete" % n)

		main._close_win()
		await _frames(3)

	print("------------------------------------------")
	print("PLAYTHROUGH: %d/%d levels won" % [passed, subset.size()])
	if passed != subset.size():
		print("RESULT: FAIL")
		quit(1)
		return
	print("RESULT: PASS")
	quit(0)


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
	var path := EVIDENCE + name + ".png"
	img.save_png(path)
	print("   shot %s" % name)
