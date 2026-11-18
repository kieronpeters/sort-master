class_name ProgressStore
extends RefCounted

## Local, offline-only save data. One small JSON file next to the game's user
## data: highest unlocked level, best move count per level, and the audio
## preference. Corrupt or missing files fall back to a clean profile instead of
## breaking the game.
##
## Writes go to a sibling temp file and are renamed into place, so a kill
## mid-write cannot leave a half-written profile behind.

const DEFAULT_PATH := "user://progress.json"

static func default_data() -> Dictionary:
	return {"unlocked": 0, "best": {}, "muted": false, "music": 1.0, "sfx": 1.0, "music_muted": false, "sfx_muted": false}

static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	var data := default_data()
	if not FileAccess.file_exists(path):
		return data
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return data

	var unlocked = parsed.get("unlocked", 0)
	if unlocked is int or unlocked is float:
		data["unlocked"] = maxi(0, int(unlocked))

	var muted = parsed.get("muted", false)
	if muted is bool:
		data["muted"] = muted

	# Separate music and effects levels, 0.0-1.0. Older saves without them keep
	# the defaults, so no migration step is needed.
	# 0.0 - 2.0: the top half of the range is a boost, because the phone speaker
	# at 100 % was too quiet in testing.
	for key in ["music", "sfx"]:
		var level = parsed.get(key, 1.0)
		if level is int or level is float:
			data[key] = clampf(float(level), 0.0, 2.0)
	for key in ["music_muted", "sfx_muted"]:
		var flag = parsed.get(key, false)
		if flag is bool:
			data[key] = flag

	var best = parsed.get("best", {})
	if best is Dictionary:
		for key in best.keys():
			var moves = best[key]
			if (moves is int or moves is float) and int(moves) > 0:
				data["best"][str(key)] = int(moves)
	return data

static func save_data(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open %s for writing" % tmp)
		return false
	var clean_best := {}
	var source_best = data.get("best", {})
	if source_best is Dictionary:
		for key in source_best.keys():
			var moves = source_best[key]
			if (moves is int or moves is float) and int(moves) > 0:
				clean_best[str(key)] = int(moves)
	f.store_string(JSON.stringify({
		"unlocked": int(data.get("unlocked", 0)),
		"best": clean_best,
		"muted": bool(data.get("muted", false)),
		"music": clampf(float(data.get("music", 1.0)), 0.0, 2.0),
		"sfx": clampf(float(data.get("sfx", 1.0)), 0.0, 2.0),
		"music_muted": bool(data.get("music_muted", false)),
		"sfx_muted": bool(data.get("sfx_muted", false)),
	}))
	f.close()

	var absolute := ProjectSettings.globalize_path(path)
	var absolute_tmp := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)
	if DirAccess.rename_absolute(absolute_tmp, absolute) != OK:
		push_warning("Could not replace %s" % path)
		return false
	return true
