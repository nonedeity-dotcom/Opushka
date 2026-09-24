## Картинки «Опушки» — простые фигуры на сетке 100×100, как в версии из Core.
##
## Картинок-файлов нет: всё рисуется фигурами, и поэтому любую вещь легко поправить в коде,
## а новая вещь в мире — это новый случай здесь. Рисунок идёт в координатах 0–100: `pen`
## ставит преобразование холста, и дальше можно рисовать ровно теми числами, что были в SVG.
class_name Art
extends RefCounted

const TILE := 64.0

# Палитра — спокойная, тёмная, та же, что в приложении.
const GRASS := [Color("#35523b"), Color("#34503a"), Color("#36543c")]
const FOREST := [Color("#2a4231"), Color("#294130"), Color("#2b4332")]
const SHORE := [Color("#62604a"), Color("#605e48"), Color("#64624c")]
const WATER := [Color("#2b5368"), Color("#2a5166"), Color("#2c556a")]
const OUTSIDE := Color("#1b2a20")

const TEXT := Color("#e8e6e0")
const MUTED := Color("#8b8f98")
const CARD := Color("#1c2028")
const CARD_BORDER := Color("#262b34")
const BG := Color("#12151a")
const ACCENT := Color("#e08a55")
const GREEN := Color("#8fb89a")
const GREEN_DARK := Color("#6f9f7f")
const GOLD := Color("#f2c26b")
const SHADOW := Color(0, 0, 0, 0.22)


## Поставить холст так, чтобы квадрат 100×100 лёг в rect.
static func pen(ci: CanvasItem, rect: Rect2) -> void:
	var s := rect.size.x / 100.0
	ci.draw_set_transform(rect.position, 0.0, Vector2(s, s))

static func unpen(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)
	# Круглые концы — как strokeLinecap="round" в SVG.
	ci.draw_circle(a, w / 2.0, col)
	ci.draw_circle(b, w / 2.0, col)

