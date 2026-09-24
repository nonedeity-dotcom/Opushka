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
		"ink":
			for q in [Vector2(36, 40), Vector2(62, 34), Vector2(50, 64), Vector2(28, 66), Vector2(72, 62)]:
				ci.draw_circle(q, 13, col)
		"shield":
			Art.poly(ci, [Vector2(50, 10), Vector2(86, 24), Vector2(80, 60), Vector2(50, 90), Vector2(20, 60), Vector2(14, 24)], col)
		"pulse":
			Art.poly(ci, [Vector2(56, 8), Vector2(24, 54), Vector2(46, 54), Vector2(38, 92), Vector2(76, 42), Vector2(54, 42)], col)
		"suck":
			for i in 3:
				ci.draw_arc(Vector2(50, 50), 14 + i * 13, i * 1.2, i * 1.2 + 4.2, 16, col, 6, true)
		"skull":
			ci.draw_circle(Vector2(50, 44), 30, col)
			ci.draw_rect(Rect2(34, 60, 32, 24), col)
			ci.draw_circle(Vector2(39, 44), 8, Art.BG)
			ci.draw_circle(Vector2(61, 44), 8, Art.BG)
		"trophy":
			Art.poly(ci, [Vector2(24, 14), Vector2(76, 14), Vector2(70, 46), Vector2(50, 60), Vector2(30, 46)], col)
			ci.draw_rect(Rect2(44, 58, 12, 18), col)
			ci.draw_rect(Rect2(30, 76, 40, 10), col)
		"tree":
			ci.draw_line(Vector2(50, 90), Vector2(50, 40), col, 7)
			ci.draw_line(Vector2(50, 60), Vector2(26, 34), col, 6)
			ci.draw_line(Vector2(50, 50), Vector2(74, 26), col, 6)
			for q in [Vector2(50, 30), Vector2(24, 28), Vector2(76, 20)]:
				ci.draw_circle(q, 10, col)
		"shop":
			# Ракушка-кошелёк: полукруг с рёбрами и застёжка.
			Art.poly(ci, [Vector2(14, 52), Vector2(86, 52), Vector2(78, 86), Vector2(22, 86)], col)
			ci.draw_arc(Vector2(50, 52), 26, PI, TAU, 20, col, 8, true)
			for x in [36.0, 50.0, 64.0]:
				ci.draw_line(Vector2(x, 58), Vector2(x, 80), Art.BG, 4)
		"sun":
			ci.draw_circle(Vector2(50, 50), 20, col)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(Vector2(50, 50) + d * 28, Vector2(50, 50) + d * 42, col, 7, true)
		"snow":
			for i in 3:
				var d := Vector2.from_angle(PI * i / 3.0)
				ci.draw_line(Vector2(50, 50) - d * 38, Vector2(50, 50) + d * 38, col, 7, true)
				for s in [-1.0, 1.0]:
					var tip: Vector2 = Vector2(50, 50) + d * 38 * s
					ci.draw_line(tip - d * 14 * s + d.orthogonal() * 9, tip - d * 4 * s, col, 5, true)
					ci.draw_line(tip - d * 14 * s - d.orthogonal() * 9, tip - d * 4 * s, col, 5, true)
		"plus":
			ci.draw_line(Vector2(50, 16), Vector2(50, 84), col, 12, true)
			ci.draw_line(Vector2(16, 50), Vector2(84, 50), col, 12, true)
		"leaf":
			Art.poly(ci, [Vector2(18, 82), Vector2(24, 40), Vector2(50, 18), Vector2(84, 14), Vector2(80, 48), Vector2(58, 76)], col)
			ci.draw_line(Vector2(18, 82), Vector2(70, 28), Art.BG, 4, true)
		"eye_off":
			Art.ellipse(ci, Vector2(50, 50), 38, 22, col)
			ci.draw_circle(Vector2(50, 50), 12, Art.BG)
			ci.draw_line(Vector2(18, 84), Vector2(82, 16), Art.BG, 12, true)
			ci.draw_line(Vector2(18, 84), Vector2(82, 16), col, 6, true)
	Art.unpen(ci)
