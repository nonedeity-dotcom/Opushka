## Стрелки у края экрана: куда уплыла выпавшая часть (золотая) и откуда идёт хищник
## (красная, только с глазками — без глаз клетка его не видит).
extends Control

var enabled := true
## Где можно рисовать стрелки: без верхних плашек и нижних кнопок.
var margin := Rect2()
## [{at — точка на экране, kind — "part"/"danger", part}]
var targets: Array = []
var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	if not enabled or margin.size.x <= 0:
		return
	var box := margin.grow(-30)
	var mid := box.get_center()
	for tg in targets:
		var at: Vector2 = tg.at
		if Rect2(Vector2.ZERO, size).grow(-10).has_point(at):
			continue
		var dir := (at - mid).normalized()
		# Точка на краю прямоугольника по направлению к цели.
		var kx := (box.size.x / 2.0) / maxf(absf(dir.x), 0.001)
		var ky := (box.size.y / 2.0) / maxf(absf(dir.y), 0.001)
		var p := mid + dir * minf(kx, ky)
		var danger: bool = tg.kind == "danger"
		var col := Art.DANGER if danger else Art.GOLD
		var pulse := 0.75 + 0.25 * sin(t * (8.0 if danger else 4.0))
		draw_circle(p, 26, Color(0.04, 0.07, 0.09, 0.8))
		draw_arc(p, 26, 0, TAU, 32, Color(col, pulse), 3, true)
		var tip := p + dir * 38
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip, p + dir * 26 + side * 10, p + dir * 26 - side * 10]), Color(col, pulse))
		if danger:
			draw_string(get_theme_default_font(), p + Vector2(-6, 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		else:
			CellArt.part_icon(self, tg.part, Rect2(p - Vector2(17, 17), Vector2(34, 34)), Color("#9aa4b0"), t)
