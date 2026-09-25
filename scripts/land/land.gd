## Второй этап — суша. Правила без картинки: где ты, кто вокруг, что можно съесть и
## разбить. Как Pond для океана: шаг мира — step(), события — в events.
##
## Кто живёт на острове:
## - бродяги — травоядные: ходят от куста к кусту и едят плоды, ночью спят, от тебя и от
##   хищников убегают;
## - хищники — охотятся на бродяг (остаётся туша — её можно доесть), ночью бросаются и
##   на тебя;
## - стаи у гнёзд — держатся у своего гнезда и защищают его: подошёл близко, стащил яйцо
##   или ранил одного — нападают все. У стаи есть вожак: убил его — стая разбегается;
## - отшельники — одиночки, крупные и сильные: подошёл — бросаются, пока не выдохнутся;
## - гиганты — огромные и очень сильные, каждый стережёт свои места. Побеждённый гигант
##   не возвращается и оставляет находку.
## Кости (вместо камней первого этапа) — разбиваешь укусами, из них ДНК. Окаменелости —
## тоже разбиваешь, в них находки: новые части тела.
##
## День сменяется ночью: ночью бродяги спят, хищники и отшельники видят дальше.
## У тебя своё гнездо: там лечишься, туда возвращаешься, если одолели, и только там
## можно поменять тело. В гнездо никто не заходит.
## Существо не растёт, а крепнет: чем больше ДНК добыто на суше, тем выше сила (больше
## здоровья, сильнее укус).
##
## Что умеет твоё тело, решают части суши (LandParts): скорость, укус, броня, зрение…
## ДНК — общая с океаном: всё добытое здесь идёт в рост вида.
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
const HUNTERS := 4
const HUNTER_SIGHT := 14.0
const GIANTS := 3
## Гигант: с какого расстояния бросается и как далеко от своих мест уходит.
const GIANT_SIGHT := 12.0
const GIANT_HOME := 22.0
const RELICS := 16
## Своё гнездо: в этом круге никто не тронет, раны заживают быстро.
const NEST_R := 5.0
const NEST_HEAL := 4.0
## Сутки — пять минут: день, закат, ночь, рассвет.
const DAY_LEN := 300.0

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
## Своё гнездо (home — то же место): есть ли, и сколько секунд после смены суток.
var has_nest := false
## Время суток: 0…1 (0 — утро, 0,65–0,9 — ночь).
var day := 0.1
var _night := false
## Что сделано на острове навсегда: номера разбитых окаменелостей и побеждённых гигантов.
var relics_taken: Array = []
var giants_beaten: Array = []
## Какая сила была — чтобы заметить, что стала больше.
var _level := 1
## Скорость от силы.
var _spd_k := 1.0
## Что даёт тело (LandParts.stats).
var st := {}
## Сцена выхода из воды: тобой управляет она, соседи тебя не замечают.
var scripted := false
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
## Окаменелости: {i, pos, size, hp, max_hp, hit, alive}
var relics: Array = []
## Туши (остались после охоты): {uid, pos, meat, t}
var carcasses: Array = []
## Деревья: {pos, size}
var trees: Array = []

func _init(e: Evolution, seed := 1) -> void:
	evo = e
	_level = evo.land_level()
	apply_body()
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
		var nest := {"pos": at, "eggs": EGGS, "color": palette[(i + 2) % palette.size()], "legs": 4 if i % 2 == 0 else 2, "respawn": 60.0,
			"panic": 0.0, "leader_t": 0.0}
		nests.append(nest)
		_add_leader(nests.size() - 1)
		for k in rng.randi_range(3, 4):
			_add_mob("pack", _near_land(at, 6.0), rng.randf_range(0.8, 1.0), nest.color, nest.legs, nests.size() - 1)
	for i in HERMITS:
		_add_mob("hermit", _land_point(45.0, Terrain.RADIUS * 0.85), rng.randf_range(1.8, 2.3), ["#5a4a6a", "#6a3a3a", "#3a4a5a", "#4a5a3a"][i % 4], 4)
	for i in HUNTERS:
		_add_mob("hunter", _land_point(30.0, Terrain.RADIUS * 0.85), rng.randf_range(1.1, 1.35), ["#c8683e", "#a8323a", "#8a5a3a", "#b04a2a"][i % 4], 4)
	for i in BONES:
		_add_bone(i < 3)
	# Окаменелости и гиганты — от своего зерна: одни и те же места на этом острове, как бы
	# ни менялось остальное.
	_restore(evo.land_save)
	var fixed := RandomNumberGenerator.new()
	fixed.seed = seed * 31 + 7
	var keep := rng
	rng = fixed
	for i in RELICS:
		var at := _land_point(20.0, Terrain.RADIUS * 0.9)
		if not relics_taken.has(i):
			relics.append({"i": i, "pos": at, "size": 1.0, "hp": 30.0, "max_hp": 30.0, "hit": 0.0, "alive": true})
	for i in GIANTS:
		var at := _land_point(Terrain.RADIUS * 0.45, Terrain.RADIUS * 0.8)
		var sz := fixed.randf_range(3.1, 3.5)
		if not giants_beaten.has(i):
			var g := _add_mob("giant", at, sz, ["#6a5a7a", "#7a5a3a", "#4a6a6a"][i], 4)
			g.home = at
			g.gi = i
	rng = keep
	if not has_nest:
		home = pos

