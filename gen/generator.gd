class_name Generator
extends RefCounted

## Builds a level by scrambling the solved state with reverse pours.
## Each reverse pour is the exact inverse of a legal forward pour, so every
## generated level is solvable by construction.


static func generate(p: LevelParams) -> PuzzleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = p.level_seed
	for attempt in 20:
		var s := _scramble(p, rng)
		if not Rules.is_solved(s):
			s.history = []
			return s
	push_error("Generator could not produce an unsolved level")
	return _scramble(p, rng)


static func _solved(p: LevelParams) -> PuzzleState:
	var s := PuzzleState.new()
	for c in p.colors:
		var i := s.add_bottle(p.capacity)
		for k in p.capacity:
			s.bottles[i].append(c)
	for e in p.empties:
		s.add_bottle(p.capacity)
	return s


static func _scramble(p: LevelParams, rng: RandomNumberGenerator) -> PuzzleState:
	var s := _solved(p)
	var last := Vector2i(-1, -1)
	for step in p.steps:
		var options := _reverse_moves(s)
		if options.is_empty():
			break
		# Avoid undoing the previous scramble step so levels get tangled.
		var filtered: Array = options.filter(func(o): return o.x != last.y or o.y != last.x)
		if not filtered.is_empty():
			options = filtered
		var pick: Vector3i = options[rng.randi_range(0, options.size() - 1)]
		var t: Array = s.bottles[pick.x]
		var f: Array = s.bottles[pick.y]
		var color: int = t[t.size() - 1]
		for i in pick.z:
			t.pop_back()
			f.append(color)
		last = Vector2i(pick.x, pick.y)
	return s


## Returns Vector3i(take_from, put_into, count) reverse pours.
## Forward pour (put_into -> take_from) of `count` layers must be legal and
## move exactly `count` layers, which needs:
##  - after removing count layers, the remaining top of take_from is empty or same color
##  - put_into has room and its top is not that color (so the forward run is exactly count)
##  - it is not a pointless bottle-to-empty move
static func _reverse_moves(s: PuzzleState) -> Array:
	var out: Array = []
	for t in s.bottles.size():
		var tb: Array = s.bottles[t]
		if tb.is_empty():
			continue
		var color: int = tb[tb.size() - 1]
		var run := Rules.top_run(tb)
		for m in range(1, run + 1):
			var remaining := tb.size() - m
			if remaining > 0 and tb[remaining - 1] != color:
				continue
			for f in s.bottles.size():
				if f == t:
					continue
				var fb: Array = s.bottles[f]
				if s.caps[f] - fb.size() < m:
					continue
				if not fb.is_empty() and fb[fb.size() - 1] == color:
					continue
				if fb.is_empty() and remaining == 0:
					continue
				out.append(Vector3i(t, f, m))
	return out
