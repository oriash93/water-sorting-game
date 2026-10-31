extends SceneTree

## Run: Godot --headless --path . --script res://tests/run_tests.gd

var _failed := 0
var _passed := 0


func _init() -> void:
	_test_rules()
	_test_undo()
	_test_generator_deterministic()
	_test_generator_solvable()
	_test_solver_plays_to_win()
	_test_liquid_math()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", name)


func _make_state(bottles: Array, capacity: int = 4) -> PuzzleState:
	return PuzzleState.from_bottles(bottles, capacity)


func _test_rules() -> void:
	var state := _make_state([[0, 1, 1], [1, 0], [], [0, 0, 0, 0], [2, 2, 2, 2]])
	check(Rules.move_count(state, 0, 1) == 0, "top 1 onto top 0 is illegal")
	check(Rules.move_count(state, 0, 2) == 2, "whole run moves into empty")
	check(Rules.move_count(state, 1, 0) == 0, "0 onto 1 illegal")
	check(Rules.move_count(state, 2, 0) == 0, "empty source illegal")
	check(Rules.move_count(state, 1, 3) == 0, "onto full bottle illegal")
	check(not Rules.can_pour(state, 3, 2), "complete bottle into empty is useless")
	check(not Rules.is_solved(state), "not solved yet")
	check(Rules.is_selectable(state, 0), "bottle with mixed liquid is selectable")
	check(not Rules.is_selectable(state, 2), "empty bottle is not selectable")
	check(not Rules.is_selectable(state, 3), "complete bottle is not selectable")

	var merge_state := _make_state([[0, 0], [0, 0], [], []])
	check(not Rules.can_pour(merge_state, 0, 2), "uniform into empty is useless")
	check(Rules.can_pour(merge_state, 0, 1), "uniform merge onto same color is allowed")

	var partial_state := _make_state([[0, 1, 1, 1], [1, 1], []])
	check(Rules.move_count(partial_state, 0, 1) == 2, "run capped by free space")
	check(Rules.is_solved(_make_state([[0, 0, 0, 0], [], [1, 1, 1, 1]])), "solved detection")
	check(not Rules.is_solved(_make_state([[0, 0, 0], [0], []])), "split color not solved")


func _test_undo() -> void:
	var state := _make_state([[0, 1, 1], [1], []])
	var key_before := state.key()
	Rules.apply(state, 0, 1)
	check(state.bottles[1].size() == 3, "pour applied")
	Rules.undo(state)
	check(state.key() == key_before and state.bottles[0] == [0, 1, 1], "undo restores state")
	check(Rules.undo(state).is_empty(), "undo on empty history is a no-op")


func _test_generator_deterministic() -> void:
	var first := Generator.generate(LevelParams.for_level(12))
	var second := Generator.generate(LevelParams.for_level(12))
	check(first.bottles == second.bottles, "same level number generates the same puzzle")
	var other := Generator.generate(LevelParams.for_level(13))
	check(first.bottles != other.bottles, "different level numbers generate different puzzles")


func _test_generator_solvable() -> void:
	var all_ok := true
	for level_number in range(1, 31):
		var params := LevelParams.for_level(level_number)
		var state := Generator.generate(params)
		var color_counts := {}
		for bottle in state.bottles:
			for color in bottle:
				color_counts[color] = color_counts.get(color, 0) + 1
		for color in params.colors:
			if color_counts.get(color, 0) != params.capacity:
				all_ok = false
		if Rules.is_solved(state):
			all_ok = false
	check(all_ok, "levels 1-30 keep color counts and are not pre-solved")

	var solved_all := true
	for level_number in range(1, 16):
		var state := Generator.generate(LevelParams.for_level(level_number))
		if Solver.solve_sync(state).is_empty():
			solved_all = false
			print("  solver failed on level ", level_number)
	check(solved_all, "solver solves levels 1-15")


func _near(actual: float, expected: float, tolerance := 0.01) -> bool:
	return absf(actual - expected) <= tolerance


func _test_liquid_math() -> void:
	var layer_height := 100.0
	var rect := Rect2(10, 20, 150, 4 * layer_height)
	var layer_area := rect.size.x * layer_height
	var upright := LiquidMath.up_vector(0.0)

	var bounds := LiquidMath.layer_bounds(rect, upright, [1.0, 1.0, 1.0], layer_area)
	check(_near(bounds[1] - bounds[0], layer_height, 0.05), "upright first layer is one layer tall")
	check(_near(bounds[3] - bounds[0], 3.0 * layer_height, 0.05), "upright three layers are three layers tall")

	check(_near(LiquidMath.spill_capacity(rect, 1, 0.0, layer_area), 4.0, 0.001), "upright bottle holds its full capacity")
	check(_near(LiquidMath.spill_capacity(rect, 1, PI / 2.0, layer_area), 0.0, 0.001), "bottle on its side holds nothing")
	check(_near(LiquidMath.spill_capacity(rect, -1, -PI / 2.0, layer_area), 0.0, 0.001), "left lip on its side holds nothing")

	var max_angle := PI / 2.0 + 0.1
	var table := LiquidMath.spill_table(rect, 1, layer_area, max_angle, 48)
	var decreasing := true
	for step in range(1, table.size()):
		if table[step] > table[step - 1] + 0.0001:
			decreasing = false
	check(decreasing, "spill capacity only shrinks as the bottle tilts")
	check(LiquidMath.angle_for_volume(table, 4.0, max_angle) == 0.0, "a full bottle starts spilling at no tilt")
	check(LiquidMath.angle_for_volume(table, 0.0, max_angle) == max_angle, "emptying needs the maximum tilt")
	var angle := LiquidMath.angle_for_volume(table, 2.0, max_angle)
	check(_near(LiquidMath.spill_capacity(rect, 1, angle, layer_area), 2.0, 0.05), "angle for two layers spills exactly two layers")

	var tilted_up := LiquidMath.up_vector(0.7)
	var tilted_bounds := LiquidMath.layer_bounds(rect, tilted_up, [1.0, 1.0], layer_area)
	var level_area := LiquidMath.area_below(LiquidMath.corners(rect), tilted_up, tilted_bounds[2])
	check(_near(level_area, 2.0 * layer_area, 1.0), "tilted liquid keeps its volume")


func _test_solver_plays_to_win() -> void:
	var state := Generator.generate(LevelParams.for_level(10))
	var path := Solver.solve_sync(state)
	check(not path.is_empty(), "path found for level 10")
	for move in path:
		if Rules.apply(state, move.x, move.y).is_empty():
			check(false, "solver emitted an illegal move")
			return
	check(Rules.is_solved(state), "replaying solver path wins the level")