## Прочитать остров, каким его оставили (evo.land_save): где ты, гнездо, время суток, что
## уже найдено.
func _restore(sv: Dictionary) -> void:
	if sv.is_empty():
		return
	relics_taken = (sv.get("relics", []) as Array).duplicate()
	giants_beaten = (sv.get("giants", []) as Array).duplicate()
	day = float(sv.get("day", day))
	var n: Array = sv.get("nest", [])
	if n.size() == 2 and not terrain.is_water(float(n[0]), float(n[1])):
		set_nest(Vector3(float(n[0]), 0.0, float(n[1])))
	var p: Array = sv.get("pos", [])
	if p.size() == 2 and not terrain.is_water(float(p[0]), float(p[1])):
		pos = Vector3(float(p[0]), terrain.height(float(p[0]), float(p[1])), float(p[1]))
	elif has_nest:
		pos = home
	hp = max_hp * clampf(float(sv.get("hp", 1.0)), 0.2, 1.0)
	_night = is_night()

## Остров сейчас — для сохранения.
func snapshot() -> Dictionary:
	return {"pos": [pos.x, pos.z], "hp": hp / maxf(max_hp, 1.0), "day": day,
		"nest": [home.x, home.z] if has_nest else [], "relics": relics_taken.duplicate(), "giants": giants_beaten.duplicate()}

## Сохранённый остров с проверкой: непонятное выбрасывается.
static func fix_save(v: Variant) -> Dictionary:
	if not v is Dictionary or (v as Dictionary).is_empty():
		return {}
	var out := {}
	var num := func(x) -> bool: return x is float or x is int
	for k in ["pos", "nest"]:
		var a = v.get(k)
		if a is Array and a.size() == 2 and a.all(num):
			out[k] = [float(a[0]), float(a[1])]
	for k in ["hp", "day"]:
		if num.call(v.get(k)):
			out[k] = clampf(float(v[k]), 0.0, 1.0)
	for k in ["relics", "giants"]:
		var a = v.get(k)
		if not a is Array:
			continue
		var list: Array = []
		for x in a:
			if num.call(x) and not list.has(int(x)):
				list.append(int(x))
		out[k] = list
	return out

## Своё гнездо — здесь.
func set_nest(at: Vector3) -> void:
	has_nest = true
	home = Vector3(at.x, terrain.height(at.x, at.z), at.z)

## Ты у своего гнезда (можно поменять тело)?
func at_nest() -> bool:
	return has_nest and Vector2(pos.x - home.x, pos.z - home.z).length() < NEST_R + 1.5

## В своём гнезде никто не тронет.
func safe() -> bool:
	return has_nest and Vector2(pos.x - home.x, pos.z - home.z).length() < NEST_R

## Сколько света: 1 — день, 0 — ночь (между — закат и рассвет).
static func daylight(d: float) -> float:
	d = fposmod(d, 1.0)
	if d < 0.55:
		return 1.0
	if d < 0.65:
		return 1.0 - (d - 0.55) / 0.1
	if d < 0.9:
		return 0.0
	return (d - 0.9) / 0.1

func is_night() -> bool:
	return daylight(day) < 0.4

