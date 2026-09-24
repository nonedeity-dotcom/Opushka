## Как выглядят клетки, их части, еда и находки.
##
## Часть рисуется в своей маленькой системе координат: начало — на краю тела, ось x смотрит
## наружу, единица — двадцатая доля радиуса. Так шип, глаз или жгутик одинаково встают
## на любое место любой клетки, и в редакторе рисуются тем же кодом.
class_name CellArt
extends RefCounted

## Части, которые торчат наружу, — рисуются под телом, чтобы край их прикрывал.
## Рты рисуются поверх — у них видна сама пасть на краю тела.
const OUTSIDE := ["proboscis", "cilia", "flagellum", "flagellum2", "spike", "spike2", "drill", "tentacle", "horn", "lantern", "jet", "sac"]
## Части, что лежат дугой по краю тела.
const RIM := ["shell", "membrane", "stone_skin", "plates", "thermo", "thorn_armor"]


## Клетка целиком. r — «рост» клетки; opts: shape (форма тела), flash, bite, poisoned,
## wobble, ghost (прозрачность 0–1), pick (номер выделенной части), shadow, golden.
static func creature(ci: CanvasItem, at: Vector2, r: float, heading: float, color: Color, parts: Array, t: float, opts := {}) -> void:
	var w: float = opts.get("wobble", 0.0)
	var alpha: float = opts.get("ghost", 1.0)
	var bite: float = opts.get("bite", 0.0)
	var pick: int = opts.get("pick", -1)
	# Только что поставленные части «вырастают»: номер части → множитель размера.
	var pops: Dictionary = opts.get("pop", {})
	var shape: Array = opts.get("shape", [])
	# Живость: плывёт — тело вытягивается по ходу; вырос — вздрагивает; всё время чуть дышит.
	var stretch: float = opts.get("stretch", 0.0)
	var grow: float = opts.get("grow", 0.0)
	r *= 1.0 + 0.22 * sin(PI * grow) * grow + 0.015 * sin(t * 2.2 + w)
	if stretch > 0.01 or not shape.is_empty():
		var src := shape if not shape.is_empty() else Content.shape_preset("round")
		var live: Array = []
		for i in src.size():
			var th := TAU * i / src.size()
			live.append(src[i] * (1.0 + 0.1 * stretch * cos(2.0 * th)))
		shape = live
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
	var gulp: float = opts.get("gulp", 0.0)
	for i in parts.size():
		if parts[i].id in OUTSIDE:
			_part(ci, parts[i], at, r, heading, color, t + w, bite, alpha, i == pick, shape, gulp, float(pops.get(i, 1.0)))
	ci.draw_colored_polygon(body, Color(color, alpha))
	_pattern(ci, opts.get("pattern", "none"), opts.get("color2", color), at, r, heading, shape, t + w, alpha)
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
			_part(ci, parts[i], at, r, heading, color, t + w, bite, alpha, i == pick, shape, gulp, float(pops.get(i, 1.0)))
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

## Узор поверх тела: полоски от края к середине, пятна, кольца или переход цвета.
static func _pattern(ci: CanvasItem, kind: String, col2: Color, at: Vector2, r: float, heading: float, shape: Array, t: float, alpha: float) -> void:
	var c2 := Color(col2, 0.75 * alpha)
	match kind:
		"stripes":
			for i in 10:
				var a := TAU * i / 10.0 + 0.3
				var edge := r * Content.shape_at(shape, a)
				var d := Vector2.from_angle(heading + a)
				ci.draw_line(at + d * edge * 0.5, at + d * edge * 0.92, c2, maxf(1.5, r * 0.13), true)
		"spots":
			for i in 7:
				var a := TAU * i / 7.0 + 0.8
				var k := 0.45 + 0.3 * float(i % 3) / 2.0
				ci.draw_circle(at + Vector2.from_angle(heading + a) * r * Content.shape_at(shape, a) * k, r * (0.1 + 0.04 * (i % 2)), c2)
		"rings":
			for k in [0.62, 0.8]:
				var ring := PackedVector2Array()
				for i in 25:
					var a := TAU * i / 24.0
					ring.append(at + Vector2.from_angle(heading + a) * r * Content.shape_at(shape, a) * k)
				ci.draw_polyline(ring, c2, maxf(1.5, r * 0.07), true)
		"gradient":
			for k in [0.75, 0.5, 0.28]:
				var pts := PackedVector2Array()
				for i in 24:
					var a := TAU * i / 24.0
					pts.append(at + Vector2.from_angle(heading + a) * r * Content.shape_at(shape, a) * k)
				ci.draw_colored_polygon(pts, Color(col2, 0.3 * alpha))

