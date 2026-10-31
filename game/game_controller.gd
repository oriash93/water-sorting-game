extends Control

const SAVE_VERSION := 1
const BACKGROUND_COLOR := Color("#1E2430")
const PALETTE: Array = [
	Color("#E74C3C"), Color("#3498DB"), Color("#2ECC71"), Color("#F1C40F"),
	Color("#9B59B6"), Color("#E67E22"), Color("#1ABC9C"), Color("#FD79A8"),
	Color("#8D6E63"), Color("#BDC3C7"), Color("#A3E635"), Color("#8E2B3A"),
]

const SELECT_LIFT := 36.0
const BOARD_SIDE_MARGIN := 40.0
const BOTTLE_GAP := 24.0
const MAX_BOTTLE_WIDTH := 170.0
const MAX_LAYER_HEIGHT := 110.0
const BUTTON_HEIGHT := 150.0
const BUTTON_BAR_HEIGHT := 200.0
const HINT_BUDGET_USEC := 6000
const HINT_NODE_LIMIT := 50000

var save_path := "user://save.json"
var level := 1
var state: PuzzleState
var views: Array[BottleView] = []
var selected_index := -1
var has_won := false
var extra_bottle_used := false
var best_moves_by_level := {}
var show_symbols := false
var is_hinting := false
var is_animating: bool:
	get:
		return pour_player != null and pour_player.is_playing()
var hint_solver: Solver

var board: Control
var pour_stream: PourStream
var pour_player: PourPlayer
var level_label: Label
var moves_label: Label
var toast_label: Label
var undo_button: Button
var hint_button: Button
var extra_button: Button
var restart_button: Button
var symbols_button: Button
var win_overlay: ColorRect
var win_title: Label
var win_info: Label
var _toast_tween: Tween
var _hint_token := 0


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	var save := _load_save()
	best_moves_by_level = save.best
	show_symbols = save.symbols
	_start_level(save.level, save.moves, save.extra)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null:
			_save()


# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	level_label = _make_label(84)
	moves_label = _make_label(40)
	moves_label.modulate = Color(1, 1, 1, 0.7)

	symbols_button = _make_button("Aa", Color("#3A4258"), 40)
	symbols_button.pressed.connect(_on_symbols)

	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	pour_stream = PourStream.new()
	pour_stream.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.add_child(pour_stream)
	pour_player = PourPlayer.new()
	pour_player.finished.connect(_on_pour_finished)
	add_child(pour_player)

	undo_button = _make_button("Undo", Color("#3A4258"), 42)
	undo_button.pressed.connect(_on_undo)
	hint_button = _make_button("Hint", Color("#2F7D5B"), 42)
	hint_button.pressed.connect(_on_hint)
	extra_button = _make_button("+ Bottle", Color("#8A5A2B"), 42)
	extra_button.pressed.connect(_on_extra)
	restart_button = _make_button("Restart", Color("#3A4258"), 42)
	restart_button.pressed.connect(_on_restart)

	toast_label = _make_label(40)
	toast_label.modulate.a = 0.0

	win_overlay = ColorRect.new()
	win_overlay.color = Color(0, 0, 0, 0.72)
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.visible = false
	add_child(win_overlay)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 40)
	center.add_child(box)
	win_title = Label.new()
	win_title.add_theme_font_size_override("font_size", 84)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_title)
	win_info = Label.new()
	win_info.add_theme_font_size_override("font_size", 52)
	win_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_info)
	var next_button := _make_button("Next level", Color("#2F7D5B"), 60, box)
	next_button.custom_minimum_size = Vector2(560, 170)
	next_button.pressed.connect(_on_next)


func _make_label(font_size: int, parent: Node = self) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _make_button(text: String, color: Color, font_size: int, parent: Node = self) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	var shades := {
		"normal": color,
		"hover": color.lightened(0.08),
		"pressed": color.darkened(0.2),
		"disabled": color.darkened(0.55),
	}
	for style_name in shades:
		var style := StyleBoxFlat.new()
		style.bg_color = shades[style_name]
		style.set_corner_radius_all(30)
		button.add_theme_stylebox_override(style_name, style)
	parent.add_child(button)
	return button