## Перечитать тело (после редактора): скорость, укус, здоровье…
func apply_body() -> void:
	var body: Dictionary = evo.land_body if evo.land_can_walk() else LandParts.from_sea(evo.body).body
	var shape: Dictionary = evo.land_shape if not evo.land_shape.is_empty() else LandParts.shape_from_sea(evo.shape)
	st = LandParts.stats(body, shape)
	var pw := LandParts.power(evo.land_level())
	var frac := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = float(st.hp) * float(pw.hp)
	hp = max_hp * frac
	bite = float(st.bite) * float(pw.bite)
	_spd_k = pw.speed

## ДНК с суши: в общий счёт вида.
## Заодно копится сила: набралось на следующую — сильнее и целый.
func _gain(x: float) -> void:
	dna += x
	evo.add_dna(x)
	evo.land_xp += x
	var l := evo.land_level()
	if l > _level:
		_level = l
		apply_body()
		hp = max_hp
		events.append({"t": "level", "level": l, "pos": pos})

func _add_mob(kind: String, at: Vector3, size: float, color: String, legs: int, nest := -1) -> Dictionary:
	_uid += 1
	var hp_: float = 14.0 * size * size * {"hermit": 1.6, "hunter": 1.2, "giant": 2.0}.get(kind, 1.0)
	var spd: float = {"wander": 0.5, "pack": 0.75, "hermit": 0.8, "hunter": 0.9, "giant": 0.75}[kind]
	var m := {"uid": _uid, "kind": kind, "pos": at, "heading": rng.randf() * TAU, "vel": Vector3.ZERO, "goal": at, "size": size,
		"color": color, "legs": legs, "t": 0.0, "hp": hp_, "max_hp": hp_,
		"bite": {"wander": 2.5, "pack": 2.5, "hermit": 5.6, "hunter": 3.6, "giant": 4.2}[kind] * size,
		"bite_cd": 0.0, "speed": SPEED * spd / sqrt(size), "nest": nest,
		"angry": 0.0, "stamina": 1.0, "rest": 0.0, "hit": 0.0, "alive": true, "leader": false, "prey": -1, "killer": ""}
	mobs.append(m)
	return m

## Вожак стаи: крупнее, крепче, кусает больнее. Пока он жив — стая держится вместе.
func _add_leader(n: int) -> Dictionary:
	var nest: Dictionary = nests[n]
	var m := _add_mob("pack", _near_land(nest.pos, 3.0), rng.randf_range(1.25, 1.35), nest.color, nest.legs, n)
	m.leader = true
	m.max_hp *= 2.2
	m.hp = m.max_hp
	m.bite *= 1.4
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
	day = fposmod(day + dt / DAY_LEN, 1.0)
	if is_night() != _night:
		_night = is_night()
		events.append({"t": "night" if _night else "day", "pos": pos})
	if not scripted:
		_move_player(dt, input)
		if do_bite:
			_player_bite()
	for m in mobs:
		if m.alive:
			_think(m, dt)
	if not scripted:
		_eat(dt)
	_nests(dt)
	for b in bushes:
		if b.fruits < FRUITS:
			b.regrow -= dt
			if b.regrow <= 0.0:
				b.fruits += 1
				b.regrow = REGROW
	for r in relics:
		r.hit = maxf(0.0, r.hit - dt * 3.0)
	for cc in carcasses:
		cc.t -= dt
	carcasses = carcasses.filter(func(cc): return cc.t > 0.0 and cc.meat > 0)
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
	# Лечишься понемногу, а в своём гнезде — быстро.
	hp = minf(max_hp, hp + dt * (float(st.regen) + (NEST_HEAL if safe() else 0.0)))

func _move_player(dt: float, input: Vector2) -> void:
	var in_water := terrain.height(pos.x, pos.z) < Terrain.WATER - 0.2
	var want := Vector3(input.x, 0.0, input.y).limit_length(1.0) * SPEED * float(st.speed) * _spd_k * (0.6 if in_water else 1.0)
	vel = vel.lerp(want, 1.0 - exp(-8.0 * dt))
	var next := pos + vel * dt
	# В воду не заходим: у берега останавливаемся (по щиколотку — можно). С перепонками —
	# по брюхо.
	if terrain.height(next.x, next.z) < Terrain.WATER - (1.3 if st.wade else 0.2):
		vel = Vector3.ZERO
		next = pos
	next = _push_out(next, 0.8)
	pos = Vector3(next.x, terrain.height(next.x, next.z), next.z)
	if want.length() > 0.3:
		heading = lerp_angle(heading, atan2(want.x, want.z), 1.0 - exp(-TURN * float(st.turn) * dt))

