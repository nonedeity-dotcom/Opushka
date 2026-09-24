## Персонаж на экране. Стоит там, где говорят правила; фаза шага растёт от пройденного
## пути — ноги двигаются ровно столько, сколько он прошёл.
extends Node2D

var facing := Vector2.DOWN
var phase := 0.0
var moving := false
var color := Art.ACCENT

func place_at(pos_tiles: Vector2, facing_: Vector2, moved: float) -> void:
	position = pos_tiles * Art.TILE + Vector2(0, Art.TILE * 0.3)
	facing = facing_
	moving = moved > 0.0005
	if moving:
		phase = fmod(phase + moved * 1.6, 1.0)
	queue_redraw()

func _draw() -> void:
	var s := Art.TILE * 1.05
	Art.pen(self, Rect2(-s / 2.0, -s * 0.92, s, s))
	Art.player(self, facing, phase, moving, color)
	Art.unpen(self)