func _layout() -> void:
	if board == null:
		return
	var viewport_size := get_viewport_rect().size
	var top_inset := 0.0
	var bottom_inset := 0.0
	if OS.has_feature("mobile"):
		var window_size := DisplayServer.window_get_size()
		if window_size.x > 0:
			var scale_factor := viewport_size.x / window_size.x
			var safe_area := DisplayServer.get_display_safe_area()
			top_inset = maxf(0.0, safe_area.position.y * scale_factor)
			bottom_inset = maxf(0.0, (window_size.y - safe_area.end.y) * scale_factor)

	level_label.position = Vector2(0, top_inset + 40)
	level_label.size = Vector2(viewport_size.x, 100)
	moves_label.position = Vector2(0, top_inset + 140)
	moves_label.size = Vector2(viewport_size.x, 60)
	symbols_button.position = Vector2(viewport_size.x - 190, top_inset + 50)
	symbols_button.size = Vector2(150, 90)

	var button_gap := 20.0
	var button_width := (viewport_size.x - BOARD_SIDE_MARGIN * 2.0 - button_gap * 3.0) / 4.0
	var button_y := viewport_size.y - bottom_inset - BUTTON_BAR_HEIGHT
	var buttons: Array[Button] = [undo_button, hint_button, extra_button, restart_button]
	for button_index in buttons.size():
		buttons[button_index].position = Vector2(
				BOARD_SIDE_MARGIN + button_index * (button_width + button_gap), button_y)
		buttons[button_index].size = Vector2(button_width, BUTTON_HEIGHT)

	board.position = Vector2(0, top_inset + 230)
	board.size = Vector2(viewport_size.x, button_y - 30.0 - board.position.y)
	toast_label.position = Vector2(0, button_y - 100.0)
	toast_label.size = Vector2(viewport_size.x, 70)

	_layout_bottles()


@warning_ignore("integer_division")
func _layout_bottles() -> void:
	_settle_animation()
	var bottle_count := views.size()
	if bottle_count == 0:
		return
	var rows := 1 if bottle_count <= 5 else (2 if bottle_count <= 12 else 3)
	var columns := ceili(float(bottle_count) / rows)
	var available_width := board.size.x - BOARD_SIDE_MARGIN * 2.0
	var bottle_width := minf(MAX_BOTTLE_WIDTH,
			(available_width - (columns - 1) * BOTTLE_GAP) / columns)
	var max_capacity := 4
	for capacity in state.caps:
		max_capacity = maxi(max_capacity, capacity)
	var row_height := board.size.y / rows
	var layer_height := minf(MAX_LAYER_HEIGHT,
			(row_height - BottleView.LIFT_PADDING - 40.0) / max_capacity)
	for bottle_index in bottle_count:
		var row := bottle_index / columns
		var column := bottle_index % columns
		var bottles_in_row := mini(columns, bottle_count - row * columns)
		var row_width := bottles_in_row * bottle_width + (bottles_in_row - 1) * BOTTLE_GAP
		var bottle_view := views[bottle_index]
		bottle_view.setup(state.caps[bottle_index], bottle_width, layer_height)
		bottle_view.position = Vector2(
				(board.size.x - row_width) / 2.0 + column * (bottle_width + BOTTLE_GAP),
				row * row_height + (row_height - bottle_view.size.y) / 2.0)


# ---------- Level flow ----------

func _start_level(level_number: int, replay_moves: Array = [], with_extra_bottle := false) -> void:
	level = maxi(1, level_number)
	has_won = false
	selected_index = -1
	_cancel_hint()
	state = Generator.generate(LevelParams.for_level(level))
	extra_bottle_used = false
	if with_extra_bottle:
		state.add_bottle(state.caps[0])
		extra_bottle_used = true
	_replay_moves(replay_moves)
	win_overlay.visible = false
	_rebuild_views()
	_update_hud()
	if Rules.is_solved(state):
		_on_win()
	else:
		_save()


