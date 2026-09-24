## Вода позади всего: сверху светлее — там поверхность и солнце, вниз темнее. По воде
## медленно ходят косые лучи света. Рисуется в координатах экрана, под океаном.
extends Control

var t := 0.0
## Смещение камеры — лучи чуть сдвигаются, когда плывёшь, и вода не кажется картинкой.
var drift := Vector2.ZERO
## Цвет воды плавно меняется с размером: на каждом — свой оттенок, яркость та же.
var _top := Color("#1d5566")
var _bottom := Color("#071219")
var _light := 1.0
## Тени в глубине: те, кто встретится на следующих размерах. Крупнее и медленнее мира
## впереди (дальше — значит, при движении сдвигаются меньше) — сразу видно, что это фон.
var level := 1
var zoom := 1.0
var player_r := 16.0
var _ghosts: Array = []  # [{id, p, dir, speed, parts, shape}]
var _ghost_level := -1
var _rng := RandomNumberGenerator.new()
const DEPTH := 0.3

var _shadows: Control
## Блики солнца сквозь рябь: два слоя одной сетки скользят навстречу (дёшево — только
## две выборки из картинки на точку). Ярче всего у поверхности, к 7-му размеру гаснут.
var _caustics: ColorRect
## Событие в океане и насколько оно в силе: цветение зеленит воду, мёртвая зона — гасит.
var event := ""
var event_k := 0.0
## Гигант рядом (0–1): его тень закрывает свет.
var shade := 0.0
var _shade := 0.0
## Новая тень выплыла из-за края — main играет далёкий зов.
signal ghost_appeared(scale: float)

