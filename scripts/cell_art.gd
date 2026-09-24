## Как выглядят клетки, их части, еда и находки.
##
## Часть рисуется в своей маленькой системе координат: начало — на краю тела, ось x смотрит
## наружу, единица — двадцатая доля радиуса. Так шип, глаз или жгутик одинаково встают
## на любое место любой клетки, и в редакторе рисуются тем же кодом.
class_name CellArt
extends RefCounted

## Части, которые торчат наружу, — рисуются под телом, чтобы край их прикрывал.
## Рты рисуются поверх — у них видна сама пасть на краю тела.
const OUTSIDE := ["proboscis", "cilia", "flagellum", "flagellum2", "spike", "spike2"]


## Клетка целиком. r — «рост» клетки; opts: shape (форма тела), flash, bite, poisoned,
## wobble, ghost (прозрачность 0–1), pick (номер выделенной части), shadow, golden.
static func creature(ci: CanvasItem, at: Vector2, r: float, heading: float, color: Color, parts: Array, t: float, opts := {}) -> void:
	var w: float = opts.get("wobble", 0.0)
	var alpha: float = opts.get("ghost", 1.0)
	var bite: float = opts.get("bite", 0.0)
	var pick: int = opts.get("pick", -1)
	var shape: Array = opts.get("shape", [])
	# Тело — живая капля своей формы: край чуть колышется.
	var body := PackedVector2Array()
	var n := 40
	for i in n:
		var th := TAU * i / n
		var k := 1.0 + 0.025 * sin(3.0 * th + t * 2.0 + w) + 0.018 * sin(5.0 * th - t * 1.4 + w * 2.0)
		body.append(at + Vector2.from_angle(heading + th) * r * Content.shape_at(shape, th) * k)
	if opts.get("golden", false):
		var glow := 0.5 + 0.5 * sin(t * 3.0 + w)
		for g in 3:
			ci.draw_circle(at, r * (1.5 + g * 0.25 + glow * 0.1), Color(1.0, 0.85, 0.35, 0.07))
	if opts.get("shadow", true):
		var shadow := PackedVector2Array()
		for q in body:
			shadow.append(q + Vector2(r * 0.12, r * 0.18))
		ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.22 * alpha))
	for i in parts.size():
		if parts[i].id in OUTSIDE:
			_part(ci, parts[i], at, r, heading, color, t + w, bite, alpha, i == pick, shape)
	ci.draw_colored_polygon(body, Color(color, alpha))
	var edge := body.duplicate()
	edge.append(body[0])
	ci.draw_polyline(edge, Color(color.darkened(0.45), alpha), maxf(1.5, r * 0.09), true)
	var fwd := Vector2.from_angle(heading)
	Art.ellipse(ci, at + fwd * r * 0.18 + fwd.orthogonal() * r * 0.2, r * 0.55, r * 0.42, Color(1, 1, 1, 0.13 * alpha), heading)
	# Ядро — ближе к хвосту, органоиды вокруг.
	var nucleus := at - fwd * r * 0.22 * Content.shape_at(shape, PI)
	ci.draw_circle(nucleus, r * 0.3, Color(color.darkened(0.3), alpha))
	ci.draw_circle(nucleus + fwd.orthogonal() * r * 0.08, r * 0.1, Color(color.darkened(0.55), alpha))
	for i in 3:
		var a := 1.3 + i * 1.9 + w
		ci.draw_circle(at + Vector2.from_angle(heading + a) * r * 0.55 * Content.shape_at(shape, a), r * 0.07, Color(color.lightened(0.35), 0.8 * alpha))
	for i in parts.size():
		if not parts[i].id in OUTSIDE:
			_part(ci, parts[i], at, r, heading, color, t + w, bite, alpha, i == pick, shape)
	var flash: float = opts.get("flash", 0.0)
	if flash > 0.0:
		ci.draw_colored_polygon(body, Color(1, 0.85, 0.8, 0.55 * flash))
	if opts.get("poisoned", false):
		ci.draw_colored_polygon(body, Color(0.5, 0.95, 0.3, 0.18 + 0.08 * sin(t * 8.0)))
	if opts.get("golden", false):
		ci.draw_polyline(edge, Color(1.0, 0.9, 0.5, 0.6 + 0.3 * sin(t * 4.0)), maxf(1.5, r * 0.08), true)
		# Искорки кружат вокруг и мерцают.
		for i in 5:
			var a := t * 0.9 + TAU * i / 5.0
			var at2 := at + Vector2.from_angle(a) * r * (1.45 + 0.12 * sin(t * 2.0 + i))
			var tw := 0.5 + 0.5 * sin(t * 6.0 + i * 1.7)
			var len := r * 0.18 * (0.5 + tw)
			ci.draw_line(at2 - Vector2(len, 0), at2 + Vector2(len, 0), Color(1, 0.95, 0.6, tw), maxf(1.0, r * 0.05), true)
			ci.draw_line(at2 - Vector2(0, len), at2 + Vector2(0, len), Color(1, 0.95, 0.6, tw), maxf(1.0, r * 0.05), true)

