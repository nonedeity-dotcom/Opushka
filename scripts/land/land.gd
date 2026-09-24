## Второй этап — суша. Правила без картинки: где ты, кто вокруг, что можно съесть и
## разбить. Как Pond для океана: шаг мира — step(), события — в events.
##
## Кто живёт на острове:
## - бродяги — мирные, ходят где хотят, ранишь — убегают;
## - стаи у гнёзд — держатся у своего гнезда и защищают его: подошёл близко, стащил яйцо
##   или ранил одного — нападают все;
## - отшельники — одиночки, крупные и сильные: подошёл — бросаются, пока не выдохнутся.
## Кости (вместо камней первого этапа) — разбиваешь укусами, из них ДНК.
class_name Land
extends RefCounted

const SPEED := 6.0
const TURN := 6.0
const WANDERERS := 5
const NESTS := 5
const HERMITS := 4
const BONES := 18
const BUSHES := 34
const TREES := 140
const FRUITS := 4
const REGROW := 30.0
const EAT_DIST := 1.6
const EGGS := 3
## Укус: перезарядка и насколько далеко перед собой достаёшь.
const BITE_CD := 0.5
const REACH := 1.9
## Стая: как далеко от гнезда ходят и с какого расстояния его стерегут.
const NEST_ROAM := 12.0
const NEST_GUARD := 7.0
const NEST_LEASH := 26.0
## Отшельник: с какого расстояния бросается и сколько гонится.
const HERMIT_SIGHT := 11.0
const HERMIT_CHASE := 6.0

var evo: Evolution
var terrain: Terrain
var rng := RandomNumberGenerator.new()
var events: Array = []
var time := 0.0

## Ты: положение (на земле), куда смотришь, скорость, здоровье, ДНК суши.
var pos := Vector3.ZERO
var heading := 0.0
var vel := Vector3.ZERO
var hp := 30.0
var max_hp := 30.0
var bite := 6.0
var bite_cd := 0.0
var dna := 0.0
var eaten := 0
var deaths := 0
var home := Vector3.ZERO
var _eat_cd := 0.0
var _uid := 0

## Существа: {uid, kind: wander/pack/hermit, pos, heading, vel, goal, size, color, legs,
## t, hp, max_hp, bite, bite_cd, speed, nest (номер гнезда или -1), angry, stamina, rest,
## hit (вспышка 0–1), alive}
var mobs: Array = []
## Гнёзда: {pos, eggs, color, legs, respawn}
var nests: Array = []
## Кости: {uid, pos, size, hp, max_hp, big, hit, alive, respawn, yaw}
var bones: Array = []
## Кусты с плодами: {pos, fruits, regrow}
var bushes: Array = []
## Деревья: {pos, size}
var trees: Array = []

func _init(e: Evolution, seed := 1) -> void:
	evo = e
	rng.seed = seed
	terrain = Terrain.new(seed)
	pos = _land_point(0.0, 25.0)
	home = pos
	for i in TREES:
		var p := _land_point(20.0, Terrain.RADIUS * 0.95)
		if terrain.slope(p.x, p.z) < 0.8:
			trees.append({"pos": p, "size": rng.randf_range(0.8, 1.5)})
	for i in BUSHES:
		bushes.append({"pos": _land_point(8.0, Terrain.RADIUS * 0.85), "fruits": FRUITS, "regrow": 0.0})
	var palette := ["#e07a6a", "#6fc0e0", "#e0b060", "#b08ae0", "#7ad0b0", "#e890b8", "#c8a070"]
	for i in WANDERERS:
		_add_mob("wander", _land_point(15.0, Terrain.RADIUS * 0.8), rng.randf_range(0.7, 1.2), palette[i % palette.size()], 2 if i % 3 == 0 else 4)
	for i in NESTS:
		var at := _land_point(35.0, Terrain.RADIUS * 0.8)
		var nest := {"pos": at, "eggs": EGGS, "color": palette[(i + 2) % palette.size()], "legs": 4 if i % 2 == 0 else 2, "respawn": 60.0}
		nests.append(nest)
		for k in rng.randi_range(3, 4):
			_add_mob("pack", _near_land(at, 6.0), rng.randf_range(0.8, 1.0), nest.color, nest.legs, nests.size() - 1)
	for i in HERMITS:
		_add_mob("hermit", _land_point(45.0, Terrain.RADIUS * 0.85), rng.randf_range(1.8, 2.3), ["#5a4a6a", "#6a3a3a", "#3a4a5a", "#4a5a3a"][i % 4], 4)
	for i in BONES:
		_add_bone(i < 3)

