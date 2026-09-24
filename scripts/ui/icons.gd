## Значки интерфейса: шестерёнка, поворот, сумка, крестик, луна, солнце, флажок…
## Рисуются фигурами — у шрифта таких значков нет, а картинки-файлы здесь не заводим.
class_name Icons
extends RefCounted

static func draw(ci: CanvasItem, name: String, rect: Rect2, col: Color) -> void:
	Art.pen(ci, rect)
	var w := 7.0
	match name:
		"settings":
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(Vector2(50, 50) + d * 26, Vector2(50, 50) + d * 40, col, 12)
			ci.draw_arc(Vector2(50, 50), 24, 0, TAU, 32, col, 11, true)
			ci.draw_circle(Vector2(50, 50), 8, col)
		"rotate":
			ci.draw_rect(Rect2(32, 14, 36, 72), col, false, w)
			ci.draw_circle(Vector2(50, 76), 3.5, col)
			ci.draw_arc(Vector2(50, 50), 44, -PI * 0.85, -PI * 0.55, 10, col, 5, true)
			ci.draw_arc(Vector2(50, 50), 44, PI * 0.15, PI * 0.45, 10, col, 5, true)
		"bag":
			Art.poly(ci, [Vector2(16, 36), Vector2(84, 36), Vector2(80, 88), Vector2(20, 88)], col)
			ci.draw_arc(Vector2(50, 36), 16, PI, TAU, 16, col, w, true)
			ci.draw_rect(Rect2(40, 50, 20, 10), Art.BG)
		"close":
			ci.draw_line(Vector2(24, 24), Vector2(76, 76), col, 9, true)
			ci.draw_line(Vector2(76, 24), Vector2(24, 76), col, 9, true)
		"undo":
			ci.draw_arc(Vector2(52, 54), 28, -PI * 0.9, PI * 0.6, 20, col, w, true)
			Art.poly(ci, [Vector2(10, 30), Vector2(34, 22), Vector2(30, 48)], col)
		"sun":
			ci.draw_circle(Vector2(50, 50), 18, col)
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(Vector2(50, 50) + d * 28, Vector2(50, 50) + d * 40, col, 7)
		"moon":
			ci.draw_circle(Vector2(46, 50), 32, col)
			ci.draw_circle(Vector2(62, 40), 28, Color(0.07, 0.08, 0.1))
		"flag":
			ci.draw_line(Vector2(28, 14), Vector2(28, 88), col, w)
			Art.poly(ci, [Vector2(28, 16), Vector2(78, 28), Vector2(28, 50)], col)
		"check":
			ci.draw_polyline(PackedVector2Array([Vector2(18, 52), Vector2(40, 74), Vector2(82, 28)]), col, 10, true)
		"pin":
			ci.draw_circle(Vector2(50, 38), 22, col)
			Art.poly(ci, [Vector2(30, 46), Vector2(70, 46), Vector2(50, 88)], col)
			ci.draw_circle(Vector2(50, 38), 9, Art.BG)
		"tool":
			ci.draw_line(Vector2(24, 80), Vector2(62, 42), col, 10, true)
			ci.draw_arc(Vector2(68, 34), 18, -PI * 0.2, PI * 1.3, 16, col, 9, true)
	Art.unpen(ci)