## Сквозь кости и окаменелости не пройти — их обходят.
func _push_out(p: Vector3, r: float) -> Vector3:
	for b in bones + relics:
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
		if d < REACH + float(st.reach) and _in_front(m.pos, fwd) and d < best_d:
			best_d = d
			best = m
	for b in bones + relics:
		if not b.alive:
			continue
		var d: float = (b.pos as Vector3).distance_to(pos) - float(b.size) * 0.9
		if d < REACH + float(st.reach) and _in_front(b.pos, fwd) and d < best_d:
			best_d = d
			best = b
	if best == null:
		return
	if best.has("kind"):
		_hurt_mob(best, bite)
	elif best.has("i"):
		# Окаменелость: разбил — внутри находка.
		best.hp -= bite * float(st.bone)
		best.hit = 1.0
		events.append({"t": "bone_hit", "pos": best.pos})
		if best.hp <= 0.0:
			best.alive = false
			relics.erase(best)
			relics_taken.append(best.i)
			_find("relic", best.pos)
	else:
		best.hp -= bite * float(st.bone)
		best.hit = 1.0
		events.append({"t": "bone_hit", "pos": best.pos})
		if best.hp <= 0.0:
			best.alive = false
			best.respawn = 90.0
			var gain: float = 12.0 if best.big else 4.0
			_gain(gain)
			events.append({"t": "bone_break", "pos": best.pos, "dna": gain, "big": best.big})

func _in_front(p: Vector3, fwd: Vector3) -> bool:
	var to := p - pos
	to.y = 0.0
	return to.length() < 0.5 or fwd.dot(to.normalized()) > 0.35

## Находка: ещё не найденная часть суши. from — откуда: relic (окаменелость — из
## недорогих), leader (вожак), giant (гигант — самая дорогая). Всё найдено — ДНК.
func _find(from: String, at: Vector3) -> String:
	var left: Array = LandParts.PARTS.keys().filter(func(id): return not evo.land_has(id))
	if left.is_empty():
		_gain(20.0)
		events.append({"t": "find", "id": "", "from": from, "pos": at, "dna": 20.0})
		return ""
	left.sort_custom(func(a, b): return int(LandParts.PARTS[a].cost) < int(LandParts.PARTS[b].cost))
	var id: String = left[left.size() - 1] if from == "giant" else left[rng.randi_range(0, mini(3, left.size() - 1))]
	evo.land_found[id] = true
	events.append({"t": "find", "id": id, "from": from, "pos": at})
	return id

func _hurt_mob(m: Dictionary, dmg: float) -> void:
	m.hp -= dmg
	m.hit = 1.0
	m.killer = "player"
	events.append({"t": "hit", "pos": m.pos, "uid": m.uid})
	match m.kind:
		"pack":
			# Ранил одного — вся стая в ярости (если вожак цел).
			_anger_pack(m.nest)
		"hermit", "hunter", "giant":
			m.angry = 8.0
		_:
			m.angry = -4.0  # бродяга — удирает

