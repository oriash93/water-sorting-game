extends SceneTree

## Run: Godot --headless --path . --script res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _init() -> void:
	_test_rules()
	_test_undo()
	_test_generator_solvable()
	_test_solver_plays_to_win()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _state(bottles: Array, cap: int = 4) -> PuzzleState:
	return PuzzleState.from_bottles(bottles, cap)


func _test_rules() -> void:
	var s := _state([[0, 1, 1], [1, 0], [], [0, 0, 0, 0], [2, 2, 2, 2]])
	check(Rules.move_count(s, 0, 1) == 0, "top 1 onto top 0 is illegal")
	check(Rules.move_count(s, 0, 2) == 2, "whole run moves into empty")
	check(Rules.move_count(s, 1, 0) == 0, "0 onto 1 illegal")
	check(Rules.move_count(s, 2, 0) == 0, "empty source illegal")
	check(Rules.move_count(s, 1, 3) == 0, "onto full bottle illegal")
	check(not Rules.can_pour(s, 3, 2), "complete bottle into empty is useless")
	check(not Rules.is_solved(s), "not solved yet")
	var t := _state([[0, 0], [0, 0], [], []])
	check(not Rules.can_pour(t, 0, 2), "uniform into empty is useless")
	check(Rules.can_pour(t, 0, 1), "uniform merge onto same color is allowed")
	var partial := _state([[0, 1, 1, 1], [1, 1], []])
	check(Rules.move_count(partial, 0, 1) == 2, "run capped by free space")
	check(Rules.is_solved(_state([[0, 0, 0, 0], [], [1, 1, 1, 1]])), "solved detection")
	check(not Rules.is_solved(_state([[0, 0, 0], [0], []])), "split color not solved")


func _test_undo() -> void:
	var s := _state([[0, 1, 1], [1], []])
	var before := s.key()
	Rules.apply(s, 0, 1)
	check(s.bottles[1].size() == 3, "pour applied")
	Rules.undo(s)
	check(s.key() == before and s.bottles[0] == [0, 1, 1], "undo restores state")
	check(Rules.undo(s).is_empty(), "undo on empty history is a no-op")


func _test_generator_solvable() -> void:
	var all_ok := true
	for n in range(1, 31):
		var p := LevelParams.for_level(n)
		var s := Generator.generate(p)
		var counts := {}
		for b in s.bottles:
			for c in b:
				counts[c] = counts.get(c, 0) + 1
		for c in p.colors:
			if counts.get(c, 0) != p.capacity:
				all_ok = false
		if Rules.is_solved(s):
			all_ok = false
	check(all_ok, "levels 1-30 keep color counts and are not pre-solved")

	var solved_all := true
	for n in range(1, 16):
		var s := Generator.generate(LevelParams.for_level(n))
		var path := Solver.solve_sync(s)
		if path.is_empty():
			solved_all = false
			print("  solver failed on level ", n)
	check(solved_all, "solver solves levels 1-15")


func _test_solver_plays_to_win() -> void:
	var s := Generator.generate(LevelParams.for_level(10))
	var path := Solver.solve_sync(s)
	check(not path.is_empty(), "path found for level 10")
	for m in path:
		var rec := Rules.apply(s, m.x, m.y)
		if rec.is_empty():
			check(false, "solver emitted an illegal move")
			return
	check(Rules.is_solved(s), "replaying solver path wins the level")
