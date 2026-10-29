class_name Solver
extends RefCounted

## Weighted A* over canonical states. Not guaranteed shortest, but fast and
## good enough for hints. Call step() with a time budget each frame so it never
## janks a phone or the single-threaded web build.

const DEFAULT_NODE_LIMIT := 50000

var done := false
var solved := false
var path: Array = []
var max_nodes := DEFAULT_NODE_LIMIT
var heuristic_weight := 3

var _states: Array = []
var _parent_of := PackedInt32Array()
var _move_from_parent: Array = []
var _cost_so_far := PackedInt32Array()
## Binary min-heap of Vector2i(priority, node_index).
var _frontier: Array[Vector2i] = []
var _seen := {}


static func solve_sync(start: PuzzleState, node_limit := DEFAULT_NODE_LIMIT) -> Array:
	var solver := Solver.new()
	solver.max_nodes = node_limit
	solver.begin(start)
	while not solver.done:
		solver.step(10000)
	return solver.path if solver.solved else []


func begin(start: PuzzleState) -> void:
	var root := start.clone()
	_states = [root]
	_parent_of = PackedInt32Array([-1])
	_move_from_parent = [Vector2i(-1, -1)]
	_cost_so_far = PackedInt32Array([0])
	_frontier = []
	_seen = {root.key(): true}
	path = []
	done = false
	solved = false
	_push(Vector2i(_mismatches(root) * heuristic_weight, 0))


func step(budget_usec: int) -> void:
	if done:
		return
	var deadline := Time.get_ticks_usec() + budget_usec
	while Time.get_ticks_usec() < deadline:
		if _frontier.is_empty() or _states.size() > max_nodes:
			done = true
			return
		var node_index := _pop_best().y
		var current: PuzzleState = _states[node_index]
		_states[node_index] = null
		if Rules.is_solved(current):
			_build_path(node_index)
			solved = true
			done = true
			return
		for move in Rules.legal_moves(current):
			var child := current.clone()
			Rules.apply(child, move.x, move.y)
			child.history = []
			var state_key := child.key()
			if _seen.has(state_key):
				continue
			_seen[state_key] = true
			_states.append(child)
			_parent_of.append(node_index)
			_move_from_parent.append(move)
			var cost := _cost_so_far[node_index] + 1
			_cost_so_far.append(cost)
			_push(Vector2i(cost + _mismatches(child) * heuristic_weight, _states.size() - 1))


func _build_path(node_index: int) -> void:
	var reversed_moves: Array = []
	while _parent_of[node_index] != -1:
		reversed_moves.append(_move_from_parent[node_index])
		node_index = _parent_of[node_index]
	reversed_moves.reverse()
	path = reversed_moves


## Heuristic: number of adjacent layers with different colors (0 when sorted).
static func _mismatches(state: PuzzleState) -> int:
	var count := 0
	for bottle in state.bottles:
		for layer_index in range(1, bottle.size()):
			if bottle[layer_index] != bottle[layer_index - 1]:
				count += 1
	return count


func _is_better(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y > b.y)


func _swap(first: int, second: int) -> void:
	var held := _frontier[first]
	_frontier[first] = _frontier[second]
	_frontier[second] = held


func _push(entry: Vector2i) -> void:
	_frontier.append(entry)
	var index := _frontier.size() - 1
	while index > 0:
		var parent_index := (index - 1) >> 1
		if not _is_better(_frontier[index], _frontier[parent_index]):
			break
		_swap(index, parent_index)
		index = parent_index


func _pop_best() -> Vector2i:
	var best := _frontier[0]
	var last: Vector2i = _frontier.pop_back()
	if not _frontier.is_empty():
		_frontier[0] = last
		var index := 0
		var count := _frontier.size()
		while true:
			var left := 2 * index + 1
			var right := left + 1
			var smallest := index
			if left < count and _is_better(_frontier[left], _frontier[smallest]):
				smallest = left
			if right < count and _is_better(_frontier[right], _frontier[smallest]):
				smallest = right
			if smallest == index:
				break
			_swap(index, smallest)
			index = smallest
	return best