func _anger_pack(nest: int) -> void:
	if nests[nest].get("panic", 0.0) > 0.0:
		return
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
	if m.get("poison_t", 0.0) > 0.0:
		m.poison_t -= dt
		m.hp -= float(st.poison) * dt
		m.killer = "player"
	var here: Vector3 = m.pos
	var to_me := pos - here
	to_me.y = 0.0
	var dist := to_me.length()
	# Тихие лапы — замечают ближе. Пока идёт сцена выхода или ты в своём гнезде — не
	# замечают вовсе. Ночью хищники видят дальше.
	var hidden := scripted or safe()
	var seen := dist / float(st.stealth) if not hidden else INF
	var night := is_night()
	var dir := Vector3.ZERO
	var spd: float = m.speed
	var attacking := false
	match m.kind:
		"pack":
			var nest: Dictionary = nests[m.nest]
			var from_nest: float = (pos - (nest.pos as Vector3)).length()
			if nest.panic > 0.0:
				# Вожака нет — стая разбегается от тебя и гнездо не стережёт.
				m.angry = 0.0
				dir = _toward(here, m.goal)
				if m.t <= 0.0 or here.distance_to(m.goal) < 1.2:
					m.t = rng.randf_range(2.0, 5.0)
					m.goal = _near_land(nest.pos, NEST_LEASH)
				if dist < 9.0:
					dir = (dir - to_me.normalized() * 2.0).normalized()
					spd *= 1.3
			else:
				if from_nest < NEST_GUARD * float(st.stealth) and not hidden:
					_anger_pack(m.nest)
				if m.angry > 0.0 and from_nest < NEST_LEASH and not hidden:
					m.angry -= dt
					# Злая стая чуть медленнее тебя: стащил яйцо — беги, успеешь.
					dir = to_me.normalized()
					spd *= 1.15
					attacking = true
				else:
					m.angry = minf(m.angry, 0.0)
					if m.t <= 0.0 or here.distance_to(m.goal) < 1.2:
						m.t = rng.randf_range(2.0, 6.0)
						m.goal = _near_land(nest.pos, NEST_ROAM)
					dir = _toward(here, m.goal)
		"hermit":
			m.rest -= dt
			var sight := HERMIT_SIGHT * (1.3 if night else 1.0)
			if m.rest <= 0.0 and (seen < sight or m.angry > 0.0) and not hidden:
				m.angry = maxf(m.angry - dt, 0.0)
				m.stamina -= dt / HERMIT_CHASE
				dir = to_me.normalized()
				spd *= 1.155
				attacking = dist < sight
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
		"hunter":
			m.rest -= dt
			var sight := HUNTER_SIGHT * (1.6 if night else 1.0)
			# На тебя — ночью, если заметил; днём — только если ты совсем рядом или ранил.
			var want_me: bool = not hidden and m.rest <= 0.0 and (m.angry > 0.0 or seen < (sight if night else 5.0))
			var prey = _mob(m.prey)
			if m.rest > 0.0:
				dir = Vector3.ZERO  # ест
			elif want_me:
				m.angry = maxf(m.angry - dt, 0.0)
				m.stamina -= dt / 7.0
				dir = to_me.normalized()
				spd *= 1.2
				attacking = true
				if m.stamina <= 0.0:
					m.rest = 5.0
					m.stamina = 1.0
					m.angry = 0.0
			elif prey != null and (prey.pos as Vector3).distance_to(here) < sight * 1.6:
				# Охота: догнать бродягу и кусать, пока не упадёт.
				m.stamina = minf(1.0, m.stamina + dt / 6.0)
				var to_prey: Vector3 = prey.pos - here
				to_prey.y = 0.0
				dir = to_prey.normalized()
				spd *= 1.25
				if to_prey.length() < float(m.size + prey.size) * 0.6 + 0.6 and m.bite_cd <= 0.0:
					m.bite_cd = 0.9
					prey.hp -= float(m.bite)
					prey.hit = 1.0
					prey.angry = -5.0
					prey.killer = "hunter"
					if dist < 25.0:
						events.append({"t": "hunt", "pos": prey.pos, "uid": m.uid})
			else:
				m.prey = -1
				m.stamina = minf(1.0, m.stamina + dt / 6.0)
				if m.t <= 0.0:
					m.t = rng.randf_range(2.0, 5.0)
					m.goal = _near_land(here, 30.0)
					# Высматривает добычу.
					var best_d := sight
					for o in mobs:
						if o.alive and o.kind == "wander":
							var dd: float = (o.pos as Vector3).distance_to(here)
							if dd < best_d:
								best_d = dd
								m.prey = o.uid
				dir = _toward(here, m.goal) * 0.7
		"giant":
			# Гигант стережёт свои места: ушёл подальше — отстаёт и идёт назад.
			var home_: Vector3 = m.home
			var me_far := (pos - home_).length() > GIANT_HOME + 12.0
			if not hidden and not me_far and (m.angry > 0.0 or seen < GIANT_SIGHT * (1.2 if night else 1.0)):
				m.angry = maxf(m.angry - dt, 0.0)
				dir = to_me.normalized()
				attacking = true
			else:
				m.angry = 0.0
				# Отдыхает — понемногу заживает.
				m.hp = minf(m.max_hp, m.hp + dt * 2.0)
				if m.t <= 0.0 or here.distance_to(m.goal) < 2.0:
					m.t = rng.randf_range(5.0, 10.0)
					m.goal = _near_land(home_, GIANT_HOME * 0.6)
				dir = _toward(here, m.goal) * 0.5
		_:
			if m.angry < 0.0:
				m.angry += dt
				dir = -to_me.normalized() if m.killer == "player" else _away_from_hunters(here)
				spd *= 1.5
			elif night and dist > 3.0:
				dir = Vector3.ZERO  # спит
			else:
				var scared := _away_from_hunters(here)
				if scared != Vector3.ZERO:
					dir = scared
					spd *= 1.4
				else:
					# Пасётся: идёт к кусту с плодами и ест.
					if m.t <= 0.0 or here.distance_to(m.goal) < 1.5:
						m.t = rng.randf_range(3.0, 8.0)
						var bush = _bush_near(here, 30.0)
						if bush != null and here.distance_to(bush.pos) < 2.2:
							bush.fruits -= 1
							if bush.regrow <= 0.0:
								bush.regrow = REGROW
							m.t = 3.0
							m.goal = here
						elif bush != null:
							m.goal = _near_land(bush.pos, 1.0)
						else:
							m.goal = _land_point(0.0, Terrain.RADIUS * 0.8) if rng.randf() < 0.2 else _near_land(here, 25.0)
					dir = _toward(here, m.goal)
				if dist < (9.0 if st.scare else 4.0):
					dir = (dir - to_me.normalized() * 1.5).normalized()
	m.vel = (m.vel as Vector3).lerp(dir * spd, 1.0 - exp(-4.0 * dt))
	var next: Vector3 = here + m.vel * dt
	if terrain.is_water(next.x, next.z):
		m.goal = _near_land(here, 10.0)
		next = here
	next = _push_out(next, float(m.size) * 0.6)
	# В твоё гнездо никто не заходит.
	if has_nest:
		var g := Vector2(next.x - home.x, next.z - home.z)
		var keep_out: float = NEST_R + float(m.size) * 0.6
		if g.length() < keep_out and g.length() > 0.01:
			var o := g.normalized() * keep_out
			next = Vector3(home.x + o.x, next.y, home.z + o.y)
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
	if attacking and not hidden and dist < float(m.size) * 0.7 + REACH and m.bite_cd <= 0.0:
		m.bite_cd = {"pack": 1.3, "hermit": 1.1, "hunter": 1.0, "giant": 1.6}.get(m.kind, 1.2)
		var dmg: float = float(m.bite) * (1.0 - float(st.armor))
		hp -= dmg
		events.append({"t": "hurt", "pos": pos, "dmg": dmg, "kind": m.kind, "uid": m.uid})
		# Шипы и хвост-булава дают сдачи, ядовитая кожа травит.
		if st.thorns > 0.0:
			m.hp -= float(m.bite) * float(st.thorns)
			m.hit = 1.0
			m.killer = "player"
			events.append({"t": "thorns", "pos": m.pos, "uid": m.uid})
		if st.poison > 0.0:
			m.poison_t = 3.0

