## Значки частей суши — рисуются фигурами в квадрате 100×100, цветные: тело — цветом
## вида, кость и рог — костяным, клюв — жёлтым. Так часть узнаётся с одного взгляда.
class_name LandIcons
extends RefCounted

const BONE := Color("#efe6cf")
const DARK := Color("#1e1e28")
const HORN := Color("#f0b040")

## Каким значком рисовать место тела, если на нём пусто.
const SLOT_ICON := {"body": "body", "mouth": "jaws", "eyes": "eyes", "legs": "legs4", "feet": "paws", "claws": "claws",
	"arms": "arms", "back": "back_spikes", "tail": "tail_long", "head": "horns", "skin": "scales"}

static func draw(ci: CanvasItem, id: String, rect: Rect2, c: Color, c2: Color) -> void:
	Art.pen(ci, rect)
	match id:
		"body":
			# Существо сбоку: туловище, голова, хвост, ножки.
			Art.ellipse(ci, Vector2(48, 52), 30, 20, c)
			ci.draw_circle(Vector2(78, 40), 14, c)
			Art.poly(ci, [Vector2(22, 48), Vector2(4, 40), Vector2(20, 60)], c)
			for x in [34.0, 60.0]:
				ci.draw_line(Vector2(x, 66), Vector2(x, 86), c, 7, true)
			ci.draw_circle(Vector2(82, 36), 4, Color.WHITE)
		"beak":
			ci.draw_circle(Vector2(34, 50), 24, c)
			Art.poly(ci, [Vector2(50, 36), Vector2(94, 50), Vector2(52, 52)], HORN)
			Art.poly(ci, [Vector2(52, 54), Vector2(84, 58), Vector2(50, 66)], HORN.darkened(0.15))
			ci.draw_circle(Vector2(36, 42), 5, DARK)
		"jaws":
			ci.draw_arc(Vector2(50, 50), 34, PI * 1.1, PI * 1.9, 16, c, 12, true)
			ci.draw_arc(Vector2(50, 50), 34, PI * 0.1, PI * 0.9, 16, c, 12, true)
			for x in [34.0, 50.0, 66.0]:
				Art.poly(ci, [Vector2(x - 6, 26), Vector2(x + 6, 26), Vector2(x, 42)], BONE)
				Art.poly(ci, [Vector2(x - 6, 74), Vector2(x + 6, 74), Vector2(x, 58)], BONE)
		"fangs":
			ci.draw_arc(Vector2(50, 40), 34, PI * 0.05, PI * 0.95, 16, c, 14, true)
			Art.poly(ci, [Vector2(26, 50), Vector2(38, 50), Vector2(30, 92)], BONE)
			Art.poly(ci, [Vector2(62, 50), Vector2(74, 50), Vector2(70, 92)], BONE)
			Art.poly(ci, [Vector2(44, 56), Vector2(56, 56), Vector2(50, 72)], BONE)
		"snout":
			ci.draw_circle(Vector2(26, 40), 20, c)
			var pts := PackedVector2Array()
			for i in 12:
				var t := i / 11.0
				pts.append(Vector2(40 + t * 44, 42 + sin(t * 2.6) * 32))
			ci.draw_polyline(pts, c, 14, true)
			ci.draw_circle(pts[pts.size() - 1], 9, c2)
		"eyes", "eyes_big":
			var r := 20.0 if id == "eyes_big" else 14.0
			for x in [30.0, 70.0]:
				ci.draw_circle(Vector2(x, 52), r, Color("#f4f4ec"))
				ci.draw_circle(Vector2(x + 3, 54), r * 0.5, DARK)
		"eyes_stalk":
			for x in [32.0, 68.0]:
				ci.draw_line(Vector2(50, 90), Vector2(x, 34), c, 6, true)
				ci.draw_circle(Vector2(x, 28), 13, Color("#f4f4ec"))
				ci.draw_circle(Vector2(x + 2, 30), 6, DARK)
		"stubs":
			_legs_icon(ci, c, 4, 0.45)
		"legs2":
			_legs_icon(ci, c, 2, 1.0)
		"legs4":
			_legs_icon(ci, c, 4, 1.0)
		"legs6":
			_legs_icon(ci, c, 6, 0.9)
		"legs_long":
			_legs_icon(ci, c, 4, 1.6)
		"paws":
			Art.ellipse(ci, Vector2(50, 64), 22, 18, c2)
			for q in [Vector2(26, 38), Vector2(42, 26), Vector2(58, 26), Vector2(74, 38)]:
				ci.draw_circle(q, 9, c2)
		"hooves":
			Art.poly(ci, [Vector2(26, 30), Vector2(74, 30), Vector2(84, 80), Vector2(16, 80)], Color("#4a3a30"))
			ci.draw_line(Vector2(50, 50), Vector2(50, 80), Color("#2a1e18"), 5)
			ci.draw_rect(Rect2(22, 20, 56, 12), c)
		"webbed":
			Art.poly(ci, [Vector2(50, 22), Vector2(90, 78), Vector2(10, 78)], c2.lightened(0.15))
			for x in [16.0, 50.0, 84.0]:
				ci.draw_line(Vector2(50, 24), Vector2(x, 80), c2.darkened(0.3), 5, true)
		"claws", "claws_big":
			var k := 1.3 if id == "claws_big" else 1.0
			for i in 3:
				var x := 26.0 + i * 24.0
				var tip := Vector2(x + 10 * k, 50 + 40 * k)
				Art.poly(ci, [Vector2(x - 7 * k, 22), Vector2(x + 7 * k, 22), tip], BONE)
			ci.draw_rect(Rect2(12, 12, 76, 14), c2)
		"arms":
			ci.draw_polyline(PackedVector2Array([Vector2(14, 22), Vector2(46, 58), Vector2(76, 42)]), c, 12, true)
			ci.draw_circle(Vector2(78, 42), 10, c2)
			for d in [Vector2(12, -10), Vector2(16, 2), Vector2(10, 12)]:
				ci.draw_line(Vector2(80, 42), Vector2(80, 42) + d, c2, 5, true)
		"arms_claw":
			ci.draw_polyline(PackedVector2Array([Vector2(12, 70), Vector2(40, 62)]), c, 12, true)
			ci.draw_arc(Vector2(62, 46), 26, PI * 0.95, PI * 1.9, 14, c2.darkened(0.1), 14, true)
			ci.draw_arc(Vector2(62, 72), 22, PI * 0.1, PI * 0.95, 14, c2.darkened(0.1), 12, true)
		"back_spikes":
			ci.draw_arc(Vector2(50, 110), 60, PI * 1.2, PI * 1.8, 20, c, 16, true)
			for i in 4:
				var a := PI * (1.28 + i * 0.15)
				var base := Vector2(50, 110) + Vector2.from_angle(a) * 58
				var tip := Vector2(50, 110) + Vector2.from_angle(a) * 90
				var side := Vector2.from_angle(a + PI / 2) * 8
				Art.poly(ci, [base - side, base + side, tip], BONE)
		"plates":
			ci.draw_arc(Vector2(50, 110), 60, PI * 1.2, PI * 1.8, 20, c, 16, true)
			for i in 3:
				var a := PI * (1.33 + i * 0.17)
				var q := Vector2(50, 110) + Vector2.from_angle(a) * 68
				Art.ellipse(ci, q, 12, 20, c2.darkened(0.2), a + PI / 2)
		"sail":
			ci.draw_line(Vector2(8, 84), Vector2(92, 84), c, 12, true)
			var fan := PackedVector2Array([Vector2(16, 80)])
			for i in 9:
				var t := i / 8.0
				fan.append(Vector2(16 + t * 68, 80 - sin(t * PI) * 62))
			fan.append(Vector2(84, 80))
			Art.poly(ci, Array(fan), c2.lightened(0.15))
			for i in 5:
				var x := 24.0 + i * 13.0
				ci.draw_line(Vector2(x, 80), Vector2(x, 80 - sin((x - 16) / 68.0 * PI) * 60), BONE, 3)
		"tail_long", "tail_club":
			var pts := PackedVector2Array()
			for i in 14:
				var t := i / 13.0
				pts.append(Vector2(10 + t * (70 if id == "tail_club" else 84), 50 + sin(t * 4.0) * 18))
			for i in pts.size() - 1:
				ci.draw_line(pts[i], pts[i + 1], c, lerpf(18, 4, float(i) / pts.size()), true)
			if id == "tail_club":
				var e := pts[pts.size() - 1]
				ci.draw_circle(e, 13, c2)
				for d in [Vector2(0, -18), Vector2(16, 0), Vector2(0, 18)]:
					Art.poly(ci, [e + d * 0.6 + d.orthogonal() * 0.2, e + d * 0.6 - d.orthogonal() * 0.2, e + d * 1.1], BONE)
		"horns":
			ci.draw_circle(Vector2(50, 70), 22, c)
			for s in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for i in 8:
					var t := i / 7.0
					pts.append(Vector2(50 + s * (14 + t * 30), 58 - t * 44 + t * t * 10))
				for i in pts.size() - 1:
					ci.draw_line(pts[i], pts[i + 1], BONE, lerpf(12, 3, float(i) / pts.size()), true)
		"crest":
			ci.draw_circle(Vector2(42, 70), 22, c)
			Art.poly(ci, [Vector2(30, 52), Vector2(44, 10), Vector2(62, 22), Vector2(80, 16), Vector2(66, 56)], c2)
		"fur":
			for row in 3:
				for i in 5:
					var x := 14.0 + i * 18.0 + (row % 2) * 9.0
					var y := 30.0 + row * 22.0
					ci.draw_polyline(PackedVector2Array([Vector2(x, y + 14), Vector2(x + 4, y), Vector2(x + 9, y + 14)]), c.darkened(0.1), 5, true)
		"scales":
			for row in 4:
				for i in 4:
					var q := Vector2(20 + i * 20 + (row % 2) * 10, 24 + row * 18)
					ci.draw_arc(q, 12, 0.0, PI, 10, c2.darkened(0.1), 6, true)
		"poison_skin":
			Art.poly(ci, [Vector2(50, 12), Vector2(72, 56), Vector2(50, 82), Vector2(28, 56)], Color("#9fe030"))
			ci.draw_circle(Vector2(50, 62), 20, Color("#9fe030"))
			ci.draw_circle(Vector2(44, 56), 6, Color("#e8ffc0"))
			for q in [Vector2(18, 24), Vector2(84, 30), Vector2(80, 84)]:
				ci.draw_circle(q, 6, Color("#c8f040"))
		_:
			ci.draw_circle(Vector2(50, 50), 20, c)
	Art.unpen(ci)

## Ноги: туловище сверху, под ним n ног длины k.
static func _legs_icon(ci: CanvasItem, c: Color, n: int, k: float) -> void:
	var top := 60.0 - 22.0 * k
	Art.ellipse(ci, Vector2(50, top), 36, 13, c)
	var per := maxi(1, n / 2)
	for i in per:
		var x := 50.0 if per == 1 else lerpf(24.0, 76.0, float(i) / (per - 1))
		var knee := Vector2(x - 8, top + 22 * k)
		ci.draw_polyline(PackedVector2Array([Vector2(x, top + 6), knee, Vector2(x + 2, top + 44 * k)]), c.darkened(0.12), 7, true)
		if per == 1:
			ci.draw_polyline(PackedVector2Array([Vector2(x + 12, top + 6), knee + Vector2(18, 0), Vector2(x + 16, top + 44 * k)]), c.darkened(0.25), 7, true)