## Где у тела часть: точка и поворот. На краю — по форме тела; внутри — ближе к середине.
static func part_anchor(p: Dictionary, at: Vector2, r: float, heading: float, shape: Array) -> Vector2:
	var d: float = p.get("d", 1.0)
	var edge := r * Content.shape_at(shape, p.a)
	var k := 0.93 if d >= 0.999 else d * 0.72
	return at + Vector2.from_angle(heading + p.a) * edge * k

## Внутренняя часть в своей системе нарисована не с нуля: сдвиг до её середины.
const INNER_CENTER := {"eye": Vector2(-2.5, 0), "chloroplast": Vector2(-6.0, 0), "electro": Vector2(-1.5, 0), "crystal": Vector2(-2.0, 0),
	"fat": Vector2(-4.0, 0), "camo": Vector2(-4.0, 0), "ink": Vector2(-4.0, 0), "shield_gland": Vector2(-4.0, 0), "pulse": Vector2(-4.0, 0),
	"suction": Vector2(-4.0, 0), "life_core": Vector2(-4.0, 0)}

## Одна часть. Годится и для «примерки» в редакторе.
static func _part(ci: CanvasItem, p: Dictionary, at: Vector2, r: float, heading: float, color: Color, t: float, bite: float, alpha: float, picked: bool, shape: Array, gulp := 0.0, grow_k := 1.0) -> void:
	var ang: float = heading + p.a
	var s := r / 20.0 * (1.0 + 0.08 * (int(p.get("lvl", 1)) - 1)) * grow_k
	# Глоток: рот на миг раздувается.
	if gulp > 0.0 and Content.is_mouth(p.id):
		s *= 1.0 + 0.35 * sin(PI * gulp)
	var pos := part_anchor(p, at, r, heading, shape)
	var d: float = p.get("d", 1.0)
	if p.id in RIM:
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
	var half := deg_to_rad(Content.PARTS[id].get("arc", 35) * 0.8 if id == "shell" else (45.0 if id == "plates" else 32.0))
	var inner := 0.84 if id in ["shell", "plates"] else 0.9
	var outer := 1.12 if id in ["shell", "plates"] else 1.06
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
	if id == "thermo":
		ci.draw_colored_polygon(pts, Color("#e0804a", 0.8 * alpha))
		ci.draw_polyline(out_pts, Color("#f8c080", alpha), maxf(1.0, r * 0.04), true)
		return
	if id == "thorn_armor":
		ci.draw_colored_polygon(pts, Color("#8a5a3a", alpha))
		for i in range(1, n, 2):
			var base: Vector2 = out_pts[i]
			var outv := (base - at).normalized()
			ci.draw_colored_polygon(PackedVector2Array([base + outv.orthogonal() * r * 0.06, base + outv * r * 0.2, base - outv.orthogonal() * r * 0.06]), Color("#e8c898", alpha))
		return
	if id == "plates":
		ci.draw_colored_polygon(pts, Color("#7a7a68", alpha))
		for i in range(0, n + 1, 2):
			var mid := (in_pts[i] + out_pts[i]) / 2.0
			ci.draw_circle(mid, r * 0.13, Color("#9a9a84", alpha))
			ci.draw_arc(mid, r * 0.13, 0, TAU, 12, Color("#5a5a4a", alpha), maxf(1.0, r * 0.03), true)
		return
	if id == "stone_skin":
		ci.draw_colored_polygon(pts, Color("#8d949c", alpha))
		for i in [2, 5, 8]:
			ci.draw_circle((in_pts[i] + out_pts[i]) / 2.0, r * 0.05, Color("#5d646c", alpha))
		ci.draw_polyline(out_pts, Color("#b0b8c0", alpha), maxf(1.0, r * 0.04), true)
		return
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
		"drill":
			Art.poly(ci, [Vector2(-1, -5.5), Vector2(17, 0), Vector2(-1, 5.5)], Color("#9aa8b8", alpha))
			# Витки бура бегут — будто он вращается.
			for i in 4:
				var x := fposmod(i * 4.0 + t * 14.0, 16.0)
				var hw := 5.5 * (1.0 - x / 17.0)
				ci.draw_line(Vector2(x, -hw), Vector2(x + 2.5, hw), Color("#6a7888", alpha), 1.1, true)
		"crystal":
			var glow := 0.6 + 0.4 * sin(t * 3.0)
			ci.draw_circle(Vector2(-2.0, 0), 9.0, Color(0.6, 0.9, 1.0, 0.18 * glow * alpha))
			Art.poly(ci, [Vector2(-2, -6), Vector2(2, -2.5), Vector2(2, 2.5), Vector2(-2, 6), Vector2(-6, 2.5), Vector2(-6, -2.5)], Color("#9fe0f8", alpha))
			Art.poly(ci, [Vector2(-2, -6), Vector2(2, -2.5), Vector2(-2, 0), Vector2(-6, -2.5)], Color("#dff6ff", alpha))
		"tentacle":
			var pts := PackedVector2Array()
			for i in 15:
				var x := 30.0 * i / 14.0
				pts.append(Vector2(x, sin(x * 0.28 - t * 5.0) * (x / 30.0) * 5.0))
			ci.draw_polyline(pts, dark, 4.0, true)
			ci.draw_polyline(pts, Color(color.lightened(0.15), alpha), 2.4, true)
			for i in [3, 6, 9, 12]:
				ci.draw_circle(pts[i], 0.9, Color("#f0d0e0", alpha))
		"lantern":
			var tip := Vector2(11.0, -5.0 + sin(t * 2.0) * 1.0)
			ci.draw_polyline(Art.quad(Vector2(0, 0), Vector2(7, 1), tip, 6), dark, 1.8, true)
			var pulse := 0.7 + 0.3 * sin(t * 4.0)
			ci.draw_circle(tip, 7.0, Color(1.0, 0.95, 0.5, 0.2 * pulse * alpha))
			ci.draw_circle(tip, 3.4, Color(1.0, 0.95, 0.6, alpha))
		"horn":
			var pts := Art.quad(Vector2(-1, -5.5), Vector2(10, -6), Vector2(19, -3.5), 8)
			pts.append_array(Art.quad(Vector2(19, -3.5), Vector2(11, 0), Vector2(-1, 5.5), 8))
			ci.draw_colored_polygon(pts, Color("#ece2c8", alpha))
			ci.draw_polyline(pts, Color("#a89878", alpha), 0.8, true)
		"fat":
			Art.ellipse(ci, Vector2(-4, 0), 4.2, 5.0, Color("#f0d890", alpha))
			ci.draw_circle(Vector2(-5.2, -1.6), 1.3, Color(1, 1, 1, 0.8 * alpha))
		"camo":
			for i in 6:
				var q := Vector2(-4, 0) + Vector2.from_angle(i * 1.1) * 3.5
				ci.draw_circle(q, 1.3, Color.from_hsv(fmod(t * 0.2 + i * 0.17, 1.0), 0.5, 1.0, 0.8 * alpha))
		"ink":
			Art.ellipse(ci, Vector2(-4, 0), 4.5, 3.6, Color("#2a2238", alpha))
			ci.draw_circle(Vector2(-5.5, -1.2), 1.0, Color(1, 1, 1, 0.5 * alpha))
		"shield_gland":
			var hexa := PackedVector2Array()
			for i in 6:
				hexa.append(Vector2(-4, 0) + Vector2.from_angle(i * TAU / 6.0) * 4.5)
			ci.draw_colored_polygon(hexa, Color("#6ab0f0", 0.85 * alpha))
			ci.draw_polyline(hexa + PackedVector2Array([hexa[0]]), Color("#c8e6ff", alpha), 0.8, true)
		"pulse":
			ci.draw_circle(Vector2(-4, 0), 4.2, Color("#f0d84a", alpha))
			ci.draw_arc(Vector2(-4, 0), 2.6, t * 4.0, t * 4.0 + 4.5, 10, Color("#806010", alpha), 1.0, true)
		"suction":
			ci.draw_circle(Vector2(-4, 0), 4.2, Color("#5aa8a0", alpha))
			ci.draw_arc(Vector2(-4, 0), 3.0, -t * 5.0, -t * 5.0 + 4.0, 10, Color("#d8fff8", alpha), 1.0, true)
			ci.draw_arc(Vector2(-4, 0), 1.6, -t * 5.0 + 2.0, -t * 5.0 + 5.5, 8, Color("#d8fff8", alpha), 0.8, true)
		"life_core":
			var beat := 1.0 + 0.15 * absf(sin(t * 3.0))
			ci.draw_circle(Vector2(-4, 0), 7.0 * beat, Color(1.0, 0.4, 0.5, 0.2 * alpha))
			Art.heart(ci, Vector2(-4, -0.5), 8.0 * beat, Color("#f0506a", alpha))
		"sucker":
			ci.draw_circle(Vector2(2.5, 0), 4.2, dark)
			ci.draw_circle(Vector2(2.5, 0), 2.6, Color("#e89aa8", alpha))
			ci.draw_circle(Vector2(2.5, 0), 1.2, Color("#6a2a3a", alpha))
		"sac":
			# Толчковый пузырь: прозрачный мешочек с горлышком, мерно сжимается.
			var sq := 1.0 + 0.08 * sin(t * 4.0)
			Art.ellipse(ci, Vector2(3.5, 0), 5.0 * sq, 4.2 / sq, Color("#a8d8f0", 0.55 * alpha), 0.0, 16)
			ci.draw_arc(Vector2(3.5, 0), 4.6, 0, TAU, 18, Color("#e8f8ff", 0.8 * alpha), 0.9, true)
			ci.draw_rect(Rect2(Vector2(8.0, -1.3), Vector2(2.2, 2.6)), Color("#6a9ab8", alpha))
			ci.draw_circle(Vector2(2.0, -1.5), 1.1, Color(1, 1, 1, 0.8 * alpha))
		"jet":
			Art.poly(ci, [Vector2(-1, -4), Vector2(7, -3), Vector2(9, 0), Vector2(7, 3), Vector2(-1, 4)], Color("#8aa0b8", alpha))
			ci.draw_circle(Vector2(9, 0), 2.2, Color("#30404e", alpha))
			ci.draw_circle(Vector2(11.5 + sin(t * 20.0), 0), 1.5 * absf(sin(t * 10.0)), Color(0.8, 0.95, 1.0, 0.7 * alpha))
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
	if id in RIM:
		_rim_part(ci, id, origin + Vector2(-18.0 * s, 0), 18.0 * s, 0.0, 0.0, alpha, [])
		return
	ci.draw_set_transform(origin + Vector2(-18.0 * s + 18.0 * s * 0.93, 0), 0.0, Vector2(s * 0.9, s * 0.9))
	part_shape(ci, id, color, t, 0.3, alpha)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- еда и находки --------------------------------------------------------------------

