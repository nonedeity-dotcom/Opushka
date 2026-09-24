## Мелкая жизнь вокруг: бабочки днём, светлячки ночью. Ни на что не влияют — просто есть.
##
## Живут в квадрате вокруг середины экрана и перелетают на другую сторону, если ты ушёл,
## поэтому их немного, а видно всегда.
extends Node2D

const COUNT := 14
const AREA := 11.0  # сторона квадрата в клетках

var _bugs: Array[Dictionary] = []
var _night := 0.0
var _t := 0.0

func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in COUNT:
		_bugs.append({
			"p": Vector2(r.randf() - 0.5, r.randf() - 0.5) * AREA,
			"v": Vector2.from_angle(r.randf() * TAU) * (0.3 + r.randf() * 0.4),
			"k": r.randf() * TAU,
			"c": [Color("#f2e6a0"), Color("#e8b8d8"), Color("#b8d4f0")][i % 3],
		})

## Каждый кадр: где середина экрана (в точках мира) и насколько темно.
func update(v: Village, center: Vector2, darkness: float) -> void:
	_night = darkness
	var dt := get_process_delta_time()
	_t += dt
	var mid := center / Art.TILE
	for b in _bugs:
		b.k += dt * (1.3 if darkness > 0.5 else 5.0)
		b.v = b.v.rotated(sin(_t * 0.7 + b.k) * dt * 1.5)
		b.p += b.v * dt
		var rel: Vector2 = b.p - mid
		# Ушёл далеко — букашка «перелетает» на другую сторону экрана.
		if absf(rel.x) > AREA / 2.0:
			b.p.x -= signf(rel.x) * AREA
		if absf(rel.y) > AREA:
			b.p.y -= signf(rel.y) * AREA * 2.0
	queue_redraw()

func _draw() -> void:
	var day := 1.0 - _night
	for i in _bugs.size():
		var b: Dictionary = _bugs[i]
		var at: Vector2 = b.p * Art.TILE
		if _night > 0.3:
			# Светлячок: мерцающая точка с ореолом.
			var glow := (0.5 + 0.5 * sin(b.k * 2.0)) * (_night - 0.3) / 0.7
			draw_circle(at, 9, Color(0.85, 1.0, 0.45, 0.12 * glow))
			draw_circle(at, 4, Color(0.85, 1.0, 0.45, 0.35 * glow))
			draw_circle(at, 1.8, Color(1, 1, 0.8, 0.9 * glow))
		elif i % 3 == 0 and day > 0.7:
			# Бабочка — только каждая третья: днём их меньше, чем светлячков ночью.
			var flap := absf(sin(b.k)) * 6.0 + 1.0
			var col: Color = b.c
			draw_rect(Rect2(at + Vector2(-flap - 1, -4), Vector2(flap, 7)), col)
			draw_rect(Rect2(at + Vector2(1, -4), Vector2(flap, 7)), col)
			draw_line(at + Vector2(0, -4), at + Vector2(0, 4), Color("#3a3230"), 1.5)
