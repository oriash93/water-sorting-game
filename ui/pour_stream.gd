class_name PourStream
extends Control

## A falling ribbon of liquid from a bottle's lip to the target's surface,
## drawn in the board's coordinate space.

const MAX_WIDTH := 16.0
const CURVE_STEPS := 18

var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _color := Color.WHITE
var _flow := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `flow` runs 0..1 and scales the ribbon's thickness.
func configure(start: Vector2, end: Vector2, color: Color, flow: float) -> void:
	_start = start
	_end = end
	_color = color
	_flow = flow
	queue_redraw()


func stop() -> void:
	_flow = 0.0
	queue_redraw()


func _draw() -> void:
	if _flow <= 0.01:
		return
	# Leaves the lip level, then accelerates downward, like a real pour.
	var drop := maxf(_end.y - _start.y, 8.0)
	var points := PackedVector2Array()
	for step in CURVE_STEPS + 1:
		var progress := float(step) / CURVE_STEPS
		points.append(Vector2(lerpf(_start.x, _end.x, progress), _start.y + drop * progress * progress))
	draw_polyline(points, _color, MAX_WIDTH * _flow, true)

	draw_set_transform(_end, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 26.0 * _flow, Color(_color, 0.45))
	draw_set_transform(Vector2.ZERO)
