## Значки интерфейса. Рисуются фигурами — у шрифта таких значков нет, а картинки-файлы
## здесь не заводим.
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
		"close":
			ci.draw_line(Vector2(24, 24), Vector2(76, 76), col, 9, true)
			ci.draw_line(Vector2(76, 24), Vector2(24, 76), col, 9, true)
		"flag":
			ci.draw_line(Vector2(28, 14), Vector2(28, 88), col, w)
			Art.poly(ci, [Vector2(28, 16), Vector2(78, 28), Vector2(28, 50)], col)
		"check":
			ci.draw_polyline(PackedVector2Array([Vector2(18, 52), Vector2(40, 74), Vector2(82, 28)]), col, 10, true)
		"dna":
			# Двойная спираль: две волны и перекладины между ними.
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 17:
				var y := 10.0 + i * 5.0
				var x := sin(i * 0.55) * 22.0
				left.append(Vector2(50 + x, y))
				right.append(Vector2(50 - x, y))
				if i % 2 == 1:
					ci.draw_line(Vector2(50 + x, y), Vector2(50 - x, y), Color(col, 0.6), 4)
			ci.draw_polyline(left, col, 7, true)
			ci.draw_polyline(right, col, 7, true)
		"dash":
			Art.poly(ci, [Vector2(40, 20), Vector2(84, 50), Vector2(40, 80), Vector2(52, 50)], col)
			for y in [34.0, 50.0, 66.0]:
				ci.draw_line(Vector2(12, y), Vector2(36, y), Color(col, 0.7), 6, true)
		"book":
			Art.poly(ci, [Vector2(12, 22), Vector2(48, 28), Vector2(48, 84), Vector2(12, 78)], col)
			Art.poly(ci, [Vector2(88, 22), Vector2(52, 28), Vector2(52, 84), Vector2(88, 78)], col)
		"mirror":
			ci.draw_line(Vector2(50, 10), Vector2(50, 90), col, 5, true)
			Art.poly(ci, [Vector2(40, 30), Vector2(12, 50), Vector2(40, 70)], col)
			Art.poly(ci, [Vector2(60, 30), Vector2(88, 50), Vector2(60, 70)], Color(col, 0.5))
		"heart":
			Art.heart(ci, Vector2(50, 46), 60, col)
		"lock":
			ci.draw_rect(Rect2(24, 46, 52, 40), col)
			ci.draw_arc(Vector2(50, 46), 18, PI, TAU, 16, col, 8, true)
		"trash":
			ci.draw_rect(Rect2(24, 30, 52, 58), col, false, w)
			ci.draw_line(Vector2(16, 24), Vector2(84, 24), col, w)
			ci.draw_line(Vector2(40, 14), Vector2(60, 14), col, w)
			for x in [40.0, 60.0]:
				ci.draw_line(Vector2(x, 40), Vector2(x, 78), col, 5)
	Art.unpen(ci)
