class_name Solver
extends RefCounted

## Weighted A* over canonical states. Not guaranteed shortest, but fast and
## good enough for hints. Call step() with a node budget each frame so it never
## janks a phone or the single-threaded web build.

var done: bool = false
var solved: bool = false
var path: Array = []
var max_nodes: int = 300000
var weight: int = 3

var _states: Array = []
var _parent: PackedInt32Array = PackedInt32Array()
var _move: Array = []
var _g: PackedInt32Array = PackedInt32Array()
var _heap: Array = []
var _seen: Dictionary = {}


static func solve_sync(start: PuzzleState, node_limit: int = 300000) -> Array:
	var sv := Solver.new()
	sv.max_nodes = node_limit
	sv.begin(start)
	while not sv.done:
		sv.step(2000)
	return sv.path if sv.solved else []


func begin(start: PuzzleState) -> void:
	var root := start.clone()
	_states = [root]
	_parent = PackedInt32Array([-1])
	_move = [Vector2i(-1, -1)]
	_g = PackedInt32Array([0])
	_heap = []
	_seen = {root.key(): true}
	path = []
	done = false
	solved = false
	_push(Vector2i(_heuristic(root) * weight, 0))


func step(budget: int) -> void:
	for i in budget:
		if _heap.is_empty() or _states.size() > max_nodes:
			done = true
			return
		var top := _pop()
		var idx := top.y
		var s: PuzzleState = _states[idx]
		if Rules.is_solved(s):
			_build_path(idx)
			solved = true
			done = true
			return
		for m in Rules.legal_moves(s):
			var child := s.clone()
			Rules.apply(child, m.x, m.y)
			child.history = []
			var k := child.key()
			if _seen.has(k):
				continue
			_seen[k] = true
			_states.append(child)
			_parent.append(idx)
			_move.append(m)
			var g := _g[idx] + 1
			_g.append(g)
			_push(Vector2i(g + _heuristic(child) * weight, _states.size() - 1))


func _build_path(idx: int) -> void:
	var rev: Array = []
	while _parent[idx] != -1:
		rev.append(_move[idx])
		idx = _parent[idx]
	rev.reverse()
	path = rev


static func _heuristic(s: PuzzleState) -> int:
	var h := 0
	for b in s.bottles:
		for i in range(1, b.size()):
			if b[i] != b[i - 1]:
				h += 1
	return h


func _less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y > b.y)


func _push(e: Vector2i) -> void:
	_heap.append(e)
	var i := _heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if _less(_heap[i], _heap[p]):
			var tmp = _heap[i]
			_heap[i] = _heap[p]
			_heap[p] = tmp
			i = p
		else:
			break


func _pop() -> Vector2i:
	var top: Vector2i = _heap[0]
	var last: Vector2i = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		var i := 0
		var n := _heap.size()
		while true:
			var l := 2 * i + 1
			var r := l + 1
			var m := i
			if l < n and _less(_heap[l], _heap[m]):
				m = l
			if r < n and _less(_heap[r], _heap[m]):
				m = r
			if m == i:
				break
			var tmp = _heap[i]
			_heap[i] = _heap[m]
			_heap[m] = tmp
			i = m
	return top
