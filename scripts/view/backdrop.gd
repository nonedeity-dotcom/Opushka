## Вода позади всего: сверху светлее — там поверхность и солнце, вниз темнее. По воде
## медленно ходят косые лучи света. Рисуется в координатах экрана, под океаном.
extends Control

var t := 0.0
## Смещение камеры — лучи чуть сдвигаются, когда плывёшь, и вода не кажется картинкой.
var drift := Vector2.ZERO
## Цвет воды плавно меняется, когда переплываешь из одной воды в другую.
var biome := "shallows"
var _top := Color("#1d5566")
var _bottom := Color("#071219")
var _light := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	t += delta
	var def: Dictionary = Content.BIOMES.get(biome, Content.BIOMES.shallows)
	var k := 1.0 - exp(-1.5 * delta)
	_top = _top.lerp(Color(def.top), k)
	_bottom = _bottom.lerp(Color(def.bottom), k)
	_light = lerpf(_light, 0.35 if biome == "deep" else 1.0, k)
	queue_redraw()

func _draw() -> void:
	# Градиент — цветами вершин, без текстуры: раньше текстура градиента пересобиралась и
	# заново уходила в видеокарту каждый кадр, и на телефоне это тормозило.
	var mid := _top.lerp(_bottom, 0.45)
	var y := size.y * 0.45
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, y), Vector2(0, y)]),
		PackedColorArray([_top, _top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y), size, Vector2(0, size.y)]),
		PackedColorArray([mid, mid, _bottom, _bottom]))
	# Лучи: широкие наклонные полосы, едва заметные, каждая дышит по-своему.
	for i in 5:
		var x := fmod(i * 0.27 * size.x + drift.x * 0.05 + sin(t * 0.07 + i) * 40.0, size.x * 1.4) - size.x * 0.2
		var w := size.x * (0.08 + 0.05 * sin(i * 1.7))
		var a := (0.035 + 0.025 * sin(t * 0.4 + i * 2.1)) * _light
		var slant := size.y * 0.35
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - slant, size.y), Vector2(x - slant, size.y)]),
			Color(0.75, 0.95, 1.0, maxf(0.0, a)))