const CAUSTICS := """
shader_type canvas_item;
render_mode blend_add;
uniform sampler2D web : repeat_enable, filter_linear;
uniform vec2 area = vec2(1600.0, 720.0);
uniform vec2 offset = vec2(0.0);
uniform float tile = 420.0;
uniform float t = 0.0;
uniform float strength = 0.15;
uniform vec4 tint : source_color = vec4(0.8, 0.97, 1.0, 1.0);
void fragment() {
	vec2 px = UV * area + offset;
	float a = texture(web, px / tile + vec2(t * 0.011, t * 0.006)).r;
	float b = texture(web, px / (tile * 1.31) + vec2(0.37 - t * 0.008, 0.21 + t * 0.010)).r;
	// Светится только там, где сетки совпали: пятнышки и короткие дуги, а не вся сетка.
	float c = a * b;
	c = c * c * 3.0 + c * 0.6;
	// Сверху (у поверхности) бликов больше.
	c *= mix(1.0, 0.55, UV.y);
	COLOR = vec4(tint.rgb, clamp(c * strength, 0.0, 1.0));
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Тени — на своём слое, целиком окрашенном в тёмно-синий и полупрозрачном: так и
	# части (шипы, челюсти) становятся тенью, а не яркими, как у настоящих.
	_caustics = ColorRect.new()
	_caustics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caustics.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = CAUSTICS
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("web", preload("res://art/caustics.png"))
	_caustics.material = mat
	add_child(_caustics)
	_shadows = Shadows.new()
	_shadows.back = self
	_shadows.modulate = Color(0.05, 0.11, 0.15, 0.8)
	add_child(_shadows)

func _process(delta: float) -> void:
	t += delta
	var water: Array = Content.WATER[clampi(level, 1, Content.WATER.size()) - 1]
	var k := 1.0 - exp(-0.8 * delta)
	_top = _top.lerp(Color(water[0]), k)
	_bottom = _bottom.lerp(Color(water[1]), k)
	_light = lerpf(_light, 1.0, k)
	_shade = lerpf(_shade, shade, 1.0 - exp(-2.0 * delta))
	# События: цветение — вода зеленеет и светлеет, мёртвая зона — тускнеет.
	if event == "bloom":
		_top = _top.lerp(Color("#2e7a5a"), 0.5 * event_k * k * 3.0)
		_bottom = _bottom.lerp(Color("#0c2a1c"), 0.5 * event_k * k * 3.0)
	elif event == "dead":
		_top = _top.lerp(Color("#15202a"), 0.7 * event_k * k * 3.0)
		_bottom = _bottom.lerp(Color("#03060a"), 0.7 * event_k * k * 3.0)
	# Блики на любом размере; тень гиганта и мёртвая зона их гасят.
	var glint := 0.32
	if event == "bloom":
		glint = maxf(glint, 0.2 * event_k)
	if event == "dead":
		glint *= 1.0 - event_k
	glint *= 1.0 - 0.8 * _shade
	_caustics.visible = glint > 0.01
	if _caustics.visible:
		var mat: ShaderMaterial = _caustics.material
		mat.set_shader_parameter("area", size)
		mat.set_shader_parameter("offset", drift * zoom * 0.35)
		mat.set_shader_parameter("t", t)
		mat.set_shader_parameter("strength", glint)
		mat.set_shader_parameter("tint", Color(0.75, 1.0, 0.8) if event == "bloom" else Color(0.8, 0.97, 1.0))
	if level != _ghost_level:
		_ghost_level = level
		_ghosts.clear()
	var pool := _ghost_pool()
	while _ghosts.size() < 2 and not pool.is_empty():
		_ghosts.append(_new_ghost(pool, _ghosts.is_empty()))
	for g in _ghosts:
		g.p += Vector2.from_angle(g.dir) * g.speed * delta
		g.wobble += delta
	queue_redraw()
	_shadows.queue_redraw()

## Только новые гиганты — те, что появятся на следующих размерах; на последнем — Древний.
func _ghost_pool() -> Array:
	var out: Array = []
	for id in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[id]
		if def.behavior != "roamer":
			continue
		var a := int(def.levels[0])
		if a > level and a <= level + 2:
			out.append(id)
	if out.is_empty():
		out = ["drevniy"]
	return out

func _new_ghost(pool: Array, anywhere: bool) -> Dictionary:
	var id: String = pool[_rng.randi() % pool.size()]
	var def: Dictionary = Content.SPECIES[id]
	var parts: Array = []
	for p in def.parts:
		parts.append({"id": p[0], "a": deg_to_rad(p[1]), "d": 1.0, "lvl": p[2]})
	var dir := _rng.randf() * TAU
	# Выплывает из-за края экрана (в пространстве глубины).
	var start := drift * DEPTH + Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5)) * size
	if not anywhere:
		start = drift * DEPTH - Vector2.from_angle(dir) * (size.length() * 0.6)
		ghost_appeared.emit(float(def.get("scale", 3.0)))
	# Плывут заметно: экран пересекают за 10–20 секунд.
	return {"id": id, "p": start, "dir": dir, "speed": _rng.randf_range(70.0, 120.0), "parts": parts,
		"shape": Content.shape_preset(def.get("shape", "round")), "wobble": _rng.randf() * 10.0}

func _ghost_screen(g: Dictionary) -> Vector2:
	return g.p - drift * DEPTH + size / 2.0

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
		var a := (0.035 + 0.025 * sin(t * 0.4 + i * 2.1)) * _light * (1.0 - 0.8 * _shade) * (1.0 - event_k if event == "dead" else 1.0)
		var slant := size.y * 0.35
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - slant, size.y), Vector2(x - slant, size.y)]),
			Color(0.75, 0.95, 1.0, maxf(0.0, a)))


class Shadows:
	extends Control
	var back

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var gone: Array = []
		for g in back._ghosts:
			var at: Vector2 = back._ghost_screen(g)
			var def: Dictionary = Content.SPECIES[g.id]
			# Гигант во столько-то раз больше тебя — и тень такая же, чуть крупнее (ближе к нам).
			var r := maxf(back.player_r * float(def.get("scale", 3.0)) * back.zoom * 1.15, 60.0)
			if not Rect2(Vector2.ZERO, size).grow(r * 3.0 + 120.0).has_point(at):
				gone.append(g)
				continue
			CellArt.creature(self, at, r, g.dir, Color(0.85, 0.9, 0.95), g.parts, g.wobble, {"shape": g.shape, "shadow": false, "simple": true})
		for g in gone:
			back._ghosts.erase(g)
