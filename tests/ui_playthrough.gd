extends SceneTree

## Run: Godot --headless --path . --script res://tests/ui_playthrough.gd
## Drives the real game scene through taps using the solver, with a throwaway save file.

const TMP_SAVE := "user://test_save.json"

var _failed := 0


func _init() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if not cond:
		_failed += 1
		print("FAIL: ", name)
	else:
		print("ok: ", name)


func _make() -> Node:
	var game: Node = load("res://ui/game_screen.tscn").instantiate()
	game.save_path = TMP_SAVE
	root.add_child(game)
	return game


func _wait_idle(game: Node) -> void:
	var guard := 0
	while game.busy and guard < 600:
		await process_frame
		guard += 1


func _play(game: Node, path: Array) -> void:
	for m in path:
		game._on_tap(m.x)
		game._on_tap(m.y)
		await _wait_idle(game)


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	var game := _make()
	await process_frame
	check(game.level == 1, "starts at level 1")

	var path := Solver.solve_sync(game.state)
	check(not path.is_empty(), "solver finds a path for level 1")

	# undo a partial play, then confirm state restores
	var key_before: String = game.state.key()
	await _play(game, [path[0]])
	check(game.state.history.size() == 1, "tap-tap pours via UI")
	game._on_undo()
	check(game.state.key() == key_before, "undo restores the start position")

	# save/restore mid-level
	await _play(game, [path[0], path[1]])
	var mid_key: String = game.state.key()
	game._save()
	game.queue_free()
	await process_frame
	var game2 := _make()
	await process_frame
	check(game2.state.key() == mid_key, "mid-level progress restored from save")

	# finish the level through the UI
	var rest := Solver.solve_sync(game2.state)
	await _play(game2, rest)
	check(game2.won, "level won through UI")
	check(game2.win_overlay.visible, "win overlay shown")
	game2._on_next()
	check(game2.level == 2 and not game2.won, "next level starts level 2")

	# extra bottle
	var n_before: int = game2.views.size()
	game2._on_extra()
	check(game2.views.size() == n_before + 1 and game2.extra_used, "extra bottle adds one view")

	# hint produces a highlighted pair
	game2._on_hint()
	var guard := 0
	while game2.hinting and guard < 600:
		await process_frame
		guard += 1
	var hinted := 0
	for v in game2.views:
		if v.hint != 0:
			hinted += 1
	check(hinted == 2, "hint highlights two bottles")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	print("\nUI playthrough: ", "PASS" if _failed == 0 else "%d failed" % _failed)
	quit(1 if _failed > 0 else 0)
