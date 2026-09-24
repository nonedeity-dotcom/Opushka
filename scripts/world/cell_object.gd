## То, что стоит на клетке: дерево, куст, камни, ветки или постройка.
##
## Узел стоит в нижней середине клетки: по этой точке движок решает, кто кого загораживает,
## и персонаж, зашедший за дерево, оказывается за ним, а не поверх кроны.
extends Node2D

var cell: Vector2i
var nature := ""
var structure := ""
var depleted := false
var lit := false
var v := 0
## Качание после удара: затухает само.
var shake := 0.0
var _flicker := 0.0

func setup(c: Vector2i, variant: int) -> void:
	cell = c
	v = variant
	position = Vector2(c.x + 0.5, c.y + 1.0) * Art.TILE

## Привести к тому, что сейчас на клетке. true — если что-то поменялось.
func sync(info: Dictionary, night: bool) -> bool:
	var n: String = info.get("nature", "")
	var s: String = info.get("built", "")
	var d: bool = info.get("depleted", false)
	var l: bool = night and s != "" and Content.STRUCTURES[s].has("light")
	if n == nature and s == structure and d == depleted and l == lit:
		return false
	nature = n
	structure = s
	depleted = d
	lit = l
	set_process(structure == "campfire" or shake > 0.0)
	queue_redraw()
	return true

func hit() -> void:
	shake = 1.0
	set_process(true)

func _process(delta: float) -> void:
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
	if structure == "campfire":
		_flicker = sin(Time.get_ticks_msec() / 90.0) * 0.5 + sin(Time.get_ticks_msec() / 37.0) * 0.3
	if shake <= 0.0 and structure != "campfire":
		set_process(false)
	queue_redraw()

func _draw() -> void:
	var sway := sin(shake * 18.0) * shake * 8.0
	Art.pen(self, Rect2(-Art.TILE / 2.0, -Art.TILE, Art.TILE, Art.TILE))
	if structure != "":
		Art.structure(self, structure, lit, _flicker)
	elif nature != "":
		Art.nature(self, nature, depleted, v, sway)
	Art.unpen(self)
