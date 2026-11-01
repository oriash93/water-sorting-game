class_name BottleView
extends Control

signal tapped(index: int)

enum HintRole { NONE, POUR_FROM, POUR_INTO }

const LIFT_PADDING := 70.0
const GLASS_EXTRA_HEIGHT := 24.0
const GLASS_SIDE_INSET := 4.0
const LAYER_INSET := 12.0
const FLOOR_MARGIN := 12.0
const LIP_HEIGHT := 16.0
const SHAKE_DISTANCE := 14.0
const MAX_LAYERS := 8
const LETTERS := "ABCDEFGHIJKLMNOP"
const LIQUID_SHADER := preload("res://ui/bottle_liquid.gdshader")

var index := 0
var capacity := 4
var layer_height := 100.0
var palette: Array = []
var show_symbols := false:
	set(value):
		show_symbols = value
		_refresh()

var layers: Array = []:
	set(value):
		layers = value
		_refresh()
## Liquid hidden from the top, in layers; animations use it to fill and drain smoothly.
var top_trim := 0.0:
	set(value):
		top_trim = value
		_refresh()
## Rotation in radians; positive tips the bottle clockwise.
var tilt := 0.0:
	set(value):
		tilt = value
		rotation = value
		_refresh()
var complete := false:
	set(value):
		complete = value
		_refresh()
var lift := 0.0:
	set(value):
		lift = value
		_refresh()
var shake_offset := 0.0:
	set(value):
		shake_offset = value
		_refresh()
var hint_role: HintRole = HintRole.NONE:
	set(value):
		hint_role = value
		_refresh()

var _visual: Control
var _liquid: ColorRect
var _overlay: Control
var _glass_style := StyleBoxFlat.new()
var _rim_style := StyleBoxFlat.new()
var _lip_style := StyleBoxFlat.new()
var _lift_tween: Tween
var _shake_tween: Tween
var _refresh_pending := false


func _init() -> void:
	_glass_style.bg_color = Color(1, 1, 1, 0.07)
	_rim_style.draw_center = false
	_rim_style.set_border_width_all(5)
	_lip_style.draw_center = false
	_lip_style.set_border_width_all(4)
	_lip_style.set_corner_radius_all(LIP_HEIGHT / 2.0)
	for style in [_glass_style, _rim_style]:
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 44
		style.corner_radius_bottom_right = 44

	_visual = Control.new()
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.draw.connect(_draw_glass)
	add_child(_visual)
	_liquid = ColorRect.new()
	_liquid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var liquid_material := ShaderMaterial.new()
	liquid_material.shader = LIQUID_SHADER
	_liquid.material = liquid_material
	_visual.add_child(_liquid)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_visual.add_child(_overlay)


func setup(bottle_capacity: int, bottle_width: float, new_layer_height: float) -> void:
	capacity = bottle_capacity
	layer_height = new_layer_height
	size = Vector2(bottle_width, LIFT_PADDING + capacity * layer_height + GLASS_EXTRA_HEIGHT)
	custom_minimum_size = size
	for child in [_visual, _liquid, _overlay]:
		child.size = size
	_refresh()


## Rectangle the liquid can occupy, in local coordinates.
func interior_rect() -> Rect2:
	return Rect2(LAYER_INSET, LIFT_PADDING + GLASS_EXTRA_HEIGHT - FLOOR_MARGIN,
			size.x - LAYER_INSET * 2.0, capacity * layer_height)


## Point on the rim where liquid pours over when tipped toward `side` (+1 right, -1 left).
func lip_point(side: int) -> Vector2:
	return Vector2(size.x - GLASS_SIDE_INSET if side > 0 else GLASS_SIDE_INSET, LIFT_PADDING + 2.0)


## Y of the liquid surface in the parent's coordinates while the bottle is upright.
func liquid_top_y() -> float:
	return position.y + interior_rect().end.y - (layers.size() - top_trim) * layer_height


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


## Many properties change in one frame during animations; redraw once, at the end of it.
func _refresh() -> void:
	if _visual == null or _refresh_pending:
		return
	_refresh_pending = true
	_apply_refresh.call_deferred()


func _apply_refresh() -> void:
	_refresh_pending = false
	_visual.position = Vector2(shake_offset, -lift)
	_visual.queue_redraw()
	_overlay.queue_redraw()
	_update_liquid()


func _update_liquid() -> void:
	if palette.is_empty() or layers.size() > MAX_LAYERS or size.x <= 0.0:
		return
	var volumes: Array = []
	volumes.resize(layers.size())
	var remaining_trim := top_trim
	for layer_index in range(layers.size() - 1, -1, -1):
		var trimmed := minf(1.0, remaining_trim)
		remaining_trim -= trimmed
		volumes[layer_index] = 1.0 - trimmed
	var rect := interior_rect()
	var up := LiquidMath.up_vector(rotation)
	var bounds := LiquidMath.layer_bounds(rect, up, volumes, rect.size.x * layer_height)
	while bounds.size() < MAX_LAYERS + 1:
		bounds.append(bounds[bounds.size() - 1])
	var colors := PackedColorArray()
	for layer_index in MAX_LAYERS:
		colors.append(palette[layers[layer_index]] if layer_index < layers.size() else Color.BLACK)

	var liquid_material := _liquid.material as ShaderMaterial
	liquid_material.set_shader_parameter("body_size", size)
	liquid_material.set_shader_parameter("interior", Vector4(rect.position.x, rect.position.y, rect.end.x, rect.end.y))
	liquid_material.set_shader_parameter("up", up)
	liquid_material.set_shader_parameter("layer_count", layers.size())
	liquid_material.set_shader_parameter("layer_colors", colors)
	liquid_material.set_shader_parameter("layer_bounds", bounds)


func _glass_rect() -> Rect2:
	return Rect2(GLASS_SIDE_INSET, LIFT_PADDING, size.x - GLASS_SIDE_INSET * 2.0,
			capacity * layer_height + GLASS_EXTRA_HEIGHT)


func _draw_glass() -> void:
	_visual.draw_style_box(_glass_style, _glass_rect())


func _draw_overlay() -> void:
	var rim_color := Color(1, 1, 1, 0.55)
	if hint_role == HintRole.POUR_FROM:
		rim_color = Color("#FFD60A")
	elif hint_role == HintRole.POUR_INTO:
		rim_color = Color("#30D158")
	elif complete:
		rim_color = Color("#FFC53D")
	_rim_style.border_color = rim_color
	_lip_style.border_color = rim_color
	_overlay.draw_style_box(_rim_style, _glass_rect())
	_overlay.draw_style_box(_lip_style, Rect2(0, LIFT_PADDING - LIP_HEIGHT / 2.0, size.x, LIP_HEIGHT))

	if show_symbols and is_zero_approx(tilt) and is_zero_approx(top_trim):
		var rect := interior_rect()
		for layer_index in layers.size():
			var center_y := rect.end.y - (layer_index + 0.5) * layer_height
			_overlay.draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, center_y + 16.0),
					LETTERS[layers[layer_index]], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 44, Color(0, 0, 0, 0.6))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(index)
		accept_event()
