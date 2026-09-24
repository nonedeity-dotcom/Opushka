## Зверь на экране: стоит там, где его держат правила зверей, и рисуется по их состоянию.
extends Node2D

var animal: Animals.Animal
var _near := false

func refresh(near: bool) -> void:
	position = animal.pos * Art.TILE
	visible = not animal.gone
	_near = near
	queue_redraw()

func _draw() -> void:
	var s := Art.TILE * (0.7 if animal.kind == "bird" else 0.85)
	if _near:
		# Тот, к кому относится кнопка, — с мягким кругом под ногами.
		draw_arc(Vector2(0, 0), Art.TILE * 0.36, 0, TAU, 32, Color(0.95, 0.76, 0.42, 0.7), 2.5, true)
	Art.pen(self, Rect2(-s / 2.0, -s * 0.9, s, s))
	Art.animal(self, animal.kind, animal.facing, animal.phase, animal.moving, animal.lift)
	Art.unpen(self)