## Где у тела часть: точка и поворот. На краю — по форме тела; внутри — ближе к середине.
static func part_anchor(p: Dictionary, at: Vector2, r: float, heading: float, shape: Array) -> Vector2:
	var d: float = p.get("d", 1.0)
	var edge := r * Content.shape_at(shape, p.a)
	var k := 0.93 if d >= 0.999 else d * 0.72
	return at + Vector2.from_angle(heading + p.a) * edge * k

## Внутренняя часть в своей системе нарисована не с нуля: сдвиг до её середины.
const INNER_CENTER := {"eye": Vector2(-2.5, 0), "chloroplast": Vector2(-6.0, 0), "electro": Vector2(-1.5, 0)}

## Одна часть. Годится и для «примерки» в редакторе.
static func _part(ci: CanvasItem, p: Dictionary, at: Vector2, r: float, heading: float, color: Color, t: float, bite: float, alpha: float, picked: bool, shape: Array) -> void:
	var ang: float = heading + p.a
	var s := r / 20.0 * (1.0 + 0.08 * (int(p.get("lvl", 1)) - 1))
	var pos := part_anchor(p, at, r, heading, shape)
	var d: float = p.get("d", 1.0)
	if p.id == "shell" or p.id == "membrane":
		_rim_part(ci, p.id, at, r, heading, p.a, alpha, shape)
	elif d < 0.999:
		# Внутри тела часть смотрит вперёд — так глаз посередине глядит по ходу.
		var rot := heading if d < 0.05 else ang
		var off: Vector2 = INNER_CENTER.get(p.id, Vector2.ZERO)
		ci.draw_set_transform(pos - off.rotated(rot) * s, rot, Vector2(s, s))
		part_shape(ci, p.id, color, t, bite, alpha)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_set_transform(pos, ang, Vector2(s, s))
		part_shape(ci, p.id, color, t, bite, alpha)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if picked:
		ci.draw_arc(pos, r * 0.3, 0, TAU, 24, Color(Art.GOLD, 0.9), maxf(2.0, r * 0.06), true)

## Одна часть отдельно — «примерка» в редакторе.
static func part_alone(ci: CanvasItem, p: Dictionary, at: Vector2, r: float, heading: float, color: Color, t: float, alpha: float, shape: Array) -> void:
	_part(ci, p, at, r, heading, color, t, 0.3, alpha, false, shape)

## Панцирь и мембрана лежат по краю тела дугой — по его форме.
static func _rim_part(ci: CanvasItem, id: String, at: Vector2, r: float, heading: float, a: float, alpha: float, shape: Array) -> void:
	var half := deg_to_rad(Content.PARTS[id].get("arc", 35) * 0.8 if id == "shell" else 32.0)
	var inner := 0.84 if id == "shell" else 0.9
	var outer := 1.12 if id == "shell" else 1.06
	var n := 10
	var out_pts := PackedVector2Array()
	var in_pts := PackedVector2Array()
	for i in n + 1:
		var q := a - half + 2.0 * half * i / n
		var edge := r * Content.shape_at(shape, q)
		out_pts.append(at + Vector2.from_angle(heading + q) * edge * outer)
		in_pts.append(at + Vector2.from_angle(heading + q) * edge * inner)
	var pts := out_pts.duplicate()
	for i in range(n, -1, -1):
		pts.append(in_pts[i])
	if id == "shell":
		ci.draw_colored_polygon(pts, Color("#b9a784", alpha))
		for i in [3, 5, 7]:
			ci.draw_line(in_pts[i], out_pts[i], Color("#8a7a5a", alpha), maxf(1.0, r * 0.05), true)
		ci.draw_polyline(out_pts, Color("#e0d2b0", alpha), maxf(1.0, r * 0.05), true)
	else:
		ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.22 * alpha))

