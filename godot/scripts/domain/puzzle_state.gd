class_name PuzzleState
extends RefCounted

## rules-v1 domain model. No nodes, no rendering, no input.
## See docs/rules-v1.md. This class is the single source of truth for gameplay.

var capacity: int = 4
var tubes: Array = []          # Array of Array[String], index 0 = bottom

func _init(p_capacity: int = 4, p_tubes: Array = []) -> void:
	capacity = p_capacity
	tubes = []
	for t in p_tubes:
		tubes.append(t.duplicate())

func clone() -> PuzzleState:
	var copy = get_script().new(capacity, tubes)
	return copy

func tube_count() -> int:
	return tubes.size()

func count_at(index: int) -> int:
	return tubes[index].size()

func top_colour(index: int) -> String:
	var t: Array = tubes[index]
	return "" if t.is_empty() else t[t.size() - 1]

func top_run(index: int) -> int:
	var t: Array = tubes[index]
	if t.is_empty():
		return 0
	var colour: String = t[t.size() - 1]
	var run := 0
	for i in range(t.size() - 1, -1, -1):
		if t[i] != colour:
			break
		run += 1
	return run

## R1-R5: is the move legal? R6 (whole run) is implied by apply_move.
func can_move(from_i: int, to_i: int) -> bool:
	if from_i == to_i:
		return false                                   # R1
	if from_i < 0 or to_i < 0 or from_i >= tubes.size() or to_i >= tubes.size():
		return false
	if tubes[from_i].is_empty():
		return false                                   # R2
	if tubes[to_i].size() >= capacity:
		return false                                   # R3
	if not tubes[to_i].is_empty():
		if top_colour(to_i) != top_colour(from_i):
			return false                               # R4
	return top_run(from_i) <= capacity - tubes[to_i].size()   # R5

## Applies a legal move atomically (R8). Returns false and changes nothing otherwise.
func apply_move(from_i: int, to_i: int) -> bool:
	if not can_move(from_i, to_i):
		return false
	var units := top_run(from_i)
	var moved: Array = tubes[from_i].slice(tubes[from_i].size() - units, tubes[from_i].size())
	tubes[from_i] = tubes[from_i].slice(0, tubes[from_i].size() - units)
	tubes[to_i] = tubes[to_i] + moved                   # R7: order preserved
	return true

## W1: every non-empty tube is single-colour AND full.
func is_won() -> bool:
	for t in tubes:
		if t.is_empty():
			continue
		if t.size() != capacity:
			return false
		var first: String = t[0]
		for unit in t:
			if unit != first:
				return false
	return true

func all_moves() -> Array:
	var moves: Array = []
	for a in tubes.size():
		for b in tubes.size():
			if can_move(a, b):
				moves.append([a, b])
	return moves

## Canonical key for tests and solver parity (rules-v1 11.2: sort the tuples).
func canonical_key() -> String:
	var parts: Array = []
	for t in tubes:
		parts.append("".join(t))
	parts.sort()
	return "|".join(parts)

func signature() -> String:
	return str(tubes)
