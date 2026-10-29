class_name PuzzleState
extends RefCounted

## A bottle is an Array of color ids, bottom to top.
var bottles: Array = []
var caps: PackedInt32Array = PackedInt32Array()
var history: Array = []


static func from_bottles(bottle_list: Array, capacity: int) -> PuzzleState:
	var state := PuzzleState.new()
	for bottle in bottle_list:
		state.bottles.append((bottle as Array).duplicate())
		state.caps.append(capacity)
	return state


func clone() -> PuzzleState:
	var copy := PuzzleState.new()
	for bottle in bottles:
		copy.bottles.append((bottle as Array).duplicate())
	copy.caps = caps.duplicate()
	return copy


## Order-independent identity of the position (bottles are interchangeable).
func key() -> String:
	var bottle_keys: PackedStringArray = PackedStringArray()
	for bottle_index in bottles.size():
		var bottle_key := str(caps[bottle_index]) + ":"
		for color in bottles[bottle_index]:
			bottle_key += char(65 + color)
		bottle_keys.append(bottle_key)
	bottle_keys.sort()
	return "|".join(bottle_keys)


func add_bottle(capacity: int) -> int:
	bottles.append([])
	caps.append(capacity)
	return bottles.size() - 1
