extends Node

## Visual check of a pour. Run windowed with the movie writer, e.g.:
## Godot --path . res://tests/pour_capture.tscn --write-movie out.png --fixed-fps 30 --quit-after 50 -- level=1 from=0 to=1
## Omit from/to to play the solver's first move. Uses a throwaway save file.

const CAPTURE_SAVE := "user://capture_save.json"
const TAP_FRAME := 6

var _game: Node
var _from_index := -1
var _to_index := -1
var _frame := 0


func _ready() -> void:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=")
		if parts.size() == 2:
			args[parts[0]] = int(parts[1])
	var file := FileAccess.open(CAPTURE_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "level": args.get("level", 1), "moves": [], "extra": args.get("extra", 0) == 1, "symbols": args.get("symbols", 0) == 1}))
	file.close()
	_game = load("res://ui/game_screen.tscn").instantiate()
	_game.save_path = CAPTURE_SAVE
	add_child(_game)
	_from_index = args.get("from", -1)
	_to_index = args.get("to", -1)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == TAP_FRAME:
		if _from_index < 0:
			var path := Solver.solve_sync(_game.state)
			_from_index = path[0].x
			_to_index = path[0].y
		_game._on_tap(_from_index)
	elif _frame == TAP_FRAME + 2:
		_game._on_tap(_to_index)
