extends SceneTree

## Run: Godot --headless --path . --script res://tests/ui_playthrough.gd
## Drives the real game scene through taps using the solver, with a throwaway save file.

const TEST_SAVE := "user://test_save.json"

var _failed := 0


func _init() -> void:
	_run.call_deferred()


func check(condition: bool, name: String) -> void:
	if not condition:
		_failed += 1
		print("FAIL: ", name)
	else:
		print("ok: ", name)


func _remove_test_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func _write_test_save(contents: String) -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(contents)


func _make_game() -> Node:
	var game: Node = load("res://ui/game_screen.tscn").instantiate()
	game.save_path = TEST_SAVE
	root.add_child(game)
	return game


func _wait_idle(game: Node) -> void:
	var frames := 0
	while game.is_animating and frames < 600:
		await process_frame
		frames += 1


func _play(game: Node, moves: Array) -> void:
	for move in moves:
		game._on_tap(move.x)
		game._on_tap(move.y)
		await _wait_idle(game)


func _run() -> void:
	_remove_test_save()
	var game := _make_game()
	await process_frame
	check(game.level == 1, "starts at level 1")
	check(game.views.size() == game.state.bottles.size(), "one view per bottle")

	var path := Solver.solve_sync(game.state)
	check(not path.is_empty(), "solver finds a path for level 1")

	var key_before: String = game.state.key()
	await _play(game, [path[0]])
	check(game.state.history.size() == 1, "tap-tap pours via UI")
	game._on_undo()
	check(game.state.key() == key_before, "undo restores the start position")

	await _play(game, [path[0], path[1]])
	var mid_level_key: String = game.state.key()
	game._save()
	game.queue_free()
	await process_frame
	var restored_game := _make_game()
	await process_frame
	check(restored_game.state.key() == mid_level_key, "mid-level progress restored from save")

	var remaining_path := Solver.solve_sync(restored_game.state)
	await _play(restored_game, remaining_path)
	check(restored_game.has_won, "level won through UI")
	check(restored_game.win_overlay.visible, "win overlay shown")
	restored_game._on_next()
	check(restored_game.level == 2 and not restored_game.has_won, "next level starts level 2")

	var bottle_count_before: int = restored_game.views.size()
	restored_game._on_extra()
	check(restored_game.views.size() == bottle_count_before + 1 and restored_game.extra_bottle_used,
			"extra bottle adds one view")

	restored_game._on_hint()
	var frames := 0
	while restored_game.is_hinting and frames < 600:
		await process_frame
		frames += 1
	var hinted_views := 0
	for bottle_view in restored_game.views:
		if bottle_view.hint_role != BottleView.HintRole.NONE:
			hinted_views += 1
	check(hinted_views == 2, "hint highlights two bottles")

	var empty_index := -1
	for bottle_index in restored_game.state.bottles.size():
		if not Rules.is_selectable(restored_game.state, bottle_index):
			empty_index = bottle_index
	var shaken_view: BottleView = restored_game.views[empty_index]
	var home_x := shaken_view.position.x
	for _tap in 10:
		restored_game._on_tap(empty_index)
		await process_frame
	await create_timer(0.3).timeout
	check(shaken_view.position.x == home_x and shaken_view.shake_offset == 0.0,
			"rapid shakes never drift the bottle")

	restored_game.queue_free()
	await process_frame
	await _test_corrupt_saves()

	_remove_test_save()
	print("\nUI playthrough: ", "PASS" if _failed == 0 else "%d failed" % _failed)
	quit(1 if _failed > 0 else 0)


func _test_corrupt_saves() -> void:
	_write_test_save('{"version": 1, "level": 3, "extra": true, "moves": [[99, 0], "x", null]}')
	var game := _make_game()
	await process_frame
	check(game.level == 3 and game.state.history.is_empty(), "out-of-range saved moves are ignored")
	check(game.extra_bottle_used, "extra bottle flag kept when version matches")
	game.queue_free()
	await process_frame

	_write_test_save('{"version": 999, "level": 4, "extra": true, "moves": [[0, 1]]}')
	game = _make_game()
	await process_frame
	check(game.level == 4 and game.state.history.is_empty() and not game.extra_bottle_used,
			"save from another version keeps level but drops moves")
	game.queue_free()
	await process_frame

	_write_test_save("not json at all")
	game = _make_game()
	await process_frame
	check(game.level == 1, "garbage save falls back to level 1")
	game.queue_free()
	await process_frame

	_write_test_save('{"version": 1, "level": "high", "best": 5, "moves": "nope"}')
	game = _make_game()
	await process_frame
	check(game.level == 1, "wrongly typed fields fall back to defaults")
	game.queue_free()
	await process_frame
