class_name Rules
extends RefCounted


static func top_color(b: Array) -> int:
	return -1 if b.is_empty() else b[b.size() - 1]


static func top_run(b: Array) -> int:
	if b.is_empty():
		return 0
	var c: int = b[b.size() - 1]
	var n := 0
	for i in range(b.size() - 1, -1, -1):
		if b[i] != c:
			break
		n += 1
	return n


static func is_uniform(b: Array) -> bool:
	return not b.is_empty() and top_run(b) == b.size()


static func is_complete(b: Array, cap: int) -> bool:
	return b.size() == cap and is_uniform(b)


## Layers a pour from -> to would move; 0 when the pour is not legal.
static func move_count(s: PuzzleState, from: int, to: int) -> int:
	if from == to:
		return 0
	var a: Array = s.bottles[from]
	var b: Array = s.bottles[to]
	if a.is_empty():
		return 0
	var space: int = s.caps[to] - b.size()
	if space <= 0:
		return 0
	if not b.is_empty() and b[b.size() - 1] != a[a.size() - 1]:
		return 0
	return mini(top_run(a), space)


## Legal but pointless: moving a finished or single-color bottle into an empty one,
## or pouring out of a bottle that is already complete.
static func is_useless(s: PuzzleState, from: int, to: int) -> bool:
	var a: Array = s.bottles[from]
	if is_complete(a, s.caps[from]):
		return true
	return is_uniform(a) and (s.bottles[to] as Array).is_empty()


static func can_pour(s: PuzzleState, from: int, to: int) -> bool:
	return move_count(s, from, to) > 0 and not is_useless(s, from, to)


static func legal_moves(s: PuzzleState) -> Array:
	var out: Array = []
	for i in s.bottles.size():
		for j in s.bottles.size():
			if can_pour(s, i, j):
				out.append(Vector2i(i, j))
	return out


## Applies the pour and returns its record, or an empty Dictionary if rejected.
static func apply(s: PuzzleState, from: int, to: int) -> Dictionary:
	if not can_pour(s, from, to):
		return {}
	var n := move_count(s, from, to)
	var a: Array = s.bottles[from]
	var b: Array = s.bottles[to]
	var color: int = a[a.size() - 1]
	for i in n:
		a.pop_back()
		b.append(color)
	var rec := {"from": from, "to": to, "count": n, "color": color}
	s.history.append(rec)
	return rec


static func undo(s: PuzzleState) -> Dictionary:
	if s.history.is_empty():
		return {}
	var rec: Dictionary = s.history.pop_back()
	var a: Array = s.bottles[rec.from]
	var b: Array = s.bottles[rec.to]
	for i in int(rec.count):
		b.pop_back()
		a.append(rec.color)
	return rec


static func is_solved(s: PuzzleState) -> bool:
	for i in s.bottles.size():
		var b: Array = s.bottles[i]
		if not b.is_empty() and not is_complete(b, s.caps[i]):
			return false
	return true