## Re-applies saved moves; stops at the first entry that is malformed or illegal.
func _replay_moves(saved_moves: Array) -> void:
	for entry in saved_moves:
		if not (entry is Array) or entry.size() != 2 or not _is_number(entry[0]) or not _is_number(entry[1]):
			return
		var from_index := int(entry[0])
		var to_index := int(entry[1])
		var bottle_count := state.bottles.size()
		if from_index < 0 or from_index >= bottle_count or to_index < 0 or to_index >= bottle_count:
			return
		if Rules.apply(state, from_index, to_index).is_empty():
			return


func _rebuild_views() -> void:
	for old_view in views:
		old_view.queue_free()
	views.clear()
	for bottle_index in state.bottles.size():
		var bottle_view := BottleView.new()
		bottle_view.index = bottle_index
		bottle_view.palette = PALETTE
		bottle_view.show_symbols = show_symbols
		bottle_view.tapped.connect(_on_tap)
		board.add_child(bottle_view)
		views.append(bottle_view)
	board.move_child(pour_stream, board.get_child_count() - 1)
	_layout()
	_refresh_all()


func _refresh_all() -> void:
	for bottle_index in views.size():
		var bottle_view := views[bottle_index]
		bottle_view.layers = (state.bottles[bottle_index] as Array).duplicate()
		bottle_view.top_trim = 0.0
		bottle_view.tilt = 0.0
		bottle_view.lift = 0.0
		bottle_view.hint_role = BottleView.HintRole.NONE
		bottle_view.complete = Rules.is_bottle_complete(state, bottle_index)


func _update_hud() -> void:
	level_label.text = "Level %d" % level
	var best_moves := _best_moves_for(level)
	var text := "Moves: %d" % state.history.size()
	if best_moves > 0:
		text += "   Best: %d" % best_moves
	moves_label.text = text
	undo_button.disabled = state.history.is_empty() or has_won
	hint_button.disabled = has_won
	extra_button.disabled = extra_bottle_used or has_won


func _best_moves_for(level_number: int) -> int:
	var value = best_moves_by_level.get(str(level_number))
	return int(value) if _is_number(value) else 0


# ---------- Input ----------

func _on_tap(tapped_index: int) -> void:
	_settle_animation()
	if has_won:
		return
	_clear_hint()
	if selected_index == -1:
		if Rules.is_selectable(state, tapped_index):
			_set_selected(tapped_index)
		else:
			views[tapped_index].shake()
		return
	if selected_index == tapped_index:
		_set_selected(-1)
		return
	if Rules.can_pour(state, selected_index, tapped_index):
		var from_index := selected_index
		selected_index = -1
		_do_pour(from_index, tapped_index)
		return
	views[selected_index].shake()
	_set_selected(-1)
	if Rules.is_selectable(state, tapped_index):
		_set_selected(tapped_index)


func _set_selected(bottle_index: int) -> void:
	if selected_index >= 0:
		views[selected_index].animate_lift(0.0)
	selected_index = bottle_index
	if bottle_index >= 0:
		views[bottle_index].animate_lift(SELECT_LIFT)


func _do_pour(from_index: int, to_index: int) -> void:
	var move_record := Rules.apply(state, from_index, to_index)
	if move_record.is_empty():
		return
	_cancel_hint()
	var source_view := views[from_index]
	var target_view := views[to_index]
	var layers_before := (state.bottles[from_index] as Array).duplicate()
	for _layer in int(move_record.count):
		layers_before.append(move_record.color)
	source_view.layers = layers_before
	target_view.layers = (state.bottles[to_index] as Array).duplicate()
	Input.vibrate_handheld(25)
	pour_player.play(source_view, target_view, pour_stream, move_record, board.size.x / 2.0)
	_update_hud()


func _on_pour_finished(from_index: int, to_index: int) -> void:
	_refresh_all()
	if Rules.is_solved(state):
		_on_win()
	else:
		_save()
		if Rules.legal_moves(state).is_empty():
			_show_toast("No moves left - try Undo" + ("" if extra_bottle_used else " or + Bottle"), 4.0)
	_update_hud()