func _add_mob(kind: String, at: Vector3, size: float, color: String, legs: int, nest := -1) -> Dictionary:
	_uid += 1
	var hp_ := 14.0 * size * size * (1.6 if kind == "hermit" else 1.0)
	var m := {"uid": _uid, "kind": kind, "pos": at, "heading": rng.randf() * TAU, "vel": Vector3.ZERO, "goal": at, "size": size,
		"color": color, "legs": legs, "t": 0.0, "hp": hp_, "max_hp": hp_, "bite": {"wander": 2.5, "pack": 2.5, "hermit": 5.6}[kind] * size,
		"bite_cd": 0.0, "speed": SPEED * (0.5 if kind == "wander" else (0.75 if kind == "pack" else 0.8)) / sqrt(size), "nest": nest,
		"angry": 0.0, "stamina": 1.0, "rest": 0.0, "hit": 0.0, "alive": true}
	mobs.append(m)
	return m

func _add_bone(big: bool) -> void:
	# Большие скелеты — у берега, маленькие кучки — где угодно.
	var at := _land_point(Terrain.RADIUS * 0.6, Terrain.RADIUS * 0.85) if big else _land_point(10.0, Terrain.RADIUS * 0.85)
	var size := rng.randf_range(2.2, 2.8) if big else rng.randf_range(0.8, 1.3)
	var hp_ := 40.0 * size if big else 14.0 * size
	_uid += 1
	bones.append({"uid": _uid, "pos": at, "size": size, "hp": hp_, "max_hp": hp_, "big": big, "hit": 0.0, "alive": true, "respawn": 0.0,
		"yaw": rng.randf() * TAU})

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

## Шаг. input — куда идти в плоскости земли (x, z), длина 0–1; do_bite — нажат «Укус».
func step(dt: float, input: Vector2, do_bite := false) -> void:
	events.clear()
	time += dt
	bite_cd -= dt
	_move_player(dt, input)
	if do_bite:
		_player_bite()
	for m in mobs:
		if m.alive:
			_think(m, dt)
	_eat(dt)
	_nests(dt)
	for b in bushes:
		if b.fruits < FRUITS:
			b.regrow -= dt
			if b.regrow <= 0.0:
				b.fruits += 1
				b.regrow = REGROW
	for b in bones:
		b.hit = maxf(0.0, b.hit - dt * 3.0)
		if not b.alive:
			b.respawn -= dt
			if b.respawn <= 0.0:
				var fresh: bool = b.big
				bones.erase(b)
				_add_bone(fresh)
				break
	_deaths()
	# Лечишься понемногу, если давно не били.
	hp = minf(max_hp, hp + dt * 0.8)

func _move_player(dt: float, input: Vector2) -> void:
	var want := Vector3(input.x, 0.0, input.y).limit_length(1.0) * SPEED
	vel = vel.lerp(want, 1.0 - exp(-8.0 * dt))
	var next := pos + vel * dt
	# В воду не заходим: у берега останавливаемся (по щиколотку — можно).
	if terrain.height(next.x, next.z) < Terrain.WATER - 0.2:
		vel = Vector3.ZERO
		next = pos
	next = _push_out(next, 0.8)
	pos = Vector3(next.x, terrain.height(next.x, next.z), next.z)
	if want.length() > 0.3:
		heading = lerp_angle(heading, atan2(want.x, want.z), 1.0 - exp(-TURN * dt))

## Сквозь кости не пройти — их обходят.
func _push_out(p: Vector3, r: float) -> Vector3:
	for b in bones:
		if not b.alive:
			continue
		var d := Vector2(p.x - b.pos.x, p.z - b.pos.z)
		var need: float = r + float(b.size) * 0.9
		if d.length() < need and d.length() > 0.01:
			var out := d.normalized() * need
			p = Vector3(b.pos.x + out.x, p.y, b.pos.z + out.y)
	return p

func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))

