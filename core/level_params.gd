class_name LevelParams
extends Resource

@export var colors: int = 4
@export var empties: int = 2
@export var capacity: int = 4
@export var steps: int = 40
@export var level_seed: int = 1


## Endless gentle ramp: more colors and more scrambling as the level number grows.
static func for_level(n: int) -> LevelParams:
	var p := LevelParams.new()
	p.colors = mini(3 + (n - 1) / 3, 12)
	p.empties = 2
	p.capacity = 4
	p.steps = p.colors * p.capacity * 3 + mini(n, 40)
	p.level_seed = n * 7919 + 13
	return p
