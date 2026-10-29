class_name Rules
extends RefCounted


static func top_run(bottle: Array) -> int:
	if bottle.is_empty():
		return 0
	var color: int = bottle[-1]
	var run := 0
	for layer_index in range(bottle.size() - 1, -1, -1):
		if bottle[layer_index] != color:
			break
		run += 1
	return run


static func is_uniform(bottle: Array) -> bool:
	return not bottle.is_empty() and top_run(bottle) == bottle.size()


static func is_complete(bottle: Array, capacity: int) -> bool:
	return bottle.size() == capacity and is_uniform(bottle)


static func is_bottle_complete(state: PuzzleState, bottle_index: int) -> bool:
	return is_complete(state.bottles[bottle_index], state.caps[bottle_index])


## A bottle the player may pick up: it has liquid and is not already finished.
static func is_selectable(state: PuzzleState, bottle_index: int) -> bool:
	return not (state.bottles[bottle_index] as Array).is_empty() and not is_bottle_complete(state, bottle_index)


## Layers a pour from -> to would move; 0 when the pour is not legal.
static func move_count(state: PuzzleState, from: int, to: int) -> int:
	if from == to:
		return 0
	var source: Array = state.bottles[from]
	var target: Array = state.bottles[to]
	if source.is_empty():
		return 0
	var free_space: int = state.caps[to] - target.size()
	if free_space <= 0:
		return 0
	if not target.is_empty() and target[-1] != source[-1]:
		return 0
	return mini(top_run(source), free_space)


## Legal but pointless: moving a finished or single-color bottle into an empty one,
## or pouring out of a bottle that is already complete.
static func is_useless(state: PuzzleState, from: int, to: int) -> bool:
	if is_bottle_complete(state, from):
		return true
	return is_uniform(state.bottles[from]) and (state.bottles[to] as Array).is_empty()


static func can_pour(state: PuzzleState, from: int, to: int) -> bool:
	return move_count(state, from, to) > 0 and not is_useless(state, from, to)


static func legal_moves(state: PuzzleState) -> Array:
	var moves: Array = []
	for from in state.bottles.size():
		for to in state.bottles.size():
			if can_pour(state, from, to):
				moves.append(Vector2i(from, to))
	return moves


## Applies the pour and returns its record, or an empty Dictionary if rejected.
static func apply(state: PuzzleState, from: int, to: int) -> Dictionary:
	if not can_pour(state, from, to):
		return {}
	var moved_count := move_count(state, from, to)
	var source: Array = state.bottles[from]
	var target: Array = state.bottles[to]
	var color: int = source[-1]
	for _layer in moved_count:
		source.pop_back()
		target.append(color)
	var move_record := {"from": from, "to": to, "count": moved_count, "color": color}
	state.history.append(move_record)
	return move_record


static func undo(state: PuzzleState) -> Dictionary:
	if state.history.is_empty():
		return {}
	var move_record: Dictionary = state.history.pop_back()
	var source: Array = state.bottles[move_record.from]
	var target: Array = state.bottles[move_record.to]
	for _layer in int(move_record.count):
		target.pop_back()
		source.append(move_record.color)
	return move_record


static func is_solved(state: PuzzleState) -> bool:
	for bottle_index in state.bottles.size():
		if not (state.bottles[bottle_index] as Array).is_empty() and not is_bottle_complete(state, bottle_index):
			return false
	return true