# Водоросли и мясо — готовыми картинками: их на экране десятки, и картинки одной текстуры
# видеокарта рисует разом, а не по 12 кружков на каждую (на телефоне из-за этого лагало).
static var _plant_tex: Array = []
static var _meat_tex: Texture2D

## Мягкий круг в картинку: край сглажен на полтора пикселя.
static func _paint_circle(img: Image, c: Vector2, r: float, col: Color) -> void:
	var s := img.get_width()
	for y in range(maxi(0, int(c.y - r - 2)), mini(s, int(c.y + r + 2))):
		for x in range(maxi(0, int(c.x - r - 2)), mini(s, int(c.x + r + 2))):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(r - d + 0.75, 0.0, 1.5) / 1.5 * col.a
			if a <= 0.0:
				continue
			var under := img.get_pixel(x, y)
			var out := Color(col.r, col.g, col.b, 1.0).lerp(under, 1.0 - a) if under.a > 0.0 else Color(col.r, col.g, col.b, a)
			out.a = maxf(under.a, a)
			img.set_pixel(x, y, out)

static func plant_texture(v: int) -> Texture2D:
	if _plant_tex.is_empty():
		for n in [3, 4]:
			var s := 64
			var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
			var c := Vector2(s, s) / 2.0
			var r := s * 0.5 / 1.0
			var pts: Array = []
			for i in n:
				pts.append(c + Vector2.from_angle(TAU * i / n - PI / 2.0) * r * 0.45)
			for p in pts:
				_paint_circle(img, p, r * 0.52, Color("#4f9a4a"))
			for p in pts:
				_paint_circle(img, p, r * 0.4, Art.PLANT)
			for p in pts:
				_paint_circle(img, p - Vector2(r * 0.12, r * 0.12), r * 0.13, Color("#c8f0b0"))
			_plant_tex.append(ImageTexture.create_from_image(img))
	return _plant_tex[v % 2]

