class_name LiquidMath
extends RefCounted

## Geometry for liquid in a tilted bottle. Positions are in the bottle's local space.
## `up` is the world's up direction expressed in that space; liquid fills the region
## where dot(p, up) <= level, so the surface always stays level in the world.
## Volumes are measured in layers (one layer = `layer_area`).

const SOLVER_ITERATIONS := 24


static func corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


static func up_vector(rotation_radians: float) -> Vector2:
	return Vector2(0.0, -1.0).rotated(-rotation_radians)


## Area of the convex polygon where dot(p, up) <= level.
static func area_below(polygon: PackedVector2Array, up: Vector2, level: float) -> float:
	var clipped := PackedVector2Array()
	var count := polygon.size()
	for index in count:
		var current := polygon[index]
		var next := polygon[(index + 1) % count]
		var current_depth := up.dot(current) - level
		var next_depth := up.dot(next) - level
		if current_depth <= 0.0:
			clipped.append(current)
		if (current_depth < 0.0 and next_depth > 0.0) or (current_depth > 0.0 and next_depth < 0.0):
			clipped.append(current.lerp(next, current_depth / (current_depth - next_depth)))
	var area := 0.0
	for index in clipped.size():
		var current := clipped[index]
		var next := clipped[(index + 1) % clipped.size()]
		area += current.x * next.y - next.x * current.y
	return absf(area) * 0.5


static func lowest_level(polygon: PackedVector2Array, up: Vector2) -> float:
	var lowest := INF
	for point in polygon:
		lowest = minf(lowest, up.dot(point))
	return lowest


static func highest_level(polygon: PackedVector2Array, up: Vector2) -> float:
	var highest := -INF
	for point in polygon:
		highest = maxf(highest, up.dot(point))
	return highest


## Surface level at which the liquid below it has the given area.
static func level_for_area(polygon: PackedVector2Array, up: Vector2, area: float) -> float:
	var low := lowest_level(polygon, up)
	var high := highest_level(polygon, up)
	for _iteration in SOLVER_ITERATIONS:
		var middle := (low + high) * 0.5
		if area_below(polygon, up, middle) < area:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## Boundaries between stacked layers: bounds[0] is the bottle's lowest point and
## bounds[i + 1] is the surface level after layer i. `volumes` are in layers.
static func layer_bounds(rect: Rect2, up: Vector2, volumes: Array, layer_area: float) -> PackedFloat32Array:
	var polygon := corners(rect)
	var bounds := PackedFloat32Array()
	bounds.append(lowest_level(polygon, up))
	var cumulative := 0.0
	for volume in volumes:
		cumulative += volume
		bounds.append(level_for_area(polygon, up, cumulative * layer_area))
	return bounds


## Most liquid (in layers) the bottle can hold without spilling over its lip when
## rotated by `rotation_radians`. The lip is the top corner on `side` (+1 right, -1 left).
static func spill_capacity(rect: Rect2, side: int, rotation_radians: float, layer_area: float) -> float:
	var up := up_vector(rotation_radians)
	var lip := Vector2(rect.end.x if side > 0 else rect.position.x, rect.position.y)
	return area_below(corners(rect), up, up.dot(lip)) / layer_area


## spill_capacity sampled at evenly spaced tilt angles from 0 to `max_angle`.
static func spill_table(rect: Rect2, side: int, layer_area: float, max_angle: float, steps: int) -> PackedFloat32Array:
	var table := PackedFloat32Array()
	for step in steps:
		var angle := max_angle * float(step) / float(steps - 1)
		table.append(spill_capacity(rect, side, side * angle, layer_area))
	return table


## Tilt angle (>= 0) at which the bottle holds exactly `volume` layers right at its lip.
static func angle_for_volume(table: PackedFloat32Array, volume: float, max_angle: float) -> float:
	var last := table.size() - 1
	if volume >= table[0]:
		return 0.0
	if volume <= table[last]:
		return max_angle
	for step in last:
		if table[step + 1] <= volume:
			var span := table[step] - table[step + 1]
			var fraction := (table[step] - volume) / span if span > 0.0 else 0.0
			return max_angle * (float(step) + fraction) / float(last)
	return max_angle
