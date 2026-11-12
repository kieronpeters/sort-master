class_name LevelValidator
extends RefCounted

## Mirrors tools/solver/solve.py::validate() exactly.
## The game and the solver must agree on what a valid level is; if these two
## ever diverge, a level can pass one and fail the other.

const RULE_VERSION := "rules-v1"
const CAPACITY := 4


## Returns "" when valid, otherwise a human-readable reason.
static func validate(level: Variant) -> String:
	if level == null or not (level is Dictionary):
		return "level is not an object"

	var d: Dictionary = level
	if String(d.get("ruleVersion", "")) != RULE_VERSION:
		return "ruleVersion must be %s" % RULE_VERSION
	if int(d.get("capacity", 0)) != CAPACITY:
		return "capacity must be %d" % CAPACITY

	var tubes = d.get("tubes", null)
	if not (tubes is Array):
		return "tubes must be an array"
	if tubes.size() < 2:
		return "at least two tubes are required"

	var counts := {}
	var empty := 0
	for i in tubes.size():
		var tube = tubes[i]
		if not (tube is Array):
			return "tube %d is not an array" % i
		if tube.size() > CAPACITY:
			return "tube %d holds %d units, capacity is %d" % [i, tube.size(), CAPACITY]
		if tube.size() == 0:
			empty += 1
		for unit in tube:
			if not (unit is String) or String(unit).length() == 0:
				return "tube %d contains an invalid unit" % i
			counts[unit] = int(counts.get(unit, 0)) + 1

	if counts.is_empty():
		return "board is empty"
	for colour in counts.keys():
		if int(counts[colour]) != CAPACITY:
			return "colour %s appears %d times, expected %d" % [colour, counts[colour], CAPACITY]
	if empty == 0:
		return "no empty tube"

	if _is_won(tubes):
		return "level is already won at load"

	return ""


static func _is_won(tubes: Array) -> bool:
	for tube in tubes:
		if tube.size() == 0:
			continue
		if tube.size() != CAPACITY:
			return false
		var first = tube[0]
		for unit in tube:
			if unit != first:
				return false
	return true