static func meat_texture() -> Texture2D:
	if _meat_tex == null:
		var s := 64
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		var c := Vector2(s, s) / 2.0
		var poly := PackedVector2Array()
		for i in 6:
			poly.append(c + Vector2.from_angle(TAU * i / 6.0 + 0.4) * s * 0.46 * (0.8 + 0.2 * sin(i * 1.7)))
		for y in s:
			for x in s:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
					img.set_pixel(x, y, Art.MEAT)
		_paint_circle(img, c + Vector2(2, -2), s * 0.14, Color("#f09a9a"))
		_meat_tex = ImageTexture.create_from_image(img)
	return _meat_tex

static func plant(ci: CanvasItem, f: Dictionary, t: float) -> void:
	var r: float = f.r
	ci.draw_texture_rect(plant_texture(f.v), Rect2(f.pos - Vector2(r, r), Vector2(r, r) * 2.0), false)

static func meat(ci: CanvasItem, f: Dictionary, t: float) -> void:
	var r: float = f.r * 1.1
	ci.draw_texture_rect(meat_texture(), Rect2(f.pos - Vector2(r, r), Vector2(r, r) * 2.0), false)

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


# --- камни и пара ---------------------------------------------------------------------

## Камень: грани, трещины тем больше, чем сильнее разбит, вспышка от удара.
## Круг водорослей: плотная живая подстилка — её не съесть, еда растёт по краю.
static func colony(ci: CanvasItem, col: Dictionary, t: float) -> void:
	var r: float = col.r
	var v: int = col.v
	var c: Vector2 = col.pos
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a: float = TAU * i / n + col.spin
		pts.append(c + Vector2.from_angle(a) * r * (0.94 + 0.06 * sin(v + i * 1.9 + t * 0.8)))
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(r * 0.06, r * 0.09))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	ci.draw_colored_polygon(pts, Color("#2f5a38"))
	# Узор подстилки: кольца и завитки чуть светлее.
	ci.draw_circle(c, r * 0.72, Color("#3a6e44"))
	var spin: float = col.spin
	ci.draw_arc(c, r * 0.5, spin, spin + TAU * 0.8, 24, Color("#4f8a58", 0.8), maxf(1.5, r * 0.05), true)
	ci.draw_arc(c, r * 0.28, spin + 2.0, spin + 2.0 + TAU * 0.7, 16, Color("#4f8a58", 0.8), maxf(1.2, r * 0.04), true)
	for i in 7:
		var a: float = col.spin * 1.5 + TAU * i / 7.0 + v
		var q := c + Vector2.from_angle(a) * r * (0.35 + 0.45 * fmod(float(v * (i + 3)) * 0.37, 1.0))
		ci.draw_circle(q, r * 0.05, Color("#6aa872", 0.8))
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_polyline(edge, Color("#1d3a24"), maxf(2.0, r * 0.05), true)