## Существо по номеру (живое) или null.
func _mob(uid: int):
	if uid < 0:
		return null
	for o in mobs:
		if o.uid == uid and o.alive:
			return o
	return null

## Бродяга видит хищника рядом — куда бежать (или ноль, если некого бояться).
func _away_from_hunters(here: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for o in mobs:
		if o.alive and o.kind == "hunter":
			var d: Vector3 = here - o.pos
			d.y = 0.0
			if d.length() < 9.0 and d.length() > 0.01:
				push += d.normalized() / maxf(d.length(), 1.0)
	return push.normalized() if push != Vector3.ZERO else Vector3.ZERO

## Ближайший куст с плодами.
func _bush_near(at: Vector3, r: float):
	var best = null
	var best_d := r
	for b in bushes:
		if b.fruits > 0:
			var d: float = (b.pos as Vector3).distance_to(at)
			if d < best_d:
				best_d = d
				best = b
	return best

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
	if _eat_cd > 0.0 or not st.mouth:
		return
	for b in bushes:
		if b.fruits > 0 and (b.pos as Vector3).distance_to(pos) < EAT_DIST + 0.6 + float(st.reach):
			b.fruits -= 1
			if b.regrow <= 0.0:
				b.regrow = REGROW
			eaten += 1
			var g: float = 1.0 * float(st.fruit)
			_gain(g)
			_eat_cd = 0.45
			events.append({"t": "eat", "pos": b.pos, "dna": g})
			return
	for cc in carcasses:
		if cc.meat > 0 and (cc.pos as Vector3).distance_to(pos) < 1.8 + float(st.reach):
			cc.meat -= 1
			var g: float = 3.0 * float(st.meat)
			_gain(g)
			_eat_cd = 0.8
			events.append({"t": "meat", "pos": cc.pos, "dna": g})
			return
	for i in nests.size():
		var n: Dictionary = nests[i]
		if n.eggs > 0 and (n.pos as Vector3).distance_to(pos) < 1.6 + float(st.reach):
			n.eggs -= 1
			var g: float = 5.0 * float(st.meat)
			_gain(g)
			_eat_cd = 0.8
			events.append({"t": "egg", "pos": n.pos, "dna": g})
			_anger_pack(i)
			return

## Гнёзда: яйца со временем появляются снова, стая пополняется.
func _nests(dt: float) -> void:
	for i in nests.size():
		var n: Dictionary = nests[i]
		n.panic = maxf(0.0, n.panic - dt)
		if n.leader_t > 0.0:
			n.leader_t -= dt
			if n.leader_t <= 0.0:
				_add_leader(i)
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
			if m.killer != "player":
				# Загрыз хищник — остаётся туша, хищник её ест.
				_uid += 1
				carcasses.append({"uid": _uid, "pos": m.pos, "meat": 3, "t": 90.0, "size": m.size})
				for o in mobs:
					if o.alive and o.kind == "hunter" and o.prey == m.uid:
						o.prey = -1
						o.rest = 8.0
				continue
			var gain: float = {"wander": 3.0, "pack": 4.0, "hermit": 25.0, "hunter": 8.0, "giant": 60.0}[m.kind] * float(st.meat)
			if m.leader:
				gain = 12.0 * float(st.meat)
			_gain(gain)
			events.append({"t": "kill", "pos": m.pos, "uid": m.uid, "kind": m.kind, "dna": gain, "leader": m.leader})
			if m.leader:
				# Вожака нет — стая разбегается, новый появится не скоро.
				var n: Dictionary = nests[m.nest]
				n.panic = 60.0
				n.leader_t = 150.0
				for o in mobs:
					if o.alive and o.kind == "pack" and o.nest == m.nest:
						o.angry = 0.0
				events.append({"t": "leader", "pos": m.pos})
				if rng.randf() < 0.35:
					_find("leader", m.pos)
			elif m.kind == "giant":
				giants_beaten.append(int(m.gi))
				events.append({"t": "giant_down", "pos": m.pos})
				_find("giant", m.pos)
	var dead := mobs.filter(func(m): return not m.alive)
	for m in dead:
		mobs.erase(m)
		# Бродяги, хищники и отшельники со временем приходят новые — где-нибудь подальше.
		if m.kind == "wander":
			_add_mob("wander", _land_point(40.0, Terrain.RADIUS * 0.8), rng.randf_range(0.7, 1.2), m.color, m.legs)
		elif m.kind == "hermit":
			_add_mob("hermit", _land_point(60.0, Terrain.RADIUS * 0.85), rng.randf_range(1.8, 2.3), m.color, 4)
		elif m.kind == "hunter":
			_add_mob("hunter", _land_point(60.0, Terrain.RADIUS * 0.85), rng.randf_range(1.1, 1.35), m.color, 4)
	if hp <= 0.0:
		# Тебя одолели: снова в гнезде (или у начала), целый; пятая часть добытого здесь
		# теряется. Сила остаётся.
		deaths += 1
		var lost := floorf(dna * 0.2)
		dna -= lost
		evo.dna_total = maxf(0.0, evo.dna_total - lost)
		events.append({"t": "death", "pos": pos, "lost": lost})
		pos = home
		vel = Vector3.ZERO
		hp = max_hp
		for m in mobs:
			m.angry = 0.0