## Сама часть в своей системе: x — наружу от тела, единица — 1/20 радиуса.
static func part_shape(ci: CanvasItem, id: String, color: Color, t: float, bite := 0.0, alpha := 1.0) -> void:
	var dark := Color(color.darkened(0.45), alpha)
	var light := Color(color.lightened(0.3), alpha)
	match id:
		"filter":
			# Воронка: светлые губы раструбом наружу, тёмное горло, внутри шевелятся волоски.
			Art.poly(ci, [Vector2(-2.5, -5.0), Vector2(3.5, -7.5), Vector2(4.5, -5.5), Vector2(4.5, 5.5), Vector2(3.5, 7.5), Vector2(-2.5, 5.0)], Color(color.lightened(0.45), alpha))
			Art.ellipse(ci, Vector2(1.8, 0), 2.4, 5.4, Color(0.1, 0.16, 0.12, 0.95 * alpha))
			for y in [-2.8, 0.0, 2.8]:
				ci.draw_line(Vector2(0.5, y), Vector2(3.2, y + sin(t * 9.0 + y) * 0.9), Color(color.lightened(0.6), alpha), 0.8, true)
		"jaws":
			var open := 0.2 + 0.55 * absf(sin(bite * PI))
			for side in [-1.0, 1.0]:
				var base := Vector2(-1.0, side * 4.2)
				var tip := Vector2(10.0, side * (1.2 + open * 4.0))
				var mid := Vector2(6.0, side * (5.5 + open * 2.0))
				var pts := Art.quad(base, mid, tip, 6)
				pts.append(Vector2(3.0, side * 2.0))
				ci.draw_colored_polygon(pts, Color("#e9dcc6", alpha))
				ci.draw_polyline(pts, Color("#8a7a66", alpha), 0.8, true)
		"fangs":
			Art.ellipse(ci, Vector2(0, 0), 3.5, 7.0, Color("#b0404a", alpha))
			var open := 0.2 + 0.6 * absf(sin(bite * PI))
			for side in [-1.0, 1.0]:
				var pts := PackedVector2Array([Vector2(0, side * 5.5), Vector2(7.0, side * (6.5 + open * 2.0)), Vector2(15.0, side * (1.0 + open * 3.0)), Vector2(1.5, side * 2.0)])
				ci.draw_colored_polygon(pts, Color("#f6f1e6", alpha))
				ci.draw_polyline(pts, Color("#9a8f80", alpha), 0.8, true)
		"proboscis":
			var wig := sin(t * 4.0) * 1.2
			var pts := Art.quad(Vector2(0, 0), Vector2(7, wig), Vector2(13, wig * 0.5), 8)
			ci.draw_polyline(pts, dark, 4.2, true)
			ci.draw_polyline(pts, Color(color.lightened(0.1), alpha), 2.6, true)
			ci.draw_circle(pts[-1], 2.4, Color("#f0a0b0", alpha))
		"cilia":
			for i in 7:
				var y := -9.0 + i * 3.0
				var sway := sin(t * 12.0 + i * 0.9) * 2.2
				ci.draw_line(Vector2(0.5, y), Vector2(5.5, y + sway), light, 1.2, true)
		"flagellum", "flagellum2":
			var big := id == "flagellum2"
			var tails := [-2.5, 2.5] if big else [0.0]
			var length := 40.0 if big else 32.0
			for off in tails:
				var pts := PackedVector2Array()
				for i in 17:
					var x := length * i / 16.0
					var amp := (x / length) * (5.5 if big else 4.5)
					pts.append(Vector2(x, off * (1.0 - x / length) + sin(x * 0.33 - t * (13.0 if big else 10.0) + off) * amp))
				ci.draw_polyline(pts, dark, 3.2 if big else 2.4, true)
				ci.draw_polyline(pts, light, 1.2, true)
		"spike":
			Art.poly(ci, [Vector2(-1, -4.5), Vector2(13, 0), Vector2(-1, 4.5)], Color("#e8d69c", alpha))
			ci.draw_line(Vector2(0, 0), Vector2(11, 0), Color("#b8a060", alpha), 0.9, true)
		"spike2":
			Art.poly(ci, [Vector2(-1, -6.5), Vector2(22, 0), Vector2(-1, 6.5)], Color("#efdfa8", alpha))
			Art.poly(ci, [Vector2(-1, -6.5), Vector2(22, 0), Vector2(-1, 0)], Color("#d8c285", alpha))
			ci.draw_line(Vector2(0, 0), Vector2(19, 0), Color("#a88f50", alpha), 1.1, true)
		"poison":
			ci.draw_circle(Vector2(-0.5, 0), 5.2, Color("#7ed85a", alpha))
			ci.draw_circle(Vector2(-0.5, 0), 5.2 * 0.6, Color("#a8f080", alpha))
			for d in [Vector2(-2, -2), Vector2(1, 2), Vector2(-2, 2.5)]:
				ci.draw_circle(d, 0.9, Color("#3d7a2a", alpha))
			var drip := fmod(t * 0.8, 1.0)
			ci.draw_circle(Vector2(5.0 + drip * 6.0, sin(t * 3.0)), 1.4 * (1.0 - drip), Color("#8fe070", alpha * (1.0 - drip)))
		"electro":
			Art.ellipse(ci, Vector2(-1.5, 0), 5.5, 4.2, Color("#f2e05a", alpha))
			Art.ellipse(ci, Vector2(-1.5, 0), 3.0, 2.0, Color("#fff6b0", alpha))
			if fmod(t * 3.0, 1.0) < 0.35:
				ci.draw_polyline(PackedVector2Array([Vector2(3, 0), Vector2(6, -2.5), Vector2(8, 1.5), Vector2(11, -1)]), Color("#fff08a", alpha), 1.2, true)
		"eye":
			var blink := fmod(t * 0.23, 1.0) > 0.96
			ci.draw_circle(Vector2(-2.5, 0), 4.6, Color("#f4f4ec", alpha))
			if blink:
				ci.draw_line(Vector2(-7, 0), Vector2(2, 0), Color("#2a2a2a", alpha), 1.4, true)
			else:
				ci.draw_circle(Vector2(-1.2, 0), 2.3, Color("#1e1e28", alpha))
				ci.draw_circle(Vector2(-2.0, -0.9), 0.8, Color(1, 1, 1, alpha))
			ci.draw_arc(Vector2(-2.5, 0), 4.6, 0, TAU, 16, dark, 0.8, true)
		"chloroplast":
			Art.ellipse(ci, Vector2(-6.0, 0), 5.0, 2.8, Color("#3f9a4a", alpha), 0.0, 14)
			for x in [-8.5, -6.0, -3.5]:
				ci.draw_line(Vector2(x, -1.8), Vector2(x, 1.8), Color("#8ad07a", alpha), 0.8, true)