## Укус: ближайший перед тобой — существо или кость.
func _player_bite() -> void:
	if bite_cd > 0.0:
		return
	bite_cd = BITE_CD
	events.append({"t": "bite", "pos": pos})
	var fwd := forward()
	var best = null
	var best_d := INF
	for m in mobs:
		if not m.alive:
			continue
		var d: float = (m.pos as Vector3).distance_to(pos) - float(m.size) * 0.6
		if d < REACH and _in_front(m.pos, fwd) and d < best_d:
			best_d = d
			best = m
	for b in bones:
		if not b.alive:
			continue
		var d: float = (b.pos as Vector3).distance_to(pos) - float(b.size) * 0.9
		if d < REACH and _in_front(b.pos, fwd) and d < best_d:
			best_d = d
			best = b
	if best == null:
		return
	if best.has("kind"):
		_hurt_mob(best, bite)
	else:
		best.hp -= bite
		best.hit = 1.0
		events.append({"t": "bone_hit", "pos": best.pos})
		if best.hp <= 0.0:
			best.alive = false
			best.respawn = 90.0
			var gain: float = 12.0 if best.big else 4.0
			dna += gain
			events.append({"t": "bone_break", "pos": best.pos, "dna": gain, "big": best.big})

func _in_front(p: Vector3, fwd: Vector3) -> bool:
	var to := p - pos
	to.y = 0.0
	return to.length() < 0.5 or fwd.dot(to.normalized()) > 0.35

func _hurt_mob(m: Dictionary, dmg: float) -> void:
	m.hp -= dmg
	m.hit = 1.0
	events.append({"t": "hit", "pos": m.pos, "uid": m.uid})
	match m.kind:
		"pack":
			# Ранил одного — вся стая в ярости.
			_anger_pack(m.nest)
		"hermit":
			m.angry = 8.0
		_:
			m.angry = -4.0  # бродяга — удирает

func _anger_pack(nest: int) -> void:
	var fresh := false
	for o in mobs:
		if o.alive and o.kind == "pack" and o.nest == nest:
			if o.angry <= 0.0:
				fresh = true
			o.angry = 8.0
	if fresh:
		events.append({"t": "alarm", "pos": nests[nest].pos})

func _think(m: Dictionary, dt: float) -> void:
	m.t -= dt
	m.bite_cd -= dt
	m.hit = maxf(0.0, m.hit - dt * 3.0)
	var here: Vector3 = m.pos
	var to_me := pos - here
	to_me.y = 0.0
	var dist := to_me.length()
	var dir := Vector3.ZERO
	var spd: float = m.speed
	match m.kind:
		"pack":
			var nest: Dictionary = nests[m.nest]
			var from_nest: float = (pos - (nest.pos as Vector3)).length()
			if from_nest < NEST_GUARD:
				_anger_pack(m.nest)
			if m.angry > 0.0 and from_nest < NEST_LEASH:
				m.angry -= dt
				# Злая стая чуть медленнее тебя: стащил яйцо — беги, успеешь.
				dir = to_me.normalized()
				spd *= 1.15
			else:
				m.angry = minf(m.angry, 0.0)
				if m.t <= 0.0 or here.distance_to(m.goal) < 1.2:
					m.t = rng.randf_range(2.0, 6.0)
					m.goal = _near_land(nest.pos, NEST_ROAM)
				dir = _toward(here, m.goal)
		"hermit":
			m.rest -= dt
			if m.rest <= 0.0 and (dist < HERMIT_SIGHT or m.angry > 0.0):
				m.angry = maxf(m.angry - dt, 0.0)
				m.stamina -= dt / HERMIT_CHASE
				# Злая стая чуть медленнее тебя: стащил яйцо — беги, успеешь.
				dir = to_me.normalized()
				spd *= 1.155
				if m.stamina <= 0.0:
					# Выдохся — отстаёт и отдыхает.
					m.rest = 4.0
					m.stamina = 1.0
					m.angry = 0.0
			else:
				m.stamina = minf(1.0, m.stamina + dt / 5.0)
				if m.t <= 0.0 or here.distance_to(m.goal) < 1.5:
					m.t = rng.randf_range(4.0, 9.0)
					m.goal = _near_land(here, 30.0)
				dir = _toward(here, m.goal) * 0.6
		_:
			if m.angry < 0.0:
				m.angry += dt
				dir = -to_me.normalized()
				spd *= 1.5
			else:
				if m.t <= 0.0 or here.distance_to(m.goal) < 1.5:
					m.t = rng.randf_range(3.0, 8.0)
					m.goal = _land_point(0.0, Terrain.RADIUS * 0.8) if rng.randf() < 0.2 else _near_land(here, 25.0)
				dir = _toward(here, m.goal)
				if dist < 4.0:
					dir = (dir - to_me.normalized() * 1.5).normalized()
	m.vel = (m.vel as Vector3).lerp(dir * spd, 1.0 - exp(-4.0 * dt))
	var next: Vector3 = here + m.vel * dt
	if terrain.is_water(next.x, next.z):
		m.goal = _near_land(here, 10.0)
		next = here
	next = _push_out(next, float(m.size) * 0.6)
	# Не налезают на тебя.
	var gap := Vector2(next.x - pos.x, next.z - pos.z)
	var need: float = float(m.size) * 0.7 + 0.7
	if gap.length() < need and gap.length() > 0.01:
		var out := gap.normalized() * need
		next = Vector3(pos.x + out.x, next.y, pos.z + out.y)
	m.pos = Vector3(next.x, terrain.height(next.x, next.z), next.z)
	if (m.vel as Vector3).length() > 0.2:
		m.heading = lerp_angle(m.heading, atan2(m.vel.x, m.vel.z), 1.0 - exp(-5.0 * dt))
	# Кусает, если злой и достаёт.
	var attacking: bool = (m.kind == "pack" and m.angry > 0.0) or (m.kind == "hermit" and dir.dot(to_me.normalized()) > 0.9 and dist < HERMIT_SIGHT)
	if attacking and dist < float(m.size) * 0.7 + REACH and m.bite_cd <= 0.0:
		m.bite_cd = 1.3 if m.kind == "pack" else 1.1
		hp -= float(m.bite)
		events.append({"t": "hurt", "pos": pos, "dmg": m.bite, "kind": m.kind, "uid": m.uid})

