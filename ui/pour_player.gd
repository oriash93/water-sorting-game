class_name PourPlayer
extends Node

## Plays one pour: the source bottle swings over the target, tips toward it until
## liquid spills over its lip, drains while the target fills, then returns home.
## The game state is already updated; this only animates the views.

signal finished(from_index: int, to_index: int)

const ENTER_SECONDS := 0.22
const EXIT_SECONDS := 0.18
const BASE_POUR_SECONDS := 0.14
const SECONDS_PER_LAYER := 0.08
const LIP_CLEARANCE := 60.0
const LIP_OFFSET_FRACTION := 0.3
const MAX_TILT := PI / 2.0 + 0.1
const TABLE_STEPS := 48
const RAISED_Z_INDEX := 20

var _tween: Tween
var _playing := false
var _source: BottleView
var _target: BottleView
var _stream: PourStream
var _from_index := 0
var _to_index := 0
var _layer_count := 0
var _color := Color.WHITE
var _side := 1
var _home_position := Vector2.ZERO
var _pour_position := Vector2.ZERO
var _start_lift := 0.0
var _initial_volume := 0.0
var _spill_table := PackedFloat32Array()
var _spill_start_angle := 0.0
var _pour_seconds := 0.0
var _total_seconds := 0.0


func is_playing() -> bool:
	return _playing


## `source` must hold the liquid from before the pour, `target` the liquid after it.
func play(source: BottleView, target: BottleView, stream: PourStream, move_record: Dictionary,
		screen_center_x: float) -> void:
	skip()
	_source = source
	_target = target
	_stream = stream
	_from_index = move_record.from
	_to_index = move_record.to
	_layer_count = move_record.count
	_color = source.palette[move_record.color]

	var source_center_x := source.position.x + source.size.x / 2.0
	var target_center_x := target.position.x + target.size.x / 2.0
	if absf(target_center_x - source_center_x) < 1.0:
		_side = -1 if source_center_x < screen_center_x else 1
	else:
		_side = 1 if target_center_x > source_center_x else -1

	var rect := source.interior_rect()
	_initial_volume = float(source.layers.size())
	_spill_table = LiquidMath.spill_table(rect, _side, rect.size.x * source.layer_height, MAX_TILT, TABLE_STEPS)
	_spill_start_angle = LiquidMath.angle_for_volume(_spill_table, _initial_volume, MAX_TILT)

	_start_lift = source.lift
	source.animate_lift(_start_lift, 0.0)
	source.pivot_offset = source.lip_point(_side)
	source.z_index = RAISED_Z_INDEX
	_home_position = source.position
	var lip_target := Vector2(
			target_center_x - _side * LIP_OFFSET_FRACTION * target.size.x,
			target.position.y + BottleView.LIFT_PADDING - LIP_CLEARANCE)
	_pour_position = lip_target - source.pivot_offset

	_pour_seconds = BASE_POUR_SECONDS + SECONDS_PER_LAYER * _layer_count
	_total_seconds = ENTER_SECONDS + _pour_seconds + EXIT_SECONDS
	target.top_trim = float(_layer_count)
	_playing = true
	_apply(0.0)
	_tween = create_tween()
	_tween.tween_method(_apply, 0.0, 1.0, _total_seconds)
	_tween.tween_callback(_complete)


## Jumps to the end of the animation.
func skip() -> void:
	if not _playing:
		return
	if _tween:
		_tween.kill()
	_apply(1.0)
	_complete()


func _apply(progress: float) -> void:
	var elapsed := progress * _total_seconds
	if elapsed < ENTER_SECONDS:
		var blend := _ease_out(elapsed / ENTER_SECONDS)
		_source.position = _home_position.lerp(_pour_position, blend)
		_source.lift = lerpf(_start_lift, 0.0, blend)
		_source.tilt = _side * _spill_start_angle * blend
		_stream.stop()
	elif elapsed < ENTER_SECONDS + _pour_seconds:
		var pour_progress := (elapsed - ENTER_SECONDS) / _pour_seconds
		_set_poured(smoothstep(0.0, 1.0, pour_progress) * _layer_count)
		_source.position = _pour_position
		_source.lift = 0.0
		var flow := smoothstep(0.0, 0.12, pour_progress) * (1.0 - smoothstep(0.85, 1.0, pour_progress))
		_stream.configure(_source.get_transform() * _source.lip_point(_side),
				Vector2(_target.position.x + _target.size.x / 2.0, _target.liquid_top_y()), _color, flow)
	else:
		var blend := smoothstep(0.0, 1.0, (elapsed - ENTER_SECONDS - _pour_seconds) / EXIT_SECONDS)
		_set_poured(float(_layer_count))
		_source.position = _pour_position.lerp(_home_position, blend)
		_source.tilt = _side * _end_angle() * (1.0 - blend)
		_stream.stop()


func _set_poured(poured: float) -> void:
	_source.top_trim = poured
	_target.top_trim = _layer_count - poured
	_source.tilt = _side * LiquidMath.angle_for_volume(_spill_table, _initial_volume - poured, MAX_TILT)


func _end_angle() -> float:
	return LiquidMath.angle_for_volume(_spill_table, _initial_volume - _layer_count, MAX_TILT)


func _complete() -> void:
	_playing = false
	_stream.stop()
	_source.pivot_offset = Vector2.ZERO
	_source.tilt = 0.0
	_source.position = _home_position
	_source.lift = 0.0
	_source.top_trim = 0.0
	_source.z_index = 0
	_target.top_trim = 0.0
	finished.emit(_from_index, _to_index)


static func _ease_out(value: float) -> float:
	return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 3.0)