## Кривая Безье второго порядка — для листьев, пламени и волн.
static func quad(a: Vector2, c: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts

static func cubic(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var ab := a.lerp(c1, t)
		var bc := c1.lerp(c2, t)
		var cd := c2.lerp(b, t)
		pts.append(ab.lerp(bc, t).lerp(bc.lerp(cd, t), t))
	return pts


# --- земля ----------------------------------------------------------------------------

static func ground_color(ground: int, v: int) -> Color:
	match ground:
		WorldGen.Ground.FOREST:
			return FOREST[v % 3]
		WorldGen.Ground.SHORE:
			return SHORE[v % 3]
		WorldGen.Ground.WATER:
			return WATER[v % 3]
	return GRASS[v % 3]

## Мелочи на земле: пучки травы, цветы, грибы, кувшинки. Только на пустых клетках.
static func ground_decor(ci: CanvasItem, ground: int, v: int) -> void:
	match ground:
		WorldGen.Ground.WATER:
			var dx := (v % 4) * 6.0
			ci.draw_polyline(quad(Vector2(14 + dx, 36), Vector2(24 + dx, 28), Vector2(34 + dx, 36)), Color("#3f6f86"), 3.5, true)
			ci.draw_polyline(quad(Vector2(34 + dx, 36), Vector2(44 + dx, 44), Vector2(54 + dx, 36)), Color("#3f6f86"), 3.5, true)
			ci.draw_polyline(quad(Vector2(34 - dx / 2, 70), Vector2(44 - dx / 2, 62), Vector2(54 - dx / 2, 70)), Color("#3f6f86"), 3.5, true)
			if v < 22:
				ci.draw_circle(Vector2(56, 52), 13, Color("#3f7a4a"))
				poly(ci, [Vector2(56, 52), Vector2(70, 46), Vector2(70, 56)], WATER[v % 3])
				if v < 8:
					ci.draw_circle(Vector2(50, 50), 4, TEXT)
		WorldGen.Ground.SHORE:
			if v < 60:
				var x := 30.0 + (v % 4) * 10
				line(ci, Vector2(x, 72), Vector2(x - 4, 50), Color("#6f8a5a"), 3)
				line(ci, Vector2(x + 6, 72), Vector2(x + 10, 46), Color("#6f8a5a"), 3)
				ellipse(ci, Vector2(x + 8, 44), 2.4, 6, Color("#7a5636"))
		_:
			var forest := ground == WorldGen.Ground.FOREST
			var blade := Color("#3a5c42") if forest else Color("#46684c")
			if v < 40:
				var x := 20.0 + (v % 5) * 12
				line(ci, Vector2(x, 70), Vector2(x - 5, 54), blade, 3)
				line(ci, Vector2(x, 70), Vector2(x + 1, 50), blade, 3)
				line(ci, Vector2(x, 70), Vector2(x + 7, 56), blade, 3)
			elif not forest and v < 52:
				var petal: Color = [TEXT, Color("#e8c96a"), Color("#b79ad6")][v % 3]
				var x := 30.0 + (v % 4) * 12
				var y := 36.0 + (v % 3) * 12
				line(ci, Vector2(x, y + 4), Vector2(x, y + 16), Color("#46684c"), 2.5)
				for o in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
					ci.draw_circle(Vector2(x, y) + o, 3.4, petal)
				ci.draw_circle(Vector2(x, y), 2.4, Color("#e0a24a"))
			elif forest and v < 50:
				ci.draw_rect(Rect2(47, 58, 6, 10), Color("#e3d6bf"))
				ellipse(ci, Vector2(50, 59), 10, 7, Color("#b8584a"))
				ci.draw_rect(Rect2(38, 59, 24, 6), ground_color(ground, v))
				ci.draw_circle(Vector2(46, 56), 1.6, Color("#f0e2d0"))
				ci.draw_circle(Vector2(54, 57), 1.4, Color("#f0e2d0"))
			elif v < 70:
				ci.draw_circle(Vector2(20 + (v % 7) * 9, 30 + (v % 5) * 10), 2, blade)


# --- что растёт и лежит ---------------------------------------------------------------

static func shadow(ci: CanvasItem, w := 26.0) -> void:
	ellipse(ci, Vector2(50, 84), w, 7, SHADOW)

## Рисунок того, что растёт на клетке. Начало холста — левый верхний угол клетки;
## деревья выше клетки и заходят на клетку сверху — так лес выглядит лесом, а не грядкой.
static func nature(ci: CanvasItem, id: String, depleted: bool, v: int, sway := 0.0) -> void:
	match id:
		"tree":
			if depleted:
				shadow(ci, 20)
				poly(ci, [Vector2(32, 66), Vector2(32, 78), Vector2(50, 83), Vector2(68, 78), Vector2(68, 66)], Color("#6b4b2e"))
				ellipse(ci, Vector2(50, 66), 18, 8, Color("#a5845a"))
				ellipse(ci, Vector2(50, 66), 10, 4, Color("#8a6a45"))
				ellipse(ci, Vector2(50, 66), 8, 3, Color("#a5845a"))
				ci.draw_polyline(cubic(Vector2(66, 70), Vector2(74, 66), Vector2(78, 70), Vector2(80, 74)), Color("#4a8254"), 3, true)
				return
			var s := sway
			if v % 3 == 0:
				# Ель: лес из одних круглых деревьев выглядит как обои.
				shadow(ci, 26)
				ci.draw_rect(Rect2(45, 70, 10, 16), Color("#5e412a"))
				poly(ci, [Vector2(50 + s, -14), Vector2(80 + s * 0.8, 30), Vector2(20 + s * 0.8, 30)], Color("#2f5e3d"))
				poly(ci, [Vector2(50 + s * 0.7, 6), Vector2(86 + s * 0.6, 54), Vector2(14 + s * 0.6, 54)], Color("#326843"))
				poly(ci, [Vector2(50 + s * 0.4, 28), Vector2(90 + s * 0.3, 76), Vector2(10 + s * 0.3, 76)], Color("#377049"))
				poly(ci, [Vector2(50 + s, -14), Vector2(58 + s, 0), Vector2(42 + s, 0)], Color("#3d7a50"))
			else:
				shadow(ci, 30)
				ci.draw_rect(Rect2(44, 50, 12, 36), Color("#6b4b2e"))
				ci.draw_circle(Vector2(50 + s * 0.6, 28), 36, Color("#3a6a44"))
				ci.draw_circle(Vector2(34 + s * 0.6, 24), 22, Color("#44794e"))
				ci.draw_circle(Vector2(64 + s * 0.8, 14), 19, Color("#4f8a59"))
				ci.draw_circle(Vector2(44 + s, 6), 12, Color("#5a9663"))
				if v % 5 == 1:
					for p in [Vector2(32, 34), Vector2(64, 38), Vector2(54, 20)]:
						ci.draw_circle(p + Vector2(s * 0.6, 0), 4, Color("#d86a4a"))
		"bush":
			shadow(ci, 28)
			ci.draw_circle(Vector2(34, 62), 20, Color("#3b6f46"))
			ci.draw_circle(Vector2(66, 60), 22, Color("#40784b"))
			ci.draw_circle(Vector2(50 + sway * 0.4, 44), 20, Color("#4a8756"))
			ci.draw_circle(Vector2(44 + sway * 0.4, 40), 8, Color("#56935f"))
			if not depleted:
				for p in [Vector2(38, 52), Vector2(58, 44), Vector2(66, 64), Vector2(46, 66), Vector2(28, 64)]:
					ci.draw_circle(p, 5.2, Color("#c9566a"))
					ci.draw_circle(p - Vector2(1.6, 1.6), 1.6, Color("#f2b8c2"))
		"rock":
			if depleted:
				ellipse(ci, Vector2(40, 70), 7, 5, Color("#7c8188"))
				ellipse(ci, Vector2(60, 74), 5, 4, Color("#8f949b"))
				return
			shadow(ci, 32)
			poly(ci, [Vector2(16, 78), Vector2(24, 42), Vector2(48, 24), Vector2(76, 32), Vector2(86, 70), Vector2(60, 84)], Color("#747980"))
			poly(ci, [Vector2(24, 42), Vector2(48, 24), Vector2(76, 32), Vector2(58, 48), Vector2(34, 52)], Color("#999ea5"))
			poly(ci, [Vector2(60, 84), Vector2(58, 48), Vector2(76, 32), Vector2(86, 70)], Color("#63686f"))
			ellipse(ci, Vector2(30, 72), 8, 3, Color(0.37, 0.54, 0.33, 0.8))
		"pebble":
			if depleted:
				return
			ellipse(ci, Vector2(38, 62), 12, 8, Color("#8a8f96"))
			ellipse(ci, Vector2(36, 59), 6, 3, Color("#a9aeb4"))
			ellipse(ci, Vector2(62, 68), 9, 6, Color("#9ea3aa"))
			ellipse(ci, Vector2(58, 50), 7, 5, Color("#7f848b"))
		"branch":
			if depleted:
				return
			line(ci, Vector2(22, 70), Vector2(78, 50), Color(0.35, 0.25, 0.16, 0.35), 8)
			line(ci, Vector2(22, 66), Vector2(78, 46), Color("#8a6440"), 6)
			line(ci, Vector2(50, 56), Vector2(60, 36), Color("#8a6440"), 4)
			line(ci, Vector2(30, 42), Vector2(64, 70), Color("#7a5636"), 5)
			ellipse(ci, Vector2(62, 34), 5, 3, Color("#5f9a62"))
		"wildcarrot":
			if depleted:
				ellipse(ci, Vector2(50, 74), 12, 5, Color("#4b3a2a"))
				return
			shadow(ci, 18)
			_carrot_tops(ci, Vector2(50 + sway * 0.4, 72), 1.0)
			# Белые зонтики цветов — так дикую морковь и узнают.
			for p in [Vector2(36, 30), Vector2(58, 24), Vector2(66, 40)]:
				line(ci, Vector2(50, 70), p + Vector2(sway * 0.5, 4), Color("#5a8a52"), 2)
				ellipse(ci, p + Vector2(sway * 0.5, 0), 9, 5, Color("#ece8dc"))
				ellipse(ci, p + Vector2(sway * 0.5, -1), 5, 2.5, Color("#fbf9f2"))
			ellipse(ci, Vector2(50, 76), 6, 4, Color("#e08a3c"))
		"sunflower":
			_sunflower(ci, 3, depleted, sway)


## Ботва моркови: пучок перистых листьев из точки base.
static func _carrot_tops(ci: CanvasItem, base: Vector2, k: float) -> void:
	for a in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		var tip := base + Vector2(sin(a) * 22.0, -cos(a) * 30.0) * k
		line(ci, base, tip, Color("#4f9a55"), 3.0 * k + 1.0)
		ellipse(ci, tip, 6.0 * k, 4.0 * k, Color("#5fae62"))

## Подсолнух: 0 — росток, 1 — листья, 2 — стебель с бутоном, 3 — цветёт. Выше клетки.
static func _sunflower(ci: CanvasItem, stage: int, depleted: bool, sway := 0.0) -> void:
	if stage == 0:
		line(ci, Vector2(50, 76), Vector2(50, 62), Color("#5a9a52"), 3)
		ellipse(ci, Vector2(44, 62), 7, 4, Color("#6fb266"))
		ellipse(ci, Vector2(56, 60), 7, 4, Color("#6fb266"))
		return
	var top := Vector2(50 + sway, 20.0 if stage == 1 else (-4.0 if stage == 2 else -18.0))
	shadow(ci, 16)
	ci.draw_polyline(quad(Vector2(50, 80), Vector2(48, (80 + top.y) / 2), top), Color("#4f8a45"), 5, true)
	for y in [60.0, 42.0, 24.0]:
		if y < top.y:
			continue
		ellipse(ci, Vector2(38, y), 11, 6, Color("#5a9a4e"))
		ellipse(ci, Vector2(62, y - 6), 11, 6, Color("#62a456"))
	if stage == 1:
		return
	if stage == 2:
		ci.draw_circle(top, 8, Color("#6f9a48"))
		return
	if not depleted:
		for i in 12:
			var ang := TAU * i / 12.0
			ellipse(ci, top + Vector2(cos(ang), sin(ang)) * 16, 7, 7, Color("#f2c23a"))
		ci.draw_circle(top, 12, Color("#6b4a2a"))
		for i in 6:
			ci.draw_circle(top + Vector2(cos(i), sin(i * 1.7)) * 6, 1.6, Color("#4a321c"))
	else:
		ci.draw_circle(top, 9, Color("#7a6040"))


# --- постройки ------------------------------------------------------------------------

static func structure(ci: CanvasItem, id: String, lit: bool, flicker := 0.0, look := "") -> void:
	match id:
		"bed":
			var parts := look.split(":")
			var crop := parts[0] if parts.size() > 0 else ""
			var stage := int(parts[1]) if parts.size() > 1 else 0
			var wet := parts.size() > 2 and parts[2] == "1"
			ci.draw_rect(Rect2(8, 26, 84, 66), Color("#7a5636"))
			ci.draw_rect(Rect2(14, 32, 72, 54), Color("#3b2a1e") if wet else Color("#5a4230"))
			for y in [44.0, 58.0, 72.0]:
				ci.draw_line(Vector2(18, y), Vector2(82, y), Color("#33241a") if wet else Color("#4c3727"), 3)
			if wet:
				ellipse(ci, Vector2(32, 50), 6, 2.5, Color(0.55, 0.75, 0.9, 0.35))
				ellipse(ci, Vector2(66, 66), 7, 2.5, Color(0.55, 0.75, 0.9, 0.35))
			if crop == "carrot":
				for p in [Vector2(32, 62), Vector2(68, 62)]:
					if stage == 0:
						line(ci, p + Vector2(0, 8), p + Vector2(-4, 0), Color("#6fb266"), 3)
						line(ci, p + Vector2(0, 8), p + Vector2(4, -2), Color("#6fb266"), 3)
					else:
						_carrot_tops(ci, p + Vector2(0, 10), 0.45 + stage * 0.2)
						if stage == 3:
							ellipse(ci, p + Vector2(0, 12), 7, 4, Color("#e8873a"))
			elif crop == "sunflower":
				_sunflower(ci, stage, false)

		"campfire":
			for p in [Vector2(26, 74), Vector2(36, 82), Vector2(50, 85), Vector2(64, 82), Vector2(74, 74)]:
				ellipse(ci, p, 7, 5, Color("#80858c"))
			line(ci, Vector2(30, 76), Vector2(70, 62), Color("#6b4b2e"), 8)
			line(ci, Vector2(30, 62), Vector2(70, 76), Color("#7a5636"), 8)
			var f := flicker
			ci.draw_colored_polygon(_flame(Vector2(50, 66), 22.0 + f * 3, 48.0 + f * 6), ACCENT)
			ci.draw_colored_polygon(_flame(Vector2(50, 66), 11.0 + f * 2, 28.0 + f * 4), GOLD)
		"workbench":
			shadow(ci, 34)
			ci.draw_rect(Rect2(12, 38, 76, 14), Color("#a07a4e"))
			ci.draw_rect(Rect2(18, 52, 9, 32), Color("#7a5636"))
			ci.draw_rect(Rect2(73, 52, 9, 32), Color("#7a5636"))
			ci.draw_rect(Rect2(18, 68, 64, 5), Color("#7a5636"))
			ci.draw_rect(Rect2(26, 29, 18, 9), Color("#8f949b"))
			line(ci, Vector2(54, 34), Vector2(76, 28), Color("#6b4b2e"), 5)
		"fence":
			ci.draw_rect(Rect2(0, 42, 100, 8), Color("#9a7a52"))
			ci.draw_rect(Rect2(0, 62, 100, 8), Color("#9a7a52"))
			for x in [14.0, 64.0]:
				ellipse(ci, Vector2(x + 11, 86), 12, 4, SHADOW)
				poly(ci, [Vector2(x, 30), Vector2(x + 11, 20), Vector2(x + 22, 30), Vector2(x + 22, 86), Vector2(x, 86)], Color("#8a6a45"))
		"coop":
			var eggs := int(look.trim_prefix("eggs:")) if look.begins_with("eggs:") else 0
			shadow(ci, 40)
			ci.draw_rect(Rect2(14, 34, 72, 50), Color("#b4905e"))
			for x in [26.0, 40.0, 54.0, 68.0]:
				ci.draw_line(Vector2(x, 36), Vector2(x, 84), Color("#9a774b"), 2)
			poly(ci, [Vector2(6, 38), Vector2(50, 4), Vector2(94, 38)], Color("#a8563c"))
			poly(ci, [Vector2(6, 38), Vector2(50, 4), Vector2(50, 12), Vector2(15, 38)], Color("#bd6a4c"))
			ci.draw_rect(Rect2(38, 54, 24, 30), Color("#3a2618"))
			ellipse(ci, Vector2(50, 54), 12, 8, Color("#3a2618"))
			# Соломка у входа и лесенка.
			for i in 5:
				line(ci, Vector2(40 + i * 5, 84), Vector2(36 + i * 6, 90), Color("#e0c070"), 2)
			line(ci, Vector2(62, 84), Vector2(78, 94), Color("#8a6a45"), 5)
			for i in eggs:
				ellipse(ci, Vector2(44 + (i % 3) * 7, 80 - (i / 3) * 6), 3.6, 4.6, Color("#f4ecdc"))
		"house":
			# Домик выше клетки: крыша заходит на клетку сверху.
			ellipse(ci, Vector2(50, 92), 46, 7, Color(0, 0, 0, 0.25))
			ci.draw_rect(Rect2(10, 36, 80, 56), Color("#b08a5a"))
			for y in [52.0, 70.0]:
				ci.draw_line(Vector2(10, y), Vector2(90, y), Color("#9a7650"), 2)
			ci.draw_rect(Rect2(68, -14, 10, 26), Color("#6b4b2e"))
			poly(ci, [Vector2(0, 40), Vector2(50, -10), Vector2(100, 40)], Color("#8e4f3a"))
			poly(ci, [Vector2(0, 40), Vector2(50, -10), Vector2(50, -2), Vector2(9, 40)], Color("#a55e46"))
			ci.draw_rect(Rect2(42, 62, 16, 30), Color("#5a3a24"))
			ci.draw_circle(Vector2(54, 78), 1.8, Color("#e0a24a"))
			var window := GOLD if lit else Color("#3d5566")
			ci.draw_rect(Rect2(19, 56, 15, 13), window)
			ci.draw_rect(Rect2(66, 56, 15, 13), window)
			ci.draw_line(Vector2(26.5, 56), Vector2(26.5, 69), Color("#6b4b2e"), 1.6)
			ci.draw_line(Vector2(73.5, 56), Vector2(73.5, 69), Color("#6b4b2e"), 1.6)

static func _packet(ci: CanvasItem, col: Color) -> void:
	_round_rect(ci, Rect2(24, 18, 52, 70), 6, col)
	ci.draw_rect(Rect2(24, 18, 52, 12), col.darkened(0.2))

static func heart(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var r := size * 0.3
	ci.draw_circle(c + Vector2(-r, -r * 0.3), r, col)
	ci.draw_circle(c + Vector2(r, -r * 0.3), r, col)
	poly(ci, [c + Vector2(-r * 1.95, 0), c + Vector2(r * 1.95, 0), c + Vector2(0, size * 0.75)], col)


# --- звери ----------------------------------------------------------------------------

## Зверь на клетке 100×100, точка опоры — низ посередине (50, 90). `phase` — фаза шага.
static func animal(ci: CanvasItem, kind: String, dir: Vector2, phase: float, moving: bool, lift := 0.0) -> void:
	var flip := -1.0 if dir.x < -0.1 else 1.0
	match kind:
		"hare":
			var hop := absf(sin(phase * TAU)) * (14.0 if moving else 0.0)
			ellipse(ci, Vector2(50, 90), 20 - hop * 0.5, 5, Color(0, 0, 0, 0.25))
			var o := Vector2(0, -hop)
			var bodyc := Color("#a08a70")
			ellipse(ci, Vector2(48, 72) + o, 20, 15, bodyc)
			ci.draw_circle(Vector2(50 - 20 * flip, 70) + o, 6, Color("#efe6da"))
			var head := Vector2(50 + 16 * flip, 58) + o
			ci.draw_circle(head, 11, bodyc)
			ellipse(ci, head + Vector2(-3 * flip, -18), 4, 13, bodyc)
			ellipse(ci, head + Vector2(4 * flip, -17), 4, 13, Color("#b29a80"))
			ellipse(ci, head + Vector2(4 * flip, -16), 2, 9, Color("#e2b8b0"))
			ci.draw_circle(head + Vector2(5 * flip, -2), 2.2, Color("#2a2a2a"))
			ci.draw_circle(head + Vector2(10 * flip, 3), 1.8, Color("#c9868a"))
			ellipse(ci, Vector2(58 + 4 * flip, 86) + o, 6, 3, Color("#8a7458"))
		"chicken":
			var peck := 0.0 if moving else maxf(0.0, sin(phase * TAU * 2.0)) * 8.0
			var step := sin(phase * TAU) * (4.0 if moving else 0.0)
			ellipse(ci, Vector2(50, 90), 16, 4, Color(0, 0, 0, 0.25))
			line(ci, Vector2(46 + step, 80), Vector2(46 + step, 89), Color("#e0a040"), 2.5)
			line(ci, Vector2(54 - step, 80), Vector2(54 - step, 89), Color("#e0a040"), 2.5)
			ellipse(ci, Vector2(48, 70), 17, 13, Color("#f2ece0"))
			poly(ci, [Vector2(50 - 14 * flip, 66), Vector2(50 - 26 * flip, 54), Vector2(50 - 22 * flip, 70)], Color("#e8e0d0"))
			ellipse(ci, Vector2(46, 72), 9, 6, Color("#ddd4c2"))
			var head := Vector2(50 + 14 * flip, 54 + peck)
			ci.draw_circle(head, 8, Color("#f2ece0"))
			ci.draw_circle(head + Vector2(-1 * flip, -8), 3.5, Color("#d8483a"))
			ci.draw_circle(head + Vector2(3 * flip, -8), 3, Color("#d8483a"))
			poly(ci, [head + Vector2(7 * flip, -1), head + Vector2(13 * flip, 1), head + Vector2(7 * flip, 3)], Color("#e8a040"))
			ci.draw_circle(head + Vector2(3 * flip, -2), 1.6, Color("#2a2a2a"))
		"bird":
			var up := Vector2(0, -lift * 30.0)
			if lift < 0.2:
				ellipse(ci, Vector2(50, 90), 7, 2, Color(0, 0, 0, 0.2))
			var flap := sin(phase * TAU) * (12.0 if lift > 0.0 else 0.0)
			var b := Vector2(50, 80) + up
			ellipse(ci, b, 9, 6, Color("#7a6250"))
			ci.draw_circle(b + Vector2(7 * flip, -4), 4.5, Color("#7a6250"))
			poly(ci, [b + Vector2(11 * flip, -5), b + Vector2(15 * flip, -4), b + Vector2(11 * flip, -3)], Color("#e0a040"))
			ellipse(ci, b + Vector2(1 * flip, 1), 5, 3, Color("#d8a078"))
			poly(ci, [b + Vector2(-2 * flip, -2), b + Vector2(-10 * flip, -4 - flap), b + Vector2(4 * flip, -1)], Color("#5e4a3a"))

## Язык пламени: капля, узкая сверху.
static func _flame(base: Vector2, w: float, h: float) -> PackedVector2Array:
	var top := base + Vector2(0, -h)
	var pts := cubic(base + Vector2(-w * 0.45, 0), base + Vector2(-w * 0.6, -h * 0.5), top + Vector2(-w * 0.1, h * 0.2), top, 8)
	pts.append_array(cubic(top, top + Vector2(w * 0.1, h * 0.2), base + Vector2(w * 0.6, -h * 0.5), base + Vector2(w * 0.45, 0), 8))
	pts.append_array(quad(base + Vector2(w * 0.45, 0), base + Vector2(0, h * 0.12), base + Vector2(-w * 0.45, 0), 6))
	return pts


# --- персонаж -------------------------------------------------------------------------

## Персонаж. `dir` — куда смотрит; `phase` — фаза шага (0–1), от неё качаются ноги.
static func player(ci: CanvasItem, dir: Vector2, phase: float, moving: bool, color: Color) -> void:
	var side := 0
	if absf(dir.x) > absf(dir.y):
		side = 1 if dir.x > 0 else -1
	var back := side == 0 and dir.y < 0
	var swing := sin(phase * TAU) * (6.0 if moving else 0.0)
	var bob := absf(sin(phase * TAU)) * (2.5 if moving else 0.0)
	ellipse(ci, Vector2(50, 92), 20, 6, Color(0, 0, 0, 0.28))
	ci.draw_rect(Rect2(40 + swing * 0.5, 74, 8, 16), Color("#3d4450"))
	ci.draw_rect(Rect2(52 - swing * 0.5, 74, 8, 16), Color("#3d4450"))
	var up := Vector2(0, -bob)
	if back:
		ci.draw_rect(Rect2(Vector2(34, 46) + up, Vector2(32, 26)), Color("#7a5636"))
	_round_rect(ci, Rect2(Vector2(32, 46) + up, Vector2(36, 32)), 13, color)
	if not back and side != 0:
		_round_rect(ci, Rect2(Vector2(30 if side > 0 else 58, 50) + up, Vector2(12, 20)), 5, Color("#7a5636"))
	var head := Vector2(50 + side * 2, 32) + up
	ci.draw_circle(head, 17, Color("#e3cdb0"))
	# Волосы: шапка сверху головы.
	var hair := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		hair.append(head + Vector2(cos(a) * 17.5, sin(a) * 17.5 + 2))
	hair.append(head + Vector2(10, -6))
	hair.append(head + Vector2(-10, -6))
	ci.draw_colored_polygon(hair, Color("#5a3a24"))
	if back:
		ci.draw_circle(head + Vector2(0, -1), 15, Color("#5a3a24"))
	elif side == 0:
		ci.draw_circle(head + Vector2(-7, 3), 2.6, Color("#2a2a2a"))
		ci.draw_circle(head + Vector2(7, 3), 2.6, Color("#2a2a2a"))
		ci.draw_polyline(quad(head + Vector2(-5, 10), head + Vector2(0, 13), head + Vector2(5, 10), 6), Color("#b0876a"), 2, true)
	else:
		ci.draw_circle(head + Vector2(side * 9, 3), 2.6, Color("#2a2a2a"))

static func _round_rect(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2, 0)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, rad), r.size - Vector2(0, rad * 2)), col)
	for c in [r.position + Vector2(rad, rad), r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(rad, r.size.y - rad), r.position + r.size - Vector2(rad, rad)]:
		ci.draw_circle(c, rad, col)