func _toward(from: Vector3, to: Vector3) -> Vector3:
	var d := to - from
	d.y = 0.0
	return d.normalized() if d.length() > 0.5 else Vector3.ZERO

func _near_land(at: Vector3, r: float) -> Vector3:
	for attempt in 20:
		var p := at + Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
		if not terrain.is_water(p.x, p.z):
			return Vector3(p.x, terrain.height(p.x, p.z), p.z)
	return at

## Плоды и яйца: подошёл — съел. Яйцо — из гнезда, и стая этого не простит.
func _eat(dt: float) -> void:
	_eat_cd -= dt
	if _eat_cd > 0.0:
		return
	for b in bushes:
		if b.fruits > 0 and (b.pos as Vector3).distance_to(pos) < EAT_DIST + 0.6:
			b.fruits -= 1
			if b.regrow <= 0.0:
				b.regrow = REGROW
			eaten += 1
			dna += 1.0
			_eat_cd = 0.45
			events.append({"t": "eat", "pos": b.pos, "dna": 1.0})
			return
	for i in nests.size():
		var n: Dictionary = nests[i]
		if n.eggs > 0 and (n.pos as Vector3).distance_to(pos) < 1.6:
			n.eggs -= 1
			dna += 5.0
			_eat_cd = 0.8
			events.append({"t": "egg", "pos": n.pos, "dna": 5.0})
			_anger_pack(i)
			return

## Гнёзда: яйца со временем появляются снова, стая пополняется.
func _nests(dt: float) -> void:
	for i in nests.size():
		var n: Dictionary = nests[i]
		n.respawn -= dt
		if n.respawn > 0.0:
			continue
		n.respawn = 60.0
		if n.eggs < EGGS:
			n.eggs += 1
		var alive := mobs.filter(func(m): return m.alive and m.kind == "pack" and m.nest == i).size()
		if alive < 3:
			_add_mob("pack", _near_land(n.pos, 4.0), rng.randf_range(0.8, 1.0), n.color, n.legs, i)

func _deaths() -> void:
	for m in mobs:
		if m.alive and m.hp <= 0.0:
			m.alive = false
			var gain: float = {"wander": 3.0, "pack": 4.0, "hermit": 25.0}[m.kind]
			dna += gain
			events.append({"t": "kill", "pos": m.pos, "uid": m.uid, "kind": m.kind, "dna": gain})
	var dead := mobs.filter(func(m): return not m.alive)
	for m in dead:
		mobs.erase(m)
		# Бродяги и отшельники со временем приходят новые — где-нибудь подальше.
		if m.kind == "wander":
			_add_mob("wander", _land_point(40.0, Terrain.RADIUS * 0.8), rng.randf_range(0.7, 1.2), m.color, m.legs)
		elif m.kind == "hermit":
			_add_mob("hermit", _land_point(60.0, Terrain.RADIUS * 0.85), rng.randf_range(1.8, 2.3), m.color, 4)
	if hp <= 0.0:
		# Тебя одолели: снова у начала, целый; ДНК суши немного теряется.
		deaths += 1
		var lost := floorf(dna * 0.2)
		dna -= lost
		events.append({"t": "death", "pos": pos, "lost": lost})
		pos = home
		vel = Vector3.ZERO
		hp = max_hp
		for m in mobs:
			m.angry = 0.0
