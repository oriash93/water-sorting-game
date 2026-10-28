class_name BottleView
extends Control

signal tapped(index: int)

const LIFT_PAD := 70.0
const LETTERS := "ABCDEFGHIJKLMNOP"

var index := 0
var cap := 4
var layer_h := 100.0
var palette: Array = []
var show_symbols := false
var layers: Array = []

var complete := false:
	set(value):
		complete = value
		queue_redraw()
var lift := 0.0:
	set(value):
		lift = value
		queue_redraw()
var grow_n := 0
var grow_t := 1.0:
	set(value):
		grow_t = value
		queue_redraw()
var drain_n := 0
var drain_color := 0
var drain_t := 1.0:
	set(value):
		drain_t = value
		queue_redraw()
## 0 none, 1 pour from, 2 pour into
var hint := 0:
	set(value):
		hint = value
		queue_redraw()

var _glass := StyleBoxFlat.new()
var _rim := StyleBoxFlat.new()
var _fill_bottom := StyleBoxFlat.new()
var _fill := StyleBoxFlat.new()


func _init() -> void:
	_glass.bg_color = Color(1, 1, 1, 0.07)
	_glass.corner_radius_top_left = 10
	_glass.corner_radius_top_right = 10
	_glass.corner_radius_bottom_left = 44
	_glass.corner_radius_bottom_right = 44
	_rim.draw_center = false
	_rim.set_border_width_all(5)
	_rim.corner_radius_top_left = 10
	_rim.corner_radius_top_right = 10
	_rim.corner_radius_bottom_left = 44
	_rim.corner_radius_bottom_right = 44
	_fill_bottom.corner_radius_bottom_left = 34
	_fill_bottom.corner_radius_bottom_right = 34


func setup(capacity: int, width: float, layer_height: float) -> void:
	cap = capacity
	layer_h = layer_height
	size = Vector2(width, LIFT_PAD + cap * layer_h + 24.0)
	custom_minimum_size = size
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var top := LIFT_PAD - lift
	var h := cap * layer_h + 24.0
	var body := Rect2(0, top, w, h)
	draw_style_box(_glass, body)

	var inset := 10.0
	var y := top + h - 12.0
	for j in layers.size():
		var frac := 1.0
		if j >= layers.size() - grow_n:
			frac = grow_t
		var lh := layer_h * frac
		if lh <= 0.5:
			continue
		y -= lh
		_draw_layer(Rect2(inset, y, w - inset * 2.0, lh), layers[j], j == 0, true)
	if drain_n > 0:
		var dh := layer_h * drain_n * (1.0 - drain_t)
		if dh > 0.5:
			y -= dh
			_draw_layer(Rect2(inset, y, w - inset * 2.0, dh), drain_color, layers.is_empty(), false)

	var rim_color := Color(1, 1, 1, 0.55)
	if hint == 1:
		rim_color = Color("#FFD60A")
	elif hint == 2:
		rim_color = Color("#30D158")
	elif complete:
		rim_color = Color("#FFC53D")
	_rim.border_color = rim_color
	draw_style_box(_rim, body)


func _draw_layer(r: Rect2, color_id: int, is_bottom: bool, with_symbol: bool) -> void:
	var sb := _fill_bottom if is_bottom else _fill
	sb.bg_color = palette[color_id]
	draw_style_box(sb, r)
	if show_symbols and with_symbol and r.size.y > 40.0:
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 16.0),
				LETTERS[color_id], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 44, Color(0, 0, 0, 0.6))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index)
		accept_event()
