class_name LevelParams
extends Resource

@export var colors: int = 4
@export var empties: int = 2
@export var capacity: int = 4
@export var steps: int = 40
@export var level_seed: int = 1


## Endless gentle ramp: more colors and more scrambling as the level number grows.
@warning_ignore("integer_division")
static func for_level(level_number: int) -> LevelParams:
	var params := LevelParams.new()
	params.colors = mini(3 + (level_number - 1) / 3, 12)
	params.empties = 2
	params.capacity = 4
	params.steps = params.colors * params.capacity * 6 + mini(level_number, 40)
	params.level_seed = level_number * 7919 + 13
	return params