## Finishes any running pour at once so the next action never waits on an animation.
func _settle_animation() -> void:
	pour_player.skip()


func _on_win() -> void:
	has_won = true
	var move_count := state.history.size()
	var previous_best := _best_moves_for(level)
	var is_new_best := previous_best == 0 or move_count < previous_best
	if is_new_best:
		best_moves_by_level[str(level)] = move_count
	win_title.text = "Level %d complete!" % level
	win_info.text = "%d moves%s" % [move_count, "  -  new best!" if (is_new_best and previous_best != 0) else ""]
	win_overlay.visible = true
	_save()
	_update_hud()


func _on_next() -> void:
	_start_level(level + 1)


func _on_undo() -> void:
	_settle_animation()
	if has_won or state.history.is_empty():
		return
	Rules.undo(state)
	selected_index = -1
	_cancel_hint()
	_refresh_all()
	_update_hud()
	_save()


func _on_restart() -> void:
	_settle_animation()
	_start_level(level)


func _on_extra() -> void:
	_settle_animation()
	if has_won or extra_bottle_used:
		return
	state.add_bottle(state.caps[0])
	extra_bottle_used = true
	selected_index = -1
	_cancel_hint()
	_rebuild_views()
	_update_hud()
	_save()


func _on_symbols() -> void:
	show_symbols = not show_symbols
	for bottle_view in views:
		bottle_view.show_symbols = show_symbols
	_save()


# ---------- Hint ----------

func _on_hint() -> void:
	_settle_animation()
	if has_won or is_hinting:
		return
	_clear_hint()
	_set_selected(-1)
	is_hinting = true
	hint_solver = Solver.new()
	hint_solver.max_nodes = HINT_NODE_LIMIT
	hint_solver.begin(state)
	_show_toast("Thinking...", 6.0)


func _process(_delta: float) -> void:
	if not is_hinting:
		return
	hint_solver.step(HINT_BUDGET_USEC)
	if not hint_solver.done:
		return
	is_hinting = false
	if hint_solver.solved and not hint_solver.path.is_empty():
		var hint_move: Vector2i = hint_solver.path[0]
		views[hint_move.x].hint_role = BottleView.HintRole.POUR_FROM
		views[hint_move.y].hint_role = BottleView.HintRole.POUR_INTO
		_show_toast("Yellow into green", 2.5)
		_hint_token += 1
		var token := _hint_token
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if token == _hint_token:
				_clear_hint())
	elif hint_solver.solved:
		_show_toast("Already solved", 1.5)
	else:
		_show_toast("No hint found - try Undo or + Bottle", 3.0)


func _cancel_hint() -> void:
	is_hinting = false
	_clear_hint()


func _clear_hint() -> void:
	_hint_token += 1
	for bottle_view in views:
		if is_instance_valid(bottle_view):
			bottle_view.hint_role = BottleView.HintRole.NONE


func _show_toast(text: String, seconds: float) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)


# ---------- Save ----------

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## Reads the save file defensively: anything missing or malformed falls back to defaults.
## Moves are only trusted when the save version matches the current generator.
func _load_save() -> Dictionary:
	var result := {"level": 1, "moves": [], "extra": false, "best": {}, "symbols": false}
	if not FileAccess.file_exists(save_path):
		return result
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return result
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return result
	var data: Dictionary = json.data
	if _is_number(data.get("level")):
		result.level = maxi(1, int(data.level))
	if data.get("best") is Dictionary:
		result.best = data.best
	result.symbols = data.get("symbols") == true
	if _is_number(data.get("version")) and int(data.version) == SAVE_VERSION and data.get("moves") is Array:
		result.moves = data.moves
		result.extra = data.get("extra") == true
	return result


func _save() -> void:
	var moves: Array = []
	if not has_won:
		for move_record in state.history:
			moves.append([move_record.from, move_record.to])
	var data := {
		"version": SAVE_VERSION,
		"level": level + 1 if has_won else level,
		"moves": moves,
		"extra": extra_bottle_used and not has_won,
		"best": best_moves_by_level,
		"symbols": show_symbols,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
