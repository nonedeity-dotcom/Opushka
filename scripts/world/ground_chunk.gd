## Кусок земли 16×16 клеток. Рисуется один раз; кусок за экраном движок не рисует вовсе —
## поэтому земля порезана на куски, а не нарисована одной картинкой на весь мир.
extends Node2D

const CHUNK := 16

var world: Dictionary
var origin: Vector2i

func setup(world_: Dictionary, origin_: Vector2i) -> void:
	world = world_
	origin = origin_
	position = Vector2(origin) * Art.TILE

func _draw() -> void:
	var size: int = world.size
	var seed: int = world.seed
	for y in range(origin.y, mini(origin.y + CHUNK, size)):
		for x in range(origin.x, mini(origin.x + CHUNK, size)):
			var i := y * size + x
			var g: int = world.ground[i]
			var v := WorldGen.variant(seed, x, y)
			var r := Rect2(Vector2(x - origin.x, y - origin.y) * Art.TILE, Vector2(Art.TILE, Art.TILE))
			draw_rect(r.grow(0.5), Art.ground_color(g, v))
			if world.nature[i] == "" or g == WorldGen.Ground.WATER:
				Art.pen(self, r)
				Art.ground_decor(self, g, v)
				Art.unpen(self)
