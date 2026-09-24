## Второй этап — суша. Правила без картинки: где ты, кто вокруг, что можно съесть.
## Как Pond для океана: шаг мира — step(), события — в events.
class_name Land
extends RefCounted

const SPEED := 6.0
const TURN := 6.0
const NPC_COUNT := 7
const BUSHES := 34
const TREES := 140
const FRUITS := 4
const REGROW := 30.0
const EAT_DIST := 1.6

var evo: Evolution
var terrain: Terrain
var rng := RandomNumberGenerator.new()
var events: Array = []
var time := 0.0

## Ты: положение (на земле), куда смотришь (угол вокруг вертикали), скорость.
var pos := Vector3.ZERO
var heading := 0.0
var vel := Vector3.ZERO
var eaten := 0
var _eat_cd := 0.0

## Соседи: {pos, heading, vel, goal, size, color, legs, t}
var npcs: Array = []
## Кусты с плодами: {pos, fruits, regrow}
var bushes: Array = []
## Деревья: {pos, size}
var trees: Array = []

func _init(e: Evolution, seed := 1) -> void:
	evo = e
	rng.seed = seed
	terrain = Terrain.new(seed)
	pos = _land_point(0.0, 25.0)
	for i in TREES:
		var p := _land_point(20.0, Terrain.RADIUS * 0.95)
		if terrain.slope(p.x, p.z) < 0.8:
			trees.append({"pos": p, "size": rng.randf_range(0.8, 1.5)})
	for i in BUSHES:
		bushes.append({"pos": _land_point(8.0, Terrain.RADIUS * 0.85), "fruits": FRUITS, "regrow": 0.0})
	var palette := ["#e07a6a", "#6fc0e0", "#e0b060", "#b08ae0", "#7ad0b0", "#e890b8"]
	for i in NPC_COUNT:
		var p := _land_point(15.0, Terrain.RADIUS * 0.8)
		npcs.append({"pos": p, "heading": rng.randf() * TAU, "vel": Vector3.ZERO, "goal": p, "size": rng.randf_range(0.7, 1.4),
			"color": palette[i % palette.size()], "legs": 2 if i % 3 == 0 else 4, "t": 0.0})

## Случайная точка суши на расстоянии от середины в пределах [inner, outer].
func _land_point(inner: float, outer: float) -> Vector3:
	for attempt in 200:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(inner * inner, outer * outer))
		var x := cos(a) * r
		var z := sin(a) * r
		if not terrain.is_water(x, z) and terrain.height(x, z) > 0.8:
			return Vector3(x, terrain.height(x, z), z)
	return Vector3(0.0, terrain.height(0.0, 0.0), 0.0)

## Шаг. input — куда идти в плоскости земли (x, z), длина 0–1.
func step(dt: float, input: Vector2) -> void:
	events.clear()
	time += dt
	_move_player(dt, input)
	for n in npcs:
		_move_npc(n, dt)
	_eat()
	for b in bushes:
		if b.fruits < FRUITS:
			b.regrow -= dt
			if b.regrow <= 0.0:
				b.fruits += 1
				b.regrow = REGROW

func _move_player(dt: float, input: Vector2) -> void:
	var want := Vector3(input.x, 0.0, input.y).limit_length(1.0) * SPEED
	vel = vel.lerp(want, 1.0 - exp(-8.0 * dt))
	var next := pos + vel * dt
	# В воду не заходим: у берега останавливаемся (глубже по щиколотку — можно).
	if terrain.height(next.x, next.z) < Terrain.WATER - 0.2:
		vel = Vector3.ZERO
		next = pos
	pos = Vector3(next.x, terrain.height(next.x, next.z), next.z)
	if want.length() > 0.3:
		var target := atan2(want.x, want.z)
		heading = lerp_angle(heading, target, 1.0 - exp(-TURN * dt))

func _move_npc(n: Dictionary, dt: float) -> void:
	n.t -= dt
	var here: Vector3 = n.pos
	if n.t <= 0.0 or here.distance_to(n.goal) < 1.5:
		n.t = rng.randf_range(3.0, 8.0)
		n.goal = _land_point(0.0, Terrain.RADIUS * 0.8) if rng.randf() < 0.2 else _near_land(here, 25.0)
	var to: Vector3 = n.goal - here
	to.y = 0.0
	# Тебя сторонятся, если подошёл совсем близко.
	var away := here - pos
	away.y = 0.0
	var dir := to.normalized()
	if away.length() < 4.0:
		dir = (dir + away.normalized() * 1.5).normalized()
	var spd := SPEED * 0.45 / sqrt(n.size)
	n.vel = (n.vel as Vector3).lerp(dir * spd, 1.0 - exp(-4.0 * dt))
	var next: Vector3 = here + n.vel * dt
	if terrain.is_water(next.x, next.z):
		n.goal = _near_land(here, 10.0)
		next = here
	n.pos = Vector3(next.x, terrain.height(next.x, next.z), next.z)
	if (n.vel as Vector3).length() > 0.2:
		n.heading = lerp_angle(n.heading, atan2(n.vel.x, n.vel.z), 1.0 - exp(-4.0 * dt))

func _near_land(at: Vector3, r: float) -> Vector3:
	for attempt in 20:
		var p := at + Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
		if not terrain.is_water(p.x, p.z):
			return Vector3(p.x, terrain.height(p.x, p.z), p.z)
	return at

## Плоды: подошёл к кусту — съел один.
func _eat() -> void:
	_eat_cd -= 1.0 / 30.0
	if _eat_cd > 0.0:
		return
	for b in bushes:
		if b.fruits > 0 and (b.pos as Vector3).distance_to(pos) < EAT_DIST + 0.6:
			b.fruits -= 1
			if b.regrow <= 0.0:
				b.regrow = REGROW
			eaten += 1
			_eat_cd = 0.45
			events.append({"t": "eat", "pos": b.pos})
			return
