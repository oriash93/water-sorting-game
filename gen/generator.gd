class_name Generator
extends RefCounted

## Builds a level by scrambling the solved state with reverse pours.
## Each reverse pour is the exact inverse of a legal forward pour, so every
## generated level is solvable by construction.

const MAX_ATTEMPTS := 20


class ReverseMove:
	var take_from: int
	var put_into: int
	var count: int

	func _init(take_from_index: int, put_into_index: int, layer_count: int) -> void:
		take_from = take_from_index
		put_into = put_into_index
		count = layer_count


static func generate(params: LevelParams) -> PuzzleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = params.level_seed
	for _attempt in MAX_ATTEMPTS:
		var state := _scramble(params, rng)
		if not Rules.is_solved(state):
			return state
	push_error("Generator could not produce an unsolved level")
	return _scramble(params, rng)


static func _solved_state(params: LevelParams) -> PuzzleState:
	var state := PuzzleState.new()
	for color in params.colors:
		var bottle_index := state.add_bottle(params.capacity)
		for _layer in params.capacity:
			state.bottles[bottle_index].append(color)
	for _empty in params.empties:
		state.add_bottle(params.capacity)
	return state


static func _scramble(params: LevelParams, rng: RandomNumberGenerator) -> PuzzleState:
	var state := _solved_state(params)
	var last: ReverseMove = null
	for _step in params.steps:
		var options := _reverse_moves(state)
		if options.is_empty():
			break
		# Avoid undoing the previous scramble step so levels get tangled.
		if last != null:
			var without_undo: Array = options.filter(func(option: ReverseMove) -> bool:
				return not (option.take_from == last.put_into and option.put_into == last.take_from))
			if not without_undo.is_empty():
				options = without_undo
		var pick: ReverseMove = options[rng.randi_range(0, options.size() - 1)]
		var take_bottle: Array = state.bottles[pick.take_from]
		var put_bottle: Array = state.bottles[pick.put_into]
		var color: int = take_bottle[-1]
		for _layer in pick.count:
			take_bottle.pop_back()
			put_bottle.append(color)
		last = pick
	return state


## Every reverse pour available from `state`. A reverse pour takes `count` layers
## off `take_from` and puts them on `put_into`; its forward counterpart
## (put_into -> take_from) must be legal and move exactly `count` layers, which needs:
##  - after removing `count` layers, take_from is empty or still topped by that color
##  - put_into has room and its top is not that color (so the forward run is exactly `count`)
##  - it is not a pointless bottle-to-empty move
static func _reverse_moves(state: PuzzleState) -> Array:
	var moves: Array = []
	for take_from in state.bottles.size():
		var take_bottle: Array = state.bottles[take_from]
		if take_bottle.is_empty():
			continue
		var color: int = take_bottle[-1]
		var top_run_length := Rules.top_run(take_bottle)
		for count in range(1, top_run_length + 1):
			var remaining := take_bottle.size() - count
			if remaining > 0 and take_bottle[remaining - 1] != color:
				continue
			for put_into in state.bottles.size():
				if put_into == take_from:
					continue
				var put_bottle: Array = state.bottles[put_into]
				if state.caps[put_into] - put_bottle.size() < count:
					continue
				if not put_bottle.is_empty() and put_bottle[-1] == color:
					continue
				if put_bottle.is_empty() and remaining == 0:
					continue
				moves.append(ReverseMove.new(take_from, put_into, count))
	return moves
