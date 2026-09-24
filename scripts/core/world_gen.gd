## Карта «Опушки»: земля и то, что на ней выросло.
##
## Карта не хранится — она выращивается заново из одного числа, зерна. В сохранение идут
## только перемены: что срублено, что построено. Сохранение остаётся маленьким, сколько бы
## месяцев ни играть, а мир у каждого свой.
class_name WorldGen
extends RefCounted

const SIZE := 64

enum Ground { GRASS, FOREST, SHORE, WATER }

static var _cache := {}

## Сделанная карта: ground — PackedByteArray (Ground), nature — Array строк ("" — пусто).
static func make(seed: int) -> Dictionary:
	if _cache.has(seed):
		return _cache[seed]
	var rnd := Rng.new(seed)
	var density := SmoothNoise.new(rnd, SIZE, 8)
	var wet := SmoothNoise.new(rnd, SIZE, 11)
	var start := Vector2i(SIZE / 2, SIZE / 2)

	# Пруд: не на поляне, но недалеко — чтобы его нашли в первый же день.
	var angle := rnd.next() * TAU
	var pond := Vector2(start) + Vector2(cos(angle), sin(angle)) * 11.0
	pond = pond.round()

	var ground := PackedByteArray()
	ground.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var d := Vector2(x, y).distance_to(Vector2(start))
			var to_pond := Vector2(x, y).distance_to(pond) + (wet.at(x, y) - 0.5) * 3.0
			var lake := wet.at(x, y) > 0.8 and d > 9.0
			if _edge(x, y):
				ground[i] = Ground.FOREST
			elif to_pond < 3.2 or lake:
				ground[i] = Ground.WATER
			elif d < 7.0:
				ground[i] = Ground.GRASS
			else:
				ground[i] = Ground.FOREST if density.at(x, y) > 0.5 else Ground.GRASS
	# Берег — сухая земля у самой воды: по ней ходят.
	var shore := PackedInt32Array()
	for y in SIZE:
		for x in SIZE:
			if ground[y * SIZE + x] == Ground.WATER:
				continue
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + dir
				if _inside(n) and ground[n.y * SIZE + n.x] == Ground.WATER:
					shore.append(y * SIZE + x)
					break
	for i in shore:
		ground[i] = Ground.SHORE

	var nature: Array[String] = []
	nature.resize(SIZE * SIZE)
	nature.fill("")
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			if ground[i] == Ground.WATER:
				continue
			# Край карты — сплошной лес: за него не выйти, и мир не кончается обрывом.
			if _edge(x, y):
				nature[i] = "tree"
				continue
			var d := Vector2(x, y).distance_to(Vector2(start))
			if d < 2.0:
				continue
			var r := rnd.next()
			var dense := 0.0 if d < 5.0 else density.at(x, y)
			var tree := 0.25 + dense * 0.45 if ground[i] == Ground.FOREST else dense * 0.18
			if r < tree:
				nature[i] = "tree"
			elif r < tree + 0.035:
				nature[i] = "bush"
			elif r < tree + 0.05 and d > 6.0:
				nature[i] = "rock"
			elif r < tree + 0.075:
				nature[i] = "pebble"
			elif r < tree + 0.12:
				nature[i] = "branch"

	# Дикая морковь и подсолнухи — на свободной траве, по своему «случайному» числу клетки, а не
	# из общего генератора: так прежние деревья и кусты остались на своих местах.
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			if nature[i] != "" or ground[i] != Ground.GRASS or x < 3 or y < 3 or x >= SIZE - 3 or y >= SIZE - 3:
				continue
			if Vector2(x, y).distance_to(Vector2(start)) < 4.0:
				continue
			var h := variant(seed ^ 0x5EED, x, y)
			if h < 4:
				nature[i] = "wildcarrot"
			elif h < 7:
				nature[i] = "sunflower"

	# Поляна обещает начало: рядом всегда ветки, камешки и кусты — топор делается сразу.
	var near := [[2, -1, "branch"], [-2, 1, "branch"], [1, 3, "branch"], [-3, -2, "branch"],
		[3, 2, "pebble"], [-1, -3, "pebble"], [-3, 3, "pebble"], [4, -3, "bush"], [-4, 0, "bush"],
		[5, 2, "wildcarrot"], [-2, 5, "wildcarrot"], [-5, -3, "sunflower"]]
	for n in near:
		var i: int = (start.y + n[1]) * SIZE + start.x + n[0]
		nature[i] = n[2]
		if ground[i] == Ground.WATER or ground[i] == Ground.SHORE:
			ground[i] = Ground.GRASS
	for dir in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = start + dir
		var i := c.y * SIZE + c.x
		nature[i] = ""
		if ground[i] == Ground.WATER or ground[i] == Ground.SHORE:
			ground[i] = Ground.GRASS

	var world := {"seed": seed, "size": SIZE, "ground": ground, "nature": nature, "start": start}
	_cache[seed] = world
	return world

static func _edge(x: int, y: int) -> bool:
	return x < 2 or y < 2 or x >= SIZE - 2 or y >= SIZE - 2

static func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE

## Постоянное «случайное» число клетки, 0–255: вид дерева, пучки травы, цветы. Одно и то
## же для клетки всегда, иначе лес переодевался бы на каждом кадре.
static func variant(seed: int, x: int, y: int) -> int:
	var h := (seed ^ ((x + 1) * 374761393) ^ ((y + 1) * 668265263)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return (h ^ (h >> 16)) & 255


## Свой генератор, а не RandomNumberGenerator: карта обязана быть одной и той же при одном
## зерне на любом телефоне и в любой версии движка.
class Rng:
	var s: int

	func _init(seed: int) -> void:
		s = seed & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		s &= 0xFFFFFFFF
		return float(s) / 4294967296.0


## Плавный шум: редкая сетка случайных чисел, между узлами — сглаженная середина. Даёт
## густые и редкие участки леса вместо ровной ряби.
class SmoothNoise:
	var grid := PackedFloat32Array()
	var n: int
	var step: float

	func _init(rnd: Rng, size: int, step_: int) -> void:
		step = step_
		n = ceili(float(size) / step_) + 2
		grid.resize(n * n)
		for i in n * n:
			grid[i] = rnd.next()

	func at(x: int, y: int) -> float:
		var gx := x / step
		var gy := y / step
		var i := floori(gx)
		var j := floori(gy)
		var tx := smoothstep(0.0, 1.0, gx - i)
		var ty := smoothstep(0.0, 1.0, gy - j)
		var top := lerpf(grid[j * n + i], grid[j * n + i + 1], tx)
		var bottom := lerpf(grid[(j + 1) * n + i], grid[(j + 1) * n + i + 1], tx)
		return lerpf(top, bottom, ty)
