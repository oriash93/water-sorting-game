extends Control

var save_path := "user://save.json"
const BG_COLOR := Color("#1E2430")
const PALETTE: Array = [
	Color("#E74C3C"), Color("#3498DB"), Color("#2ECC71"), Color("#F1C40F"),
	Color("#9B59B6"), Color("#E67E22"), Color("#1ABC9C"), Color("#FD79A8"),
	Color("#8D6E63"), Color("#BDC3C7"), Color("#A3E635"), Color("#8E2B3A"),
]

var level := 1
var state: PuzzleState
var views: Array = []
var selected := -1
var busy := false
var won := false
var extra_used := false
var best := {}
var symbols := false
var hinting := false
var hint_solver: Solver

var board: Control
var stream: ColorRect
var level_label: Label
var moves_label: Label
var toast: Label
var btn_undo: Button
var btn_hint: Button
var btn_extra: Button
var btn_restart: Button
var btn_symbols: Button
var win_overlay: ColorRect
var win_title: Label
var win_info: Label
var _toast_tween: Tween
var _hint_token := 0


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	var data := _load_save()
	best = data.get("best", {})
	symbols = bool(data.get("symbols", false))
	_start_level(int(data.get("level", 1)), data.get("moves", []), bool(data.get("extra", false)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null:
			_save()


# ---------- UI construction ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	level_label = _make_label(84)
	moves_label = _make_label(40)
	moves_label.modulate = Color(1, 1, 1, 0.7)

	btn_symbols = _make_button("Aa", Color("#3A4258"), 40)
	btn_symbols.pressed.connect(_on_symbols)

	board = Control.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	stream = ColorRect.new()
	stream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream.visible = false
	board.add_child(stream)

	btn_undo = _make_button("Undo", Color("#3A4258"), 42)
	btn_undo.pressed.connect(_on_undo)
	btn_hint = _make_button("Hint", Color("#2F7D5B"), 42)
	btn_hint.pressed.connect(_on_hint)
	btn_extra = _make_button("+ Bottle", Color("#8A5A2B"), 42)
	btn_extra.pressed.connect(_on_extra)
	btn_restart = _make_button("Restart", Color("#3A4258"), 42)
	btn_restart.pressed.connect(_on_restart)

	toast = _make_label(40)
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	win_overlay = ColorRect.new()
	win_overlay.color = Color(0, 0, 0, 0.72)
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.visible = false
	add_child(win_overlay)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 40)
	cc.add_child(box)
	win_title = Label.new()
	win_title.add_theme_font_size_override("font_size", 84)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_title)
	win_info = Label.new()
	win_info.add_theme_font_size_override("font_size", 52)
	win_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(win_info)
	var next := _make_button("Next level", Color("#2F7D5B"), 60, false)
	next.custom_minimum_size = Vector2(560, 170)
	next.pressed.connect(_on_next)
	box.add_child(next)