## Значок части для палитры редактора: кусочек тела слева и часть справа.
static func part_icon(ci: CanvasItem, id: String, rect: Rect2, color: Color, t := 0.0, alpha := 1.0) -> void:
	var s := rect.size.x / 60.0
	var origin := rect.position + Vector2(rect.size.x * 0.4, rect.size.y * 0.5)
	if id == "flagellum" or id == "flagellum2":
		s *= 0.8
		origin.x -= rect.size.x * 0.12
	ci.draw_circle(origin + Vector2(-18.0 * s, 0), 18.0 * s, Color(color, 0.9 * alpha))
	if id == "shell" or id == "membrane":
		_rim_part(ci, id, origin + Vector2(-18.0 * s, 0), 18.0 * s, 0.0, 0.0, alpha, [])
		return
	ci.draw_set_transform(origin + Vector2(-18.0 * s + 18.0 * s * 0.93, 0), 0.0, Vector2(s * 0.9, s * 0.9))
	part_shape(ci, id, color, t, 0.3, alpha)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- еда и находки --------------------------------------------------------------------

static func plant(ci: CanvasItem, f: Dictionary, t: float) -> void:
	var v: int = f.v
	var r: float = f.r
	var spin := t * 0.3 + v
	var n := 3 + v % 2
	for i in n:
		var p: Vector2 = f.pos + Vector2.from_angle(spin + TAU * i / n) * r * 0.45
		ci.draw_circle(p, r * 0.52, Color("#4f9a4a"))
		ci.draw_circle(p, r * 0.4, Art.PLANT)
		ci.draw_circle(p - Vector2(r * 0.12, r * 0.12), r * 0.13, Color("#c8f0b0"))

static func meat(ci: CanvasItem, f: Dictionary, t: float) -> void:
	var v: int = f.v
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + v * 0.3 + t * 0.2
		pts.append(f.pos + Vector2.from_angle(a) * f.r * (0.8 + 0.35 * sin(v + i * 1.7)))
	ci.draw_colored_polygon(pts, Art.MEAT)
	ci.draw_circle(f.pos + Vector2(1, -1), f.r * 0.3, Color("#f09a9a"))

## Выпавшая часть: светящаяся капсула со значком внутри.
static func capsule(ci: CanvasItem, cap: Dictionary, t: float, known: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 4.0 + cap.pos.x)
	var at: Vector2 = cap.pos
	ci.draw_circle(at, 22.0 + pulse * 4.0, Color(Art.GOLD, 0.12))
	ci.draw_circle(at, 15.0, Color(0.1, 0.12, 0.16, 0.9))
	ci.draw_arc(at, 15.0, 0, TAU, 32, Color(Art.GOLD, 0.6 + 0.4 * pulse), 2.5, true)
	part_icon(ci, cap.part, Rect2(at - Vector2(12, 12), Vector2(24, 24)), Color("#9aa4b0"), t)
	if not known:
		ci.draw_circle(at + Vector2(11, -11), 5.0, Art.ACCENT)
