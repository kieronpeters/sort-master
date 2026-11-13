extends SceneTree

## QA evidence capture for the palette decision: one screenshot per affected
## level. Development-only, excluded from release exports with the rest of
## tests/.
##
## Run:
##   Godot_v4.7.2-stable_win64_console.exe --path godot --resolution 720x1280 \
##       --script res://tests/capture_qa.gd

const LEVELS := [16, 21, 25, 30]


func _initialize() -> void:
	_run()


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.unlocked = 29
	for n in LEVELS:
		main._start_level(n - 1)
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../docs/evidence/qa-level-%d.png" % n)
		print("shot level ", n)
	quit()
