## Вода позади всего: сверху светлее — там поверхность и солнце, вниз темнее. По воде
## медленно ходят косые лучи света. Рисуется в координатах экрана, под океаном.
extends Control

var t := 0.0
## Смещение камеры — лучи чуть сдвигаются, когда плывёшь, и вода не кажется картинкой.
var drift := Vector2.ZERO
var _grad: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color("#1d5566"))
	g.set_color(1, Color("#071219"))
	g.add_point(0.45, Color("#113544"))
	_grad = GradientTexture2D.new()
	_grad.gradient = g
	_grad.fill_from = Vector2(0.5, 0.0)
	_grad.fill_to = Vector2(0.5, 1.0)
	_grad.width = 8
	_grad.height = 256

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(_grad, Rect2(Vector2.ZERO, size), false)
	# Лучи: широкие наклонные полосы, едва заметные, каждая дышит по-своему.
	for i in 5:
		var x := fmod(i * 0.27 * size.x + drift.x * 0.05 + sin(t * 0.07 + i) * 40.0, size.x * 1.4) - size.x * 0.2
		var w := size.x * (0.08 + 0.05 * sin(i * 1.7))
		var a := 0.035 + 0.025 * sin(t * 0.4 + i * 2.1)
		var slant := size.y * 0.35
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - slant, size.y), Vector2(x - slant, size.y)]),
			Color(0.75, 0.95, 1.0, maxf(0.0, a)))