func _make_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _make_button(text: String, color: Color, font_size: int, attach := true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	var shades := {
		"normal": color,
		"hover": color.lightened(0.08),
		"pressed": color.darkened(0.2),
		"disabled": color.darkened(0.55),
	}
	for key in shades:
		var sb := StyleBoxFlat.new()
		sb.bg_color = shades[key]
		sb.set_corner_radius_all(30)
		b.add_theme_stylebox_override(key, sb)
	if attach:
		add_child(b)
	return b


func _layout() -> void:
	if board == null:
		return
	var vs := get_viewport_rect().size
	var top_inset := 0.0
	var bottom_inset := 0.0
	if OS.has_feature("mobile"):
		var win := DisplayServer.window_get_size()
		if win.x > 0:
			var k := vs.x / win.x
			var safe := DisplayServer.get_display_safe_area()
			top_inset = maxf(0.0, safe.position.y * k)
			bottom_inset = maxf(0.0, (win.y - safe.end.y) * k)

	level_label.position = Vector2(0, top_inset + 40)
	level_label.size = Vector2(vs.x, 100)
	moves_label.position = Vector2(0, top_inset + 140)
	moves_label.size = Vector2(vs.x, 60)
	btn_symbols.position = Vector2(vs.x - 190, top_inset + 50)
	btn_symbols.size = Vector2(150, 90)

	var btn_gap := 20.0
	var btn_w := (vs.x - 80.0 - btn_gap * 3.0) / 4.0
	var btn_y := vs.y - bottom_inset - 200.0
	var buttons: Array = [btn_undo, btn_hint, btn_extra, btn_restart]
	for i in buttons.size():
		var b: Button = buttons[i]
		b.position = Vector2(40.0 + i * (btn_w + btn_gap), btn_y)
		b.size = Vector2(btn_w, 150)

	board.position = Vector2(0, top_inset + 230)
	board.size = Vector2(vs.x, btn_y - 30.0 - board.position.y)
	toast.position = Vector2(0, btn_y - 100.0)
	toast.size = Vector2(vs.x, 70)

	_layout_bottles()


func _layout_bottles() -> void:
	var n := views.size()
	if n == 0:
		return
	var rows := 1 if n <= 5 else (2 if n <= 12 else 3)
	var cols := ceili(float(n) / rows)
	var gap := 24.0
	var avail_w := board.size.x - 80.0
	var bw := minf(170.0, (avail_w - (cols - 1) * gap) / cols)
	var cap := 4
	for c in state.caps:
		cap = maxi(cap, c)
	var row_h := board.size.y / rows
	var lh := minf(110.0, (row_h - BottleView.LIFT_PAD - 40.0) / cap)
	for i in n:
		var v: BottleView = views[i]
		var r := i / cols
		var c := i % cols
		var count_in_row := mini(cols, n - r * cols)
		var row_w := count_in_row * bw + (count_in_row - 1) * gap
		v.setup(state.caps[i], bw, lh)
		v.position = Vector2(
			(board.size.x - row_w) / 2.0 + c * (bw + gap),
			r * row_h + (row_h - v.size.y) / 2.0)


# ---------- Level flow ----------

func _start_level(n: int, replay: Array = [], extra := false) -> void:
	level = maxi(1, n)
	won = false
	busy = false
	selected = -1
	_cancel_hint()
	state = Generator.generate(LevelParams.for_level(level))
	extra_used = false
	if extra:
		state.add_bottle(state.caps[0])
		extra_used = true
	for m in replay:
		Rules.apply(state, int(m[0]), int(m[1]))
	win_overlay.visible = false
	_rebuild_views()
	_update_hud()
	_save()


func _rebuild_views() -> void:
	for v in views:
		v.queue_free()
	views.clear()
	for i in state.bottles.size():
		var v := BottleView.new()
		v.index = i
		v.palette = PALETTE
		v.show_symbols = symbols
		v.tapped.connect(_on_tap)
		board.add_child(v)
		views.append(v)
	board.move_child(stream, board.get_child_count() - 1)
	_layout()
	_refresh_all()


func _refresh_all() -> void:
	for i in views.size():
		var v: BottleView = views[i]
		v.layers = (state.bottles[i] as Array).duplicate()
		v.grow_n = 0
		v.drain_n = 0
		v.lift = 0.0
		v.hint = 0
		v.complete = Rules.is_complete(state.bottles[i], state.caps[i])


func _update_hud() -> void:
	level_label.text = "Level %d" % level
	var b: int = int(best.get(str(level), 0))
	moves_label.text = "Moves: %d" % state.history.size() + ("   Best: %d" % b if b > 0 else "")
	btn_undo.disabled = state.history.is_empty() or busy or won
	btn_hint.disabled = busy or won
	btn_extra.disabled = extra_used or busy or won
	btn_restart.disabled = busy


# ---------- Input ----------

func _on_tap(i: int) -> void:
	if busy or won:
		return
	_clear_hint()
	if selected == -1:
		if not (state.bottles[i] as Array).is_empty() and not Rules.is_complete(state.bottles[i], state.caps[i]):
			_set_selected(i)
		else:
			_shake(views[i])
		return
	if selected == i:
		_set_selected(-1)
		return
	if Rules.can_pour(state, selected, i):
		var from := selected
		selected = -1
		_do_pour(from, i)
	else:
		_shake(views[selected])
		_set_selected(-1)
		if not (state.bottles[i] as Array).is_empty() and not Rules.is_complete(state.bottles[i], state.caps[i]):
			_set_selected(i)


func _set_selected(i: int) -> void:
	if selected >= 0 and selected < views.size():
		create_tween().tween_property(views[selected], "lift", 0.0, 0.12)
	selected = i
	if i >= 0:
		create_tween().tween_property(views[i], "lift", 36.0, 0.12)


func _shake(v: BottleView) -> void:
	var x := v.position.x
	var tw := create_tween()
	tw.tween_property(v, "position:x", x + 14.0, 0.04)
	tw.tween_property(v, "position:x", x - 14.0, 0.08)
	tw.tween_property(v, "position:x", x, 0.04)


func _do_pour(f: int, t: int) -> void:
	var rec := Rules.apply(state, f, t)
	if rec.is_empty():
		return
	busy = true
	_cancel_hint()
	var vf: BottleView = views[f]
	var vt: BottleView = views[t]
	var n: int = rec.count
	vt.layers = (state.bottles[t] as Array).duplicate()
	vt.grow_n = n
	vt.grow_t = 0.0
	vf.layers = (state.bottles[f] as Array).duplicate()
	vf.drain_n = n
	vf.drain_color = rec.color
	vf.drain_t = 0.0
	vf.lift = 36.0

	var surface := vt.position.y + vt.size.y - 12.0 - vt.layers.size() * vt.layer_h
	var stream_top := vt.position.y + BottleView.LIFT_PAD - 110.0
	stream.color = PALETTE[rec.color]
	stream.position = Vector2(vt.position.x + vt.size.x / 2.0 - 9.0, stream_top)
	stream.size = Vector2(18, maxf(10.0, surface - stream_top))
	stream.visible = true
	Input.vibrate_handheld(25)

	var dur := 0.18 + 0.1 * n
	var tw := create_tween().set_parallel(true)
	tw.tween_property(vt, "grow_t", 1.0, dur)
	tw.tween_property(vf, "drain_t", 1.0, dur)
	tw.chain().tween_callback(_finish_pour.bind(f, t))
	_update_hud()


func _finish_pour(f: int, t: int) -> void:
	stream.visible = false
	var vf: BottleView = views[f]
	var vt: BottleView = views[t]
	vt.grow_n = 0
	vf.drain_n = 0
	create_tween().tween_property(vf, "lift", 0.0, 0.12)
	vf.complete = Rules.is_complete(state.bottles[f], state.caps[f])
	vt.complete = Rules.is_complete(state.bottles[t], state.caps[t])
	busy = false
	if Rules.is_solved(state):
		_on_win()
	else:
		_save()
	_update_hud()


func _on_win() -> void:
	won = true
	var mv := state.history.size()
	var prev: int = int(best.get(str(level), 0))
	var is_best := prev == 0 or mv < prev
	if is_best:
		best[str(level)] = mv
	win_title.text = "Level %d complete!" % level
	win_info.text = "%d moves%s" % [mv, "  -  new best!" if (is_best and prev != 0) else ""]
	win_overlay.visible = true
	_save()


func _on_next() -> void:
	_start_level(level + 1)


func _on_undo() -> void:
	if busy or won or state.history.is_empty():
		return
	Rules.undo(state)
	selected = -1
	_cancel_hint()
	_refresh_all()
	_update_hud()
	_save()


func _on_restart() -> void:
	if busy:
		return
	_start_level(level)


func _on_extra() -> void:
	if busy or won or extra_used:
		return
	state.add_bottle(state.caps[0])
	extra_used = true
	selected = -1
	_cancel_hint()
	_rebuild_views()
	_update_hud()
	_save()


func _on_symbols() -> void:
	symbols = not symbols
	for v in views:
		v.show_symbols = symbols
		v.queue_redraw()
	_save()


# ---------- Hint ----------

func _on_hint() -> void:
	if busy or won or hinting:
		return
	_clear_hint()
	_set_selected(-1)
	hinting = true
	hint_solver = Solver.new()
	hint_solver.max_nodes = 150000
	hint_solver.begin(state)
	_show_toast("Thinking...", 6.0)


func _process(_delta: float) -> void:
	if not hinting:
		return
	hint_solver.step(1500)
	if not hint_solver.done:
		return
	hinting = false
	if hint_solver.solved and not hint_solver.path.is_empty():
		var m: Vector2i = hint_solver.path[0]
		(views[m.x] as BottleView).hint = 1
		(views[m.y] as BottleView).hint = 2
		_show_toast("Yellow into green", 2.5)
		_hint_token += 1
		var token := _hint_token
		get_tree().create_timer(3.0).timeout.connect(func():
			if token == _hint_token:
				_clear_hint())
	elif hint_solver.solved:
		_show_toast("Already solved", 1.5)
	else:
		_show_toast("No hint found - try Undo or + Bottle", 3.0)


func _cancel_hint() -> void:
	hinting = false
	_clear_hint()


func _clear_hint() -> void:
	_hint_token += 1
	for v in views:
		if is_instance_valid(v):
			v.hint = 0


func _show_toast(text: String, secs: float) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(secs)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)


# ---------- Save ----------

func _load_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func _save() -> void:
	var moves: Array = []
	if not won:
		for r in state.history:
			moves.append([r.from, r.to])
	var data := {
		"level": level + 1 if won else level,
		"moves": moves,
		"extra": extra_used and not won,
		"best": best,
		"symbols": symbols,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
