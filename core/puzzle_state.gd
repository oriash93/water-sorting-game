class_name PuzzleState
extends RefCounted

## A bottle is an Array of color ids, bottom to top.
var bottles: Array = []
var caps: PackedInt32Array = PackedInt32Array()
var history: Array = []


static func from_bottles(b: Array, capacity: int) -> PuzzleState:
	var s := PuzzleState.new()
	for bottle in b:
		s.bottles.append((bottle as Array).duplicate())
		s.caps.append(capacity)
	return s


func clone() -> PuzzleState:
	var s := PuzzleState.new()
	for b in bottles:
		s.bottles.append((b as Array).duplicate())
	s.caps = caps.duplicate()
	return s


## Order-independent identity of the position (bottles are interchangeable).
func key() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i in bottles.size():
		var t := str(caps[i]) + ":"
		for c in bottles[i]:
			t += char(65 + c)
		parts.append(t)
	parts.sort()
	return "|".join(parts)


func add_bottle(capacity: int) -> int:
	bottles.append([])
	caps.append(capacity)
	return bottles.size() - 1