# --- значки вещей ---------------------------------------------------------------------

## Значок вещи — для сумки, панели вещей и кнопки действия. Рисуется в квадрат rect.
static func item_icon(ci: CanvasItem, id: String, rect: Rect2) -> void:
	pen(ci, rect)
	match id:
		"stick":
			line(ci, Vector2(20, 80), Vector2(80, 20), Color("#8a6440"), 10)
			line(ci, Vector2(52, 48), Vector2(72, 58), Color("#8a6440"), 7)
			line(ci, Vector2(38, 62), Vector2(32, 42), Color("#7a5636"), 6)
			ellipse(ci, Vector2(70, 60), 6, 4, Color("#5f9a62"))
		"stone":
			poly(ci, [Vector2(16, 70), Vector2(26, 36), Vector2(52, 22), Vector2(80, 34), Vector2(86, 66), Vector2(58, 82)], Color("#7c8188"))
			poly(ci, [Vector2(26, 36), Vector2(52, 22), Vector2(80, 34), Vector2(60, 48), Vector2(36, 50)], Color("#9ea3aa"))
			poly(ci, [Vector2(58, 82), Vector2(60, 48), Vector2(80, 34), Vector2(86, 66)], Color("#6a6f76"))
		"log":
			_round_rect(ci, Rect2(14, 34, 66, 34), 8, Color("#7a5636"))
			ci.draw_line(Vector2(24, 44), Vector2(62, 44), Color("#6b4b2e"), 3)
			ci.draw_line(Vector2(20, 58), Vector2(56, 58), Color("#6b4b2e"), 3)
			ellipse(ci, Vector2(78, 51), 12, 17, Color("#a5845a"))
			ellipse(ci, Vector2(78, 51), 6, 9, Color("#8a6a45"))
			ellipse(ci, Vector2(78, 51), 4, 6, Color("#a5845a"))
		"berries":
			ci.draw_polyline(quad(Vector2(50, 14), Vector2(56, 28), Vector2(74, 30)), Color("#4d8b58"), 5, true)
			ellipse(ci, Vector2(66, 24), 12, 6, Color("#5f9a62"))
			ci.draw_circle(Vector2(36, 58), 16, Color("#c9566a"))
			ci.draw_circle(Vector2(62, 62), 16, Color("#b44659"))
			ci.draw_circle(Vector2(48, 40), 14, Color("#d86a7c"))
			ci.draw_circle(Vector2(44, 36), 4, Color("#f2b8c2"))
			ci.draw_circle(Vector2(30, 52), 4, Color("#f2b8c2"))
		"axe":
			line(ci, Vector2(30, 86), Vector2(66, 22), Color("#8a6440"), 9)
			poly(ci, [Vector2(56, 14), Vector2(72, 10), Vector2(86, 22), Vector2(88, 44), Vector2(70, 40), Vector2(60, 34)], Color("#b7bcc3"))
			ci.draw_polyline(quad(Vector2(88, 44), Vector2(86, 28), Vector2(72, 22)), Color("#e6e8eb"), 3, true)
		"pickaxe":
			line(ci, Vector2(30, 86), Vector2(58, 28), Color("#8a6440"), 9)
			var top := quad(Vector2(14, 34), Vector2(52, 4), Vector2(90, 28))
			top.append_array(quad(Vector2(90, 28), Vector2(52, 14), Vector2(14, 34)))
			ci.draw_colored_polygon(top, Color("#b7bcc3"))
		"campfire":
			line(ci, Vector2(22, 80), Vector2(78, 62), Color("#6b4b2e"), 10)
			line(ci, Vector2(22, 62), Vector2(78, 80), Color("#7a5636"), 10)
			ci.draw_colored_polygon(_flame(Vector2(50, 68), 36, 58), ACCENT)
			ci.draw_colored_polygon(_flame(Vector2(50, 68), 18, 34), GOLD)
		"workbench":
			ci.draw_rect(Rect2(10, 34, 80, 16), Color("#a07a4e"))
			ci.draw_rect(Rect2(16, 50, 10, 36), Color("#7a5636"))
			ci.draw_rect(Rect2(74, 50, 10, 36), Color("#7a5636"))
			ci.draw_rect(Rect2(16, 66, 68, 6), Color("#7a5636"))
			ci.draw_rect(Rect2(28, 24, 20, 10), Color("#8f949b"))
			line(ci, Vector2(58, 30), Vector2(80, 22), Color("#6b4b2e"), 5)
		"fence":
			ci.draw_rect(Rect2(8, 40, 84, 9), Color("#9a7a52"))
			ci.draw_rect(Rect2(8, 62, 84, 9), Color("#9a7a52"))
			for x in [14.0, 44.0, 74.0]:
				poly(ci, [Vector2(x, 28), Vector2(x + 6, 20), Vector2(x + 12, 28), Vector2(x + 12, 86), Vector2(x, 86)], Color("#8a6a45"))
		"house":
			ci.draw_rect(Rect2(18, 46, 64, 42), Color("#b08a5a"))
			poly(ci, [Vector2(8, 50), Vector2(50, 12), Vector2(92, 50)], Color("#8e4f3a"))
			ci.draw_rect(Rect2(42, 62, 16, 26), Color("#5a3a24"))
			ci.draw_rect(Rect2(24, 56, 12, 12), GOLD)
			ci.draw_rect(Rect2(64, 56, 12, 12), GOLD)
			ci.draw_rect(Rect2(64, 20, 10, 18), Color("#6b4b2e"))
		"sleep":
			var moon := cubic(Vector2(62, 16), Vector2(36, 16), Vector2(20, 42), Vector2(24, 62))
			moon.append_array(cubic(Vector2(24, 62), Vector2(28, 84), Vector2(52, 94), Vector2(68, 86)))
			moon.append_array(cubic(Vector2(68, 86), Vector2(46, 80), Vector2(36, 62), Vector2(40, 46)))
			moon.append_array(cubic(Vector2(40, 46), Vector2(42, 32), Vector2(50, 22), Vector2(62, 16)))
			ci.draw_colored_polygon(moon, GOLD)
			ci.draw_circle(Vector2(74, 30), 4, GOLD)
			ci.draw_circle(Vector2(82, 52), 3, GOLD)
		"water":
			var drop := cubic(Vector2(50, 12), Vector2(62, 32), Vector2(76, 46), Vector2(76, 62))
			drop.append_array(cubic(Vector2(76, 62), Vector2(76, 80), Vector2(62, 88), Vector2(50, 88)))
			drop.append_array(cubic(Vector2(50, 88), Vector2(36, 88), Vector2(24, 78), Vector2(24, 62)))
			drop.append_array(cubic(Vector2(24, 62), Vector2(24, 46), Vector2(38, 32), Vector2(50, 12)))
			ci.draw_colored_polygon(drop, Color("#4d7d94"))
			ci.draw_polyline(quad(Vector2(38, 62), Vector2(38, 76), Vector2(52, 76)), Color("#a9cfe0"), 5, true)
		"hand":
			ci.draw_arc(Vector2(50, 50), 26, 0, TAU, 32, MUTED, 5, true)
			ci.draw_circle(Vector2(50, 50), 8, MUTED)
		"carrot":
			var body := PackedVector2Array([Vector2(58, 30), Vector2(74, 44), Vector2(30, 90)])
			ci.draw_colored_polygon(body, Color("#e8873a"))
			ci.draw_circle(Vector2(66, 37), 11, Color("#e8873a"))
			for p in [[Vector2(52, 58), Vector2(60, 62)], [Vector2(42, 72), Vector2(48, 76)]]:
				line(ci, p[0], p[1], Color("#c96a28"), 3)
			for a in [-0.5, 0.0, 0.5]:
				line(ci, Vector2(70, 32), Vector2(70, 32) + Vector2(sin(a + 0.7), -cos(a + 0.7)) * 26, Color("#4f9a55"), 5)
		"carrot_seed":
			_packet(ci, Color("#d9b27a"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(46, 46), Vector2(56, 52), Vector2(38, 76)]), Color("#e8873a"))
			line(ci, Vector2(52, 48), Vector2(60, 36), Color("#4f9a55"), 4)
		"sunflower_seed":
			for p in [Vector2(34, 40), Vector2(62, 36), Vector2(46, 64), Vector2(70, 64), Vector2(28, 70)]:
				var pts := PackedVector2Array()
				for i in 16:
					var t := TAU * i / 16.0
					pts.append(p + Vector2(cos(t) * 8, sin(t) * 14 * (0.7 if sin(t) < 0 else 1.0)))
				ci.draw_colored_polygon(pts, Color("#3a3230"))
				line(ci, p + Vector2(0, -8), p + Vector2(0, 10), Color("#d8d0c0"), 2)
		"egg":
			ellipse(ci, Vector2(50, 56), 26, 32, Color("#f4ecdc"))
			ellipse(ci, Vector2(42, 44), 7, 10, Color("#ffffff"))
		"can":
			_round_rect(ci, Rect2(24, 36, 44, 46), 8, Color("#6f8fa0"))
			line(ci, Vector2(66, 50), Vector2(88, 30), Color("#6f8fa0"), 8)
			ellipse(ci, Vector2(89, 29), 6, 4, Color("#8fb0c0"))
			ci.draw_arc(Vector2(46, 38), 16, PI, TAU, 16, Color("#58778a"), 5, true)
			ci.draw_rect(Rect2(24, 52, 44, 6), Color("#58778a"))
		"bed":
			ci.draw_rect(Rect2(10, 30, 80, 56), Color("#7a5636"))
			ci.draw_rect(Rect2(16, 36, 68, 44), Color("#5a4230"))
			for x in [32.0, 50.0, 68.0]:
				line(ci, Vector2(x, 60), Vector2(x - 6, 46), Color("#6fb266"), 4)
				line(ci, Vector2(x, 60), Vector2(x + 6, 46), Color("#6fb266"), 4)
		"coop":
			ci.draw_rect(Rect2(18, 44, 64, 44), Color("#b4905e"))
			poly(ci, [Vector2(8, 48), Vector2(50, 12), Vector2(92, 48)], Color("#a8563c"))
			ci.draw_rect(Rect2(40, 60, 20, 28), Color("#3a2618"))
			ellipse(ci, Vector2(50, 60), 10, 7, Color("#3a2618"))
		"sprout":
			line(ci, Vector2(50, 84), Vector2(50, 46), Color("#4f9a55"), 6)
			ellipse(ci, Vector2(34, 44), 16, 9, Color("#6fb266"))
			ellipse(ci, Vector2(66, 36), 16, 9, Color("#6fb266"))
			ellipse(ci, Vector2(50, 88), 26, 6, Color("#5a4230"))
		"heart":
			heart(ci, Vector2(50, 54), 30, Color("#e0788a"))
	unpen(ci)
