class_name ProgressStore
extends RefCounted

## Local, offline-only save data. One small JSON file next to the game's user
## data: highest unlocked level, best move count per level, and the audio
## preference. Corrupt or missing files fall back to a clean profile instead of
## breaking the game.

const DEFAULT_PATH := "user://progress.json"

static func default_data() -> Dictionary:
	return {"unlocked": 0, "best": {}, "muted": false}

static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	var data := default_data()
	if not FileAccess.file_exists(path):
		return data
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return data

	data["unlocked"] = maxi(0, int(parsed.get("unlocked", 0)))
	data["muted"] = bool(parsed.get("muted", false))

	var best = parsed.get("best", {})
	if best is Dictionary:
		for key in best.keys():
			var moves := int(best[key])
			if moves > 0:
				data["best"][str(key)] = moves
	return data

static func save_data(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open %s for writing" % path)
		return false
	f.store_string(JSON.stringify({
		"unlocked": int(data.get("unlocked", 0)),
		"best": data.get("best", {}),
		"muted": bool(data.get("muted", false)),
	}))
	f.close()
	return true
