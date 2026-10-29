class_name BottleView
extends Control

signal tapped(index: int)

enum HintRole { NONE, POUR_FROM, POUR_INTO }

const LIFT_PADDING := 70.0
const GLASS_EXTRA_HEIGHT := 24.0
const LAYER_INSET := 10.0
const FLOOR_MARGIN := 12.0
const SHAKE_DISTANCE := 14.0
const LETTERS := "ABCDEFGHIJKLMNOP"

var index := 0
var capacity := 4
var layer_height := 100.0
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
var shake_offset := 0.0:
	set(value):
		shake_offset = value
		queue_redraw()
var grow_count := 0
var grow_progress := 1.0:
	set(value):
		grow_progress = value
		queue_redraw()
var drain_count := 0
var drain_color := 0
var drain_progress := 1.0:
	set(value):
		drain_progress = value
		queue_redraw()
var hint_role: HintRole = HintRole.NONE:
	set(value):
		hint_role = value
		queue_redraw()

var _glass_style := StyleBoxFlat.new()
var _rim_style := StyleBoxFlat.new()
var _bottom_fill_style := StyleBoxFlat.new()
var _fill_style := StyleBoxFlat.new()
var _lift_tween: Tween
var _shake_tween: Tween


func _init() -> void:
	_glass_style.bg_color = Color(1, 1, 1, 0.07)
	_rim_style.draw_center = false
	_rim_style.set_border_width_all(5)
	for style in [_glass_style, _rim_style]:
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 44
		style.corner_radius_bottom_right = 44
	_bottom_fill_style.corner_radius_bottom_left = 34
	_bottom_fill_style.corner_radius_bottom_right = 34


func setup(bottle_capacity: int, bottle_width: float, new_layer_height: float) -> void:
	capacity = bottle_capacity
	layer_height = new_layer_height
	size = Vector2(bottle_width, LIFT_PADDING + capacity * layer_height + GLASS_EXTRA_HEIGHT)
	custom_minimum_size = size
	queue_redraw()


## Y of the liquid surface in the parent's coordinates, once all layers are poured in.
func surface_y() -> float:
	return position.y + size.y - FLOOR_MARGIN - layers.size() * layer_height


func animate_lift(target: float, duration := 0.12) -> void:
	if _lift_tween:
		_lift_tween.kill()
	if duration <= 0.0:
		lift = target
		return
	_lift_tween = create_tween()
	_lift_tween.tween_property(self, "lift", target, duration)


func shake() -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "shake_offset", SHAKE_DISTANCE, 0.04)
	_shake_tween.tween_property(self, "shake_offset", -SHAKE_DISTANCE, 0.08)
	_shake_tween.tween_property(self, "shake_offset", 0.0, 0.04)


func _draw() -> void:
	draw_set_transform(Vector2(shake_offset, 0.0))
	var body_height := capacity * layer_height + GLASS_EXTRA_HEIGHT
	var body_top := LIFT_PADDING - lift
	var body := Rect2(0, body_top, size.x, body_height)
	draw_style_box(_glass_style, body)

	var stack_top_y := body_top + body_height - FLOOR_MARGIN
	for layer_index in layers.size():
		var growth := 1.0
		if layer_index >= layers.size() - grow_count:
			growth = grow_progress
		var drawn_height := layer_height * growth
		if drawn_height <= 0.5:
			continue
		stack_top_y -= drawn_height
		_draw_layer(Rect2(LAYER_INSET, stack_top_y, size.x - LAYER_INSET * 2.0, drawn_height),
				layers[layer_index], layer_index == 0, true)
	if drain_count > 0:
		var drain_height := layer_height * drain_count * (1.0 - drain_progress)
		if drain_height > 0.5:
			stack_top_y -= drain_height
			_draw_layer(Rect2(LAYER_INSET, stack_top_y, size.x - LAYER_INSET * 2.0, drain_height),
					drain_color, layers.is_empty(), false)

	var rim_color := Color(1, 1, 1, 0.55)
	if hint_role == HintRole.POUR_FROM:
		rim_color = Color("#FFD60A")
	elif hint_role == HintRole.POUR_INTO:
		rim_color = Color("#30D158")
	elif complete:
		rim_color = Color("#FFC53D")
	_rim_style.border_color = rim_color
	draw_style_box(_rim_style, body)


func _draw_layer(rect: Rect2, color_id: int, is_bottom: bool, with_symbol: bool) -> void:
	var style := _bottom_fill_style if is_bottom else _fill_style
	style.bg_color = palette[color_id]
	draw_style_box(style, rect)
	if show_symbols and with_symbol and rect.size.y > 40.0:
		draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + 16.0),
				LETTERS[color_id], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 44, Color(0, 0, 0, 0.6))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index)
		accept_event()