static func rock(ci: CanvasItem, k: Dictionary, t: float) -> void:
	var def: Dictionary = Content.ROCKS[k.kind]
	var col := Color(def.color)
	var r: float = k.r
	var v: int = k.v
	var pts := PackedVector2Array()
	var n := 9
	for i in n:
		var a := TAU * i / n + v * 0.1
		pts.append(k.pos + Vector2.from_angle(a) * r * (0.86 + 0.14 * sin(v * 1.3 + i * 2.1)))
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(r * 0.1, r * 0.14))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(pts, col.darkened(0.15))
	# Светлая грань сверху-слева.
	var top := PackedVector2Array([k.pos])
	for i in [5, 6, 7, 8]:
		top.append(pts[i])
	ci.draw_colored_polygon(top, col.lightened(0.12))
	var edge := pts.duplicate()
	edge.append(pts[0])
	ci.draw_polyline(edge, col.darkened(0.45), maxf(1.5, r * 0.06), true)
	if k.kind == "crystal":
		var glow := 0.6 + 0.4 * sin(t * 2.0 + v)
		for i in 3:
			var a := -PI / 2.0 + (i - 1) * 0.5
			var base: Vector2 = k.pos + Vector2.from_angle(a + PI / 2.0) * r * 0.2
			var tip := base + Vector2.from_angle(a) * r * (0.7 + 0.15 * i)
			var side := Vector2.from_angle(a).orthogonal() * r * 0.14
			ci.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(0.7, 0.95, 1.0, 0.85))
		ci.draw_circle(k.pos, r * 1.3, Color(0.6, 0.9, 1.0, 0.08 * glow))
	# Трещины: чем меньше прочности, тем их больше.
	var broken := 1.0 - float(k.hp) / float(k.max_hp)
	for i in int(broken * 5.0):
		var a := v * 0.7 + i * 2.4
		var p0: Vector2 = k.pos + Vector2.from_angle(a) * r * 0.15
		var p1 := p0 + Vector2.from_angle(a + 0.4) * r * 0.45
		var p2 := p1 + Vector2.from_angle(a - 0.3) * r * 0.35
		ci.draw_polyline(PackedVector2Array([p0, p1, p2]), Color(0.1, 0.1, 0.12, 0.8), maxf(1.0, r * 0.05), true)
	if k.flash > 0.0:
		ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.4 * k.flash))

## Пара: твоя же клетка, только с розовым ореолом и сердечком над ней.
static func mate(ci: CanvasItem, m: Creature, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	ci.draw_circle(m.pos, m.radius * (1.6 + 0.15 * pulse), Color(1.0, 0.6, 0.8, 0.12))
	creature(ci, m.pos, m.size_r, m.heading, m.color, m.parts, m.phase, {"shape": m.shape, "wobble": 1.7})
	var h := m.pos + Vector2(0, -m.radius * 1.7 - 6.0 * pulse)
	Art.heart(ci, h, m.radius * 0.8, Color("#f07aa8"))

