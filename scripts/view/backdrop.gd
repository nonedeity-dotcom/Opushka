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
## Тени в глубине: те, кто встретится на следующих размерах. Крупнее и медленнее мира
## впереди (дальше — значит, при движении сдвигаются меньше) — сразу видно, что это фон.
var level := 1
var zoom := 1.0
var _ghosts: Array = []  # [{id, p, dir, speed, parts, shape}]
var _ghost_level := -1
var _rng := RandomNumberGenerator.new()
const DEPTH := 0.3

var _shadows: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Тени — на своём слое, целиком окрашенном в тёмно-синий и полупрозрачном: так и
	# части (шипы, челюсти) становятся тенью, а не яркими, как у настоящих.
	_shadows = Shadows.new()
	_shadows.back = self
	_shadows.modulate = Color(0.05, 0.11, 0.15, 0.8)
	add_child(_shadows)

func _process(delta: float) -> void:
	t += delta
	var def: Dictionary = Content.BIOMES.get(biome, Content.BIOMES.shallows)
	var k := 1.0 - exp(-1.5 * delta)
	_top = _top.lerp(Color(def.top), k)
	_bottom = _bottom.lerp(Color(def.bottom), k)
	_light = lerpf(_light, 0.35 if biome == "deep" else 1.0, k)
	if level != _ghost_level:
		_ghost_level = level
		_ghosts.clear()
	var pool := _ghost_pool()
	while _ghosts.size() < 3 and not pool.is_empty():
		_ghosts.append(_new_ghost(pool, _ghosts.is_empty()))
	for g in _ghosts:
		g.p += Vector2.from_angle(g.dir) * g.speed * delta
		g.wobble += delta
	queue_redraw()
	_shadows.queue_redraw()

## Виды, которые появятся на следующих одном-двух размерах; на последнем — самые большие.
func _ghost_pool() -> Array:
	var out: Array = []
	for id in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[id]
		if float(def.get("weight", 0.0)) <= 0.0 and not def.has("scale"):
			continue
		var a := int(def.levels[0])
		if a > level and a <= level + 2:
			out.append(id)
	if out.is_empty():
		out = ["leviafan", "velikan", "kit"]
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
	return {"id": id, "p": start, "dir": dir, "speed": _rng.randf_range(10.0, 22.0), "parts": parts,
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
		var a := (0.035 + 0.025 * sin(t * 0.4 + i * 2.1)) * _light
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
			var base: float = 16.0 * float(def.scale) if def.has("scale") else float(def.radius)
			var r := maxf(base * back.zoom * 1.7, 46.0)
			if not Rect2(Vector2.ZERO, size).grow(r * 3.0 + 120.0).has_point(at):
				gone.append(g)
				continue
			CellArt.creature(self, at, r, g.dir, Color(0.85, 0.9, 0.95), g.parts, g.wobble, {"shape": g.shape, "shadow": false, "simple": true})
		for g in gone:
			back._ghosts.erase(g)
