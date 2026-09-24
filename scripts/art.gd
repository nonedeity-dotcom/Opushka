## Палитра и рисовальные мелочи — общие для океана и интерфейса.
##
## Картинок-файлов нет: всё рисуется фигурами. `pen` ставит холст так, что квадрат 100×100
## ложится в нужный прямоугольник, — значки рисуются в этих числах.
class_name Art
extends RefCounted

const TEXT := Color("#e8e6e0")
const MUTED := Color("#8b8f98")
const CARD := Color("#16222b")
const CARD_BORDER := Color("#22313c")
const BG := Color("#0c141a")
const ACCENT := Color("#e08a55")
const GREEN := Color("#8fd0b0")
const GREEN_DARK := Color("#5fa88a")
const GOLD := Color("#f2c26b")
const DANGER := Color("#e0605a")
const WATER_DEEP := Color("#0b1c26")
const WATER := Color("#12303d")
const PLANT := Color("#7ccf6a")
const MEAT := Color("#d8646a")

## Поставить холст так, чтобы квадрат 100×100 лёг в rect.
static func pen(ci: CanvasItem, rect: Rect2) -> void:
	var s := rect.size.x / 100.0
	ci.draw_set_transform(rect.position, 0.0, Vector2(s, s))

static func unpen(ci: CanvasItem) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, n := 20) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	ci.draw_colored_polygon(pts, col)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w / 2.0, col)
	ci.draw_circle(b, w / 2.0, col)

static func quad(a: Vector2, c: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts

static func round_rect(ci: CanvasItem, r: Rect2, radius: float, col: Color) -> void:
	var rad := minf(radius, minf(r.size.x, r.size.y) / 2.0)
	ci.draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2, 0)), col)
	ci.draw_rect(Rect2(r.position + Vector2(0, rad), r.size - Vector2(0, rad * 2)), col)
	for c in [r.position + Vector2(rad, rad), r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(rad, r.size.y - rad), r.position + r.size - Vector2(rad, rad)]:
		ci.draw_circle(c, rad, col)

static func heart(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var r := size * 0.3
	ci.draw_circle(c + Vector2(-r, -r * 0.3), r, col)
	ci.draw_circle(c + Vector2(r, -r * 0.3), r, col)
	poly(ci, [c + Vector2(-r * 1.95, 0), c + Vector2(r * 1.95, 0), c + Vector2(0, size * 0.75)], col)
