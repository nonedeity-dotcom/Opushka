## Стрелки у края экрана: куда уплыла выпавшая часть (золотая) и откуда идёт хищник
## (красная, только с глазками — без глаз клетка его не видит).
extends Control

var enabled := true
## Где можно рисовать стрелки: без верхних плашек и нижних кнопок.
var margin := Rect2()
## [{at — точка на экране, kind — "part"/"danger"/"mate"/"lair", part}]
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
			# Пара в тумане на экране: сердечко над ней, чтобы было видно, куда плыть.
			if tg.kind == "mate" and tg.get("hidden", false):
				var bob := sin(t * 3.0) * 6.0
				draw_circle(at + Vector2(0, bob), 22, Color(0.04, 0.07, 0.09, 0.6))
				Art.heart(self, at + Vector2(0, bob - 2), 26, Color("#f07aa8"))
			continue
		var dir := (at - mid).normalized()
		# Точка на краю прямоугольника по направлению к цели.
		var kx := (box.size.x / 2.0) / maxf(absf(dir.x), 0.001)
		var ky := (box.size.y / 2.0) / maxf(absf(dir.y), 0.001)
		var p := mid + dir * minf(kx, ky)
		var danger: bool = tg.kind == "danger"
		var lair: bool = tg.kind == "lair"
		var col := Art.DANGER if danger else (Color("#f07aa8") if tg.kind == "mate" else (Color("#c9a0ff") if lair else Art.GOLD))
		var pulse := 0.75 + 0.25 * sin(t * (8.0 if danger else 4.0))
		draw_circle(p, 26, Color(0.04, 0.07, 0.09, 0.8))
		draw_arc(p, 26, 0, TAU, 32, Color(col, pulse), 3, true)
		var tip := p + dir * 38
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([tip, p + dir * 26 + side * 10, p + dir * 26 - side * 10]), Color(col, pulse))
		if danger:
			draw_string(get_theme_default_font(), p + Vector2(-6, 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		elif tg.kind == "mate":
			Art.heart(self, p + Vector2(0, -2), 26, col)
		elif lair:
			Icons.draw(self, "skull", Rect2(p - Vector2(14, 14), Vector2(28, 28)), col)
		else:
			CellArt.part_icon(self, tg.part, Rect2(p - Vector2(17, 17), Vector2(34, 34)), Color("#9aa4b0"), t)
