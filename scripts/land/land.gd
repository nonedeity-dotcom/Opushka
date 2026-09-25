## Второй этап — суша. Правила без картинки: где ты, кто вокруг, что можно съесть и
## разбить. Как Pond для океана: шаг мира — step(), события — в events.
##
## Кто живёт на острове (виды — LandSpecies), три размера:
## - стаи — твоего размера, всегда вместе у своего гнезда. Травоядные ходят за плодами к
##   кустам, к деревьям и за упавшими плодами и носят их в гнездо; хищные стаи охотятся
##   на чужих сборщиков, съедают добычу и носят мясо домой. Еда в гнезде — стая растёт.
##   Подошёл к гнезду, стащил яйцо или ранил одного — нападают все. У стаи есть вожак:
##   убил его — стая разбегается;
## - отшельники — одиночки вдвое крупнее, сильные: подошёл — бросаются, пока не
##   выдохнутся;
## - гиганты — огромные и очень сильные, каждый стережёт свои места. Побеждённый гигант
##   не возвращается и оставляет находку.
## Деревья: на плодовых висят плоды — бей дерево, и они падают. Кусты — плоды достаёшь
## сам. Кости (вместо камней первого этапа) — разбиваешь укусами, из них ДНК.
## Окаменелости — тоже разбиваешь, в них находки: новые части тела.
##
## День сменяется ночью: ночью стаи спят в гнёздах (кроме ночных хищников).
## У тебя своё гнездо: там лечишься, туда возвращаешься, если одолели, и только там
## можно поменять тело. В гнездо никто не заходит.
## Существо не растёт, а крепнет: чем больше ДНК добыто на суше, тем выше сила.
##
## Своя стая: в гнезде копятся запасы (носишь еду сам — «Взять», в пасти одна, с руками
## три), с запасами лечишься втрое быстрее. Пара приходит, когда запасов хватает; вместе в
## гнезде — два яйца, из них детёныши твоего вида. Детёныши растут, пока в гнезде есть
## еда, подросшие ходят за тобой, дерутся за тебя и носят еду домой. Каждая пара яиц —
## новое поколение.
## Дружба: носи травоядной стае плоды в её гнездо — после трёх подарков она не трогает
## тебя и помогает против хищников.
## Умения тела: прыжок (длинные ноги), рёв (гребень), плевок ядом (ядовитая кожа),
## копать (когти), плавать (перепонки — можно в глубокую воду, там никто не достанет).
## Погода: ясно, дождь (всё растёт вдвое быстрее), туман (тебя замечают ближе), гроза
## (стаи прячутся, молния бьёт в деревья — плоды падают).
class_name Land
extends RefCounted

const SPEED := 6.0
const TURN := 6.0
const NESTS := 8
const HERMITS := 6
const GIANTS := 4
const BONES := 24
const BUSHES := 60
const TREES := 380
## Из них плодовые: плоды висят на дереве, падают от ударов.
const FRUIT_TREES := 60
const TREE_FRUITS := 6
const TREE_REGROW := 40.0
## Упавший плод лежит столько, потом сгнивает.
const DROP_LIFE := 150.0
const FRUITS := 4
const REGROW := 30.0
const EAT_DIST := 1.6
const EGGS := 3
## Сколько еды помещается в гнезде стаи; за две — ещё один в стае (до MAX_PACK).
const FOOD_MAX := 6
const MAX_PACK := 6
## Укус: перезарядка и насколько далеко перед собой достаёшь.
const BITE_CD := 0.5
const REACH := 1.9
## Стая: как далеко от гнезда бродят, с какого расстояния его стерегут, докуда гонятся,
## докуда ходят за едой и на охоту.
const NEST_ROAM := 9.0
const NEST_GUARD := 7.0
const NEST_LEASH := 26.0
const FORAGE_R := 45.0
const HUNT_R := 55.0
## Сколько из стаи одновременно уходят за едой.
const TRIPS := 2
## Отшельник: с какого расстояния бросается и сколько гонится.
const HERMIT_SIGHT := 11.0
const HERMIT_CHASE := 6.0
## Гигант: с какого расстояния бросается и как далеко от своих мест уходит.
const GIANT_SIGHT := 13.0
const GIANT_HOME := 24.0
const RELICS := 20
## Своё гнездо: в этом круге никто не тронет, раны заживают быстро.
const NEST_R := 5.0
const NEST_HEAL := 4.0
## Сутки — пять минут: день, закат, ночь, рассвет.
const DAY_LEN := 300.0
## Клетка сетки для деревьев (чтобы быстро находить ближайшие).
const CELL := 10.0
## Своя стая: сколько всего (с парой), запасы в гнезде, сколько запасов на пару яиц, яйцо
## до вылупления и детёныш до взрослого (секунды).
const MAX_ALLY := 5
const STASH_MAX := 12
const MATE_FOOD := 4
const EGG_HATCH := 45.0
const GROW_TIME := 180.0
## Сколько подарков — и стая друг.
const FRIEND_AT := 3
## Умения: перезарядка (секунды).
const ABILITY_CD := {"jump": 4.0, "roar": 14.0, "spit": 5.0, "dig": 18.0}
const WEATHER := ["clear", "rain", "fog", "storm"]

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
## Отравлен (ядозуб): секунд осталось и урон в секунду.
var poison_t := 0.0
var poison_dps := 0.0
## Своё гнездо (home — то же место).
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
## Только для снимков: существа стоят на месте.
var frozen := false
## Что несёшь в пасти (или в руках): ["fruit", "meat", …].
var carry: Array = []
## Запасы в своём гнезде; яйца в нём (сколько секунд до вылупления у каждого).
var stash := 0
var eggs: Array = []
## Пара уже есть (в стае) и когда можно снова откладывать яйца.
var _lay_cd := 0.0
## Дружба со стаями: номер гнезда → сколько подарков.
var friends := {}
## Перезарядка умений и что сейчас идёт: прыжок, копание.
var cd := {}
var jump_t := 0.0
var dig_t := 0.0
## Погода и сколько ещё она продлится; молния — через сколько.
var weather := "clear"
var weather_t := 150.0
var _bolt_t := 10.0
## Какие виды уже встречал (для атласа) — проверяется раз в секунду.
var _seen_t := 0.0
var _eat_cd := 0.0
var _uid := 0

## Существа: {uid, kind: pack/hermit/giant, sp (вид), pos, heading, vel, goal, size, color,
## color2, t, hp, max_hp, bite, bite_cd, speed, nest (номер гнезда или -1), angry,
## stamina, rest, hit (вспышка 0–1), alive, leader, prey, killer, task (home / forage /
## carry / hunt / eat), target, carry ("" / fruit / meat)}
var mobs: Array = []
## Гнёзда стай: {pos, sp, eggs, food, color, color2, respawn, panic, leader_t}
var nests: Array = []
## Кости: {uid, pos, size, hp, max_hp, big, hit, alive, respawn, yaw}
var bones: Array = []
## Кусты с плодами: {pos, fruits, regrow}
var bushes: Array = []
## Окаменелости: {i, pos, size, hp, max_hp, hit, alive}
var relics: Array = []
## Туши (остались после охоты): {uid, pos, meat, t, size}
var carcasses: Array = []
## Упавшие плоды: {uid, pos, t}
var drops: Array = []
## Деревья: {i, pos, size, kind (oak / pine / fruit), fruits, regrow, hit}
var trees: Array = []
var _cells := {}

func _init(e: Evolution, seed := 1) -> void:
	evo = e
	_level = evo.land_level()
	apply_body()
	rng.seed = seed
	terrain = Terrain.new(seed)
	pos = _land_point(0.0, 25.0)
	home = pos
	var fruit_n := 0
	for i in TREES:
		var p := _land_point(15.0, Terrain.RADIUS * 0.95)
		if terrain.slope(p.x, p.z) > 0.8:
			continue
		var h := terrain.height(p.x, p.z)
		var fruit := fruit_n < FRUIT_TREES and h < 7.0
		var kind := "fruit" if fruit else ("pine" if h > 5.5 or rng.randf() < 0.3 else "oak")
		if fruit:
			fruit_n += 1
		var t := {"i": trees.size(), "pos": p, "size": rng.randf_range(1.3, 2.4) if not fruit else rng.randf_range(1.2, 1.6), "kind": kind,
			"fruits": TREE_FRUITS if fruit else 0, "regrow": 0.0, "hit": 0.0}
		trees.append(t)
		var c := _cell(p)
		if not _cells.has(c):
			_cells[c] = []
		_cells[c].append(t.i)
	for i in BUSHES:
		bushes.append({"pos": _land_point(8.0, Terrain.RADIUS * 0.85), "fruits": FRUITS, "regrow": 0.0})
	# Стаи: травоядных больше, хищных меньше.
	var order := ["grazer", "fangpack", "longneck", "hopper", "shellback", "nightstalker", "grazer", "fangpack"]
	for i in NESTS:
		var at := _land_point(35.0, Terrain.RADIUS * 0.8)
		for tries in 30:
			if nests.all(func(n): return (n.pos as Vector3).distance_to(at) > 45.0):
				break
			at = _land_point(35.0, Terrain.RADIUS * 0.8)
		var sid: String = order[i % order.size()]
		var all_cols: Array = LandSpecies.SPECIES[sid].colors
		var cols: Array = all_cols[i % all_cols.size()]
		var nest := {"pos": at, "sp": sid, "eggs": EGGS, "food": 2, "color": cols[0], "color2": cols[1], "respawn": 60.0, "panic": 0.0, "leader_t": 0.0}
		nests.append(nest)
		_add_leader(nests.size() - 1)
		for k in rng.randi_range(3, 4):
			_add_member(nests.size() - 1)
	for i in HERMITS:
		_add_hermit(_land_point(45.0, Terrain.RADIUS * 0.85), i)
	for i in BONES:
		_add_bone(i < 4)
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
	var giants := LandSpecies.of_tier("giant")
	for i in GIANTS:
		var at := _land_point(Terrain.RADIUS * 0.4, Terrain.RADIUS * 0.8)
		var sid: String = giants[i % giants.size()]
		var sp: Dictionary = LandSpecies.SPECIES[sid]
		var sz := fixed.randf_range(sp.size[0], sp.size[1])
		if not giants_beaten.has(i):
			var g := _add_mob("giant", sid, at, sz, sp.colors[0][0], sp.colors[0][1])
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
	stash = int(sv.get("stash", 0))
	eggs = (sv.get("eggs", []) as Array).duplicate()
	for k in (sv.get("friends", {}) as Dictionary):
		friends[int(k)] = int(sv.friends[k])
	for a in (sv.get("allies", []) as Array):
		_add_ally(float(a[0]), bool(a[1]), home if has_nest else pos)

## Остров сейчас — для сохранения.
func snapshot() -> Dictionary:
	var al: Array = []
	for m in mobs:
		if m.kind == "ally" and m.alive:
			al.append([m.age, m.mate])
	var fr := {}
	for k in friends:
		fr[str(k)] = friends[k]
	return {"pos": [pos.x, pos.z], "hp": hp / maxf(max_hp, 1.0), "day": day,
		"nest": [home.x, home.z] if has_nest else [], "relics": relics_taken.duplicate(), "giants": giants_beaten.duplicate(),
		"stash": stash, "eggs": eggs.duplicate(), "allies": al, "friends": fr}

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
	if num.call(v.get("stash")):
		out.stash = clampi(int(v.stash), 0, STASH_MAX)
	if v.get("eggs") is Array:
		out.eggs = (v.eggs as Array).filter(num).map(func(x): return clampf(float(x), 0.0, EGG_HATCH)).slice(0, MAX_ALLY)
	if v.get("allies") is Array:
		var al: Array = []
		for a in v.allies:
			if a is Array and a.size() == 2 and num.call(a[0]) and a[1] is bool and al.size() < MAX_ALLY:
				al.append([clampf(float(a[0]), 0.0, 1.0), a[1]])
		out.allies = al
	if v.get("friends") is Dictionary:
		var fr := {}
		for k in v.friends:
			if str(k).is_valid_int() and num.call(v.friends[k]):
				fr[str(k)] = clampi(int(v.friends[k]), 0, 99)
		out.friends = fr
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

## ДНК с суши: в общий счёт вида. Заодно копится сила: набралось на следующую — сильнее
## и целый.
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

# --- кто живёт ------------------------------------------------------------------------

## Существо: kind — pack / hermit / giant, sid — вид. Здоровье, укус и скорость — от
## размера и от вида.
func _add_mob(kind: String, sid: String, at: Vector3, size: float, color: String, color2: String, nest := -1) -> Dictionary:
	_uid += 1
	var sp: Dictionary = LandSpecies.SPECIES[sid]
	var hp_: float = 14.0 * size * size * float({"hermit": 1.6, "giant": 2.0}.get(kind, 1.0)) * float(sp.hp)
	var bite_: float = float({"pack": 2.5, "hermit": 5.6, "giant": 4.2}[kind]) * size * float(sp.bite)
	var m := {"uid": _uid, "kind": kind, "sp": sid, "pos": at, "heading": rng.randf() * TAU, "vel": Vector3.ZERO, "goal": at, "size": size,
		"color": color, "color2": color2, "t": rng.randf_range(0.0, 4.0), "hp": hp_, "max_hp": hp_, "bite": bite_,
		"bite_cd": 0.0, "speed": SPEED * float(sp.speed) / sqrt(size), "nest": nest,
		"angry": 0.0, "stamina": 1.0, "rest": 0.0, "hit": 0.0, "alive": true, "leader": false, "prey": -1, "killer": "",
		"task": "home", "target": {}, "carry": ""}
	mobs.append(m)
	return m

## Ещё один в стаю — у её гнезда.
func _add_member(n: int) -> Dictionary:
	var nest: Dictionary = nests[n]
	var sp: Dictionary = LandSpecies.SPECIES[nest.sp]
	return _add_mob("pack", nest.sp, _near_land(nest.pos, 6.0), rng.randf_range(sp.size[0], sp.size[1]), nest.color, nest.color2, n)

## Вожак стаи: чуть крупнее, крепче, кусает больнее, всегда у гнезда. Пока он жив — стая
## держится вместе.
func _add_leader(n: int) -> Dictionary:
	var m := _add_member(n)
	m.leader = true
	m.size = float(m.size) * 1.25
	m.max_hp = float(m.max_hp) * 2.2
	m.hp = m.max_hp
	m.bite = float(m.bite) * 1.4
	return m

## Отшельник: вид по очереди, где-нибудь вдали.
func _add_hermit(at: Vector3, i: int) -> Dictionary:
	var list := LandSpecies.of_tier("hermit")
	var sid: String = list[posmod(i, list.size())]
	var sp: Dictionary = LandSpecies.SPECIES[sid]
	var cols: Array = sp.colors[posmod(i, sp.colors.size())]
	return _add_mob("hermit", sid, at, rng.randf_range(sp.size[0], sp.size[1]), cols[0], cols[1])

## Свой: детёныш (age 0) растёт до взрослого (1); mate — пара.
func _add_ally(age: float, mate: bool, at: Vector3) -> Dictionary:
	_uid += 1
	var m := {"uid": _uid, "kind": "ally", "sp": "", "pos": _near_land(at, 2.0), "heading": rng.randf() * TAU, "vel": Vector3.ZERO, "goal": at,
		"size": 1.0, "age": age, "mate": mate, "t": 0.0, "hp": 1.0, "max_hp": 1.0, "bite": 1.0, "bite_cd": 0.0, "speed": SPEED,
		"nest": -1, "angry": 0.0, "stamina": 1.0, "rest": 0.0, "hit": 0.0, "alive": true, "leader": false, "prey": -1, "killer": "",
		"task": "home", "target": {}, "carry": "", "foe": -1, "slot": mobs.filter(func(o): return o.kind == "ally").size()}
	_ally_stats(m)
	m.hp = m.max_hp
	mobs.append(m)
	return m

## Свой растёт: размер, здоровье и укус — от возраста и от твоих.
func _ally_stats(m: Dictionary) -> void:
	var k: float = 0.55 + 0.45 * float(m.age)
	var frac: float = m.hp / maxf(m.max_hp, 0.01)
	m.size = k * (0.95 if m.mate else 1.0)
	m.max_hp = max_hp * 0.6 * k * k
	m.hp = m.max_hp * frac
	m.bite = bite * 0.45 * k

func allies() -> Array:
	return mobs.filter(func(m): return m.kind == "ally" and m.alive)

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

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

## Деревья в радиусе r (по сетке — быстро).
func trees_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	var c := _cell(p)
	var k := int(ceil(r / CELL))
	for dz in range(-k, k + 1):
		for dx in range(-k, k + 1):
			for i in _cells.get(c + Vector2i(dx, dz), []):
				var t: Dictionary = trees[i]
				if Vector2(t.pos.x - p.x, t.pos.z - p.z).length() < r:
					out.append(t)
	return out

## Толщина ствола.
static func trunk(t: Dictionary) -> float:
	return 0.3 * float(t.size)

# --- шаг ------------------------------------------------------------------------------

## Шаг. input — куда идти в плоскости земли (x, z), длина 0–1; do_bite — нажат «Укус».
func step(dt: float, input: Vector2, do_bite := false) -> void:
	events.clear()
	time += dt
	bite_cd -= dt
	day = fposmod(day + dt / DAY_LEN, 1.0)
	if is_night() != _night:
		_night = is_night()
		events.append({"t": "night" if _night else "day", "pos": pos})
	_weather(dt)
	for k in cd.keys():
		cd[k] = maxf(0.0, float(cd[k]) - dt)
	jump_t = maxf(0.0, jump_t - dt)
	if dig_t > 0.0:
		dig_t -= dt
		if dig_t <= 0.0:
			_dug()
	if not scripted:
		_move_player(dt, input)
		if do_bite:
			_player_bite()
	for m in mobs:
		if m.alive and not frozen:
			_think(m, dt)
	if not scripted:
		_eat(dt)
		_home(dt)
	_nests(dt)
	_seen_t -= dt
	if _seen_t <= 0.0:
		_seen_t = 1.0
		for m in mobs:
			if m.alive and m.sp != "" and not evo.land_seen.has(m.sp) and (m.pos as Vector3).distance_to(pos) < 18.0 + float(m.size) * 3.0:
				evo.land_seen[m.sp] = true
				events.append({"t": "seen", "sp": m.sp, "pos": m.pos})
	var grow := dt * (2.0 if weather in ["rain", "storm"] else 1.0)
	for b in bushes:
		if b.fruits < FRUITS:
			b.regrow -= grow
			if b.regrow <= 0.0:
				b.fruits += 1
				b.regrow = REGROW
	for t in trees:
		if t.hit > 0.0:
			t.hit = maxf(0.0, t.hit - dt * 2.5)
		if t.kind == "fruit" and t.fruits < TREE_FRUITS:
			t.regrow -= grow
			if t.regrow <= 0.0:
				t.fruits += 1
				t.regrow = TREE_REGROW
	for d in drops:
		d.t -= dt
	drops = drops.filter(func(d): return d.t > 0.0)
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
	if poison_t > 0.0:
		poison_t -= dt
		hp -= poison_dps * dt
	_deaths()
	# Лечишься понемногу, а в своём гнезде — быстро (с запасами — втрое быстрее).
	hp = minf(max_hp, hp + dt * (float(st.regen) + (NEST_HEAL * (3.0 if stash > 0 else 1.0) if safe() else 0.0)))

func _move_player(dt: float, input: Vector2) -> void:
	var in_water := terrain.height(pos.x, pos.z) < Terrain.WATER - 0.2
	if dig_t > 0.0:
		input = Vector2.ZERO  # копаешь — стоишь
	var want := Vector3(input.x, 0.0, input.y).limit_length(1.0) * SPEED * float(st.speed) * _spd_k * (0.6 if in_water else 1.0)
	if jump_t > 0.0:
		want = forward() * SPEED * 2.4  # в прыжке — вперёд, быстро
	vel = vel.lerp(want, 1.0 - exp(-(20.0 if jump_t > 0.0 else 8.0) * dt))
	var next := pos + vel * dt
	# В воду не заходим: у берега останавливаемся (по щиколотку — можно). С перепонками —
	# плывёшь и в глубину (там никто не достанет).
	if terrain.height(next.x, next.z) < Terrain.WATER - (6.0 if st.wade else 0.2):
		vel = Vector3.ZERO
		next = pos
	if jump_t <= 0.0:
		next = _push_out(next, 0.8)
	pos = Vector3(next.x, maxf(terrain.height(next.x, next.z), Terrain.WATER - 0.5 if swimming_at(next) else -INF), next.z)
	if want.length() > 0.3:
		heading = lerp_angle(heading, atan2(want.x, want.z), 1.0 - exp(-TURN * float(st.turn) * dt))

## Сквозь кости, окаменелости и стволы не пройти — их обходят.
func _push_out(p: Vector3, r: float) -> Vector3:
	for b in bones + relics:
		if not b.alive:
			continue
		var d := Vector2(p.x - b.pos.x, p.z - b.pos.z)
		var need: float = r + float(b.size) * 0.9
		if d.length() < need and d.length() > 0.01:
			var out := d.normalized() * need
			p = Vector3(b.pos.x + out.x, p.y, b.pos.z + out.y)
	for t in trees_near(p, r + 2.0):
		var d := Vector2(p.x - t.pos.x, p.z - t.pos.z)
		var need: float = r * 0.6 + trunk(t)
		if d.length() < need and d.length() > 0.01:
			var out := d.normalized() * need
			p = Vector3(t.pos.x + out.x, p.y, t.pos.z + out.y)
	return p

## Плывёшь (глубже, чем по брюхо)?
func swimming_at(p: Vector3) -> bool:
	return st.get("wade", false) and terrain.height(p.x, p.z) < Terrain.WATER - 1.0

func swimming() -> bool:
	return swimming_at(pos)

func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))

## Укус: ближайший перед тобой — существо, кость, окаменелость или дерево.
func _player_bite() -> void:
	if bite_cd > 0.0:
		return
	bite_cd = BITE_CD
	events.append({"t": "bite", "pos": pos})
	var fwd := forward()
	var best = null
	var best_d := INF
	var what := ""
	var reach := REACH + float(st.reach)
	for m in mobs:
		if not m.alive or m.kind == "ally":
			continue
		var d: float = (m.pos as Vector3).distance_to(pos) - float(m.size) * 0.6
		if d < reach and _in_front(m.pos, fwd) and d < best_d:
			best_d = d
			best = m
			what = "mob"
	for b in bones:
		if not b.alive:
			continue
		var d: float = (b.pos as Vector3).distance_to(pos) - float(b.size) * 0.9
		if d < reach and _in_front(b.pos, fwd) and d < best_d:
			best_d = d
			best = b
			what = "bone"
	for b in relics:
		var d: float = (b.pos as Vector3).distance_to(pos) - float(b.size) * 0.9
		if d < reach and _in_front(b.pos, fwd) and d < best_d:
			best_d = d
			best = b
			what = "relic"
	for t in trees_near(pos, reach + 3.0):
		var d: float = Vector2(t.pos.x - pos.x, t.pos.z - pos.z).length() - trunk(t)
		if d < reach and _in_front(t.pos, fwd) and d < best_d:
			best_d = d
			best = t
			what = "tree"
	match what:
		"mob":
			_hurt_mob(best, bite)
		"tree":
			_hit_tree(best)
		"relic":
			# Окаменелость: разбил — внутри находка.
			best.hp -= bite * float(st.bone)
			best.hit = 1.0
			events.append({"t": "bone_hit", "pos": best.pos})
			if best.hp <= 0.0:
				best.alive = false
				relics.erase(best)
				relics_taken.append(best.i)
				_find("relic", best.pos)
		"bone":
			best.hp -= bite * float(st.bone)
			best.hit = 1.0
			events.append({"t": "bone_hit", "pos": best.pos})
			if best.hp <= 0.0:
				best.alive = false
				best.respawn = 90.0
				var gain: float = 12.0 if best.big else 4.0
				_gain(gain)
				events.append({"t": "bone_break", "pos": best.pos, "dna": gain, "big": best.big})

## Ударил дерево: оно качается, с плодового падают плоды (сильный укус — больше).
func _hit_tree(t: Dictionary) -> void:
	t.hit = 1.0
	events.append({"t": "tree_hit", "pos": t.pos, "i": t.i})
	if t.kind != "fruit" or t.fruits <= 0:
		return
	var n := mini(int(t.fruits), 1 + (1 if bite >= 9.0 else 0) + (1 if bite >= 16.0 else 0))
	for k in n:
		t.fruits -= 1
		if t.regrow <= 0.0:
			t.regrow = TREE_REGROW
		_drop_fruit(t.pos, trunk(t) + rng.randf_range(0.8, 2.6))
	events.append({"t": "fruit_fall", "pos": t.pos, "n": n})

## Плод на землю: рядом с точкой, на суше.
func _drop_fruit(at: Vector3, r: float) -> void:
	var p := at
	for tries in 8:
		var a := rng.randf() * TAU
		p = at + Vector3(cos(a), 0.0, sin(a)) * r
		if not terrain.is_water(p.x, p.z):
			break
	_uid += 1
	drops.append({"uid": _uid, "pos": Vector3(p.x, terrain.height(p.x, p.z), p.z), "t": DROP_LIFE})

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
	# Нёс еду — роняет.
	_drop_carry(m)
	match m.kind:
		"pack":
			# Ранил одного — вся стая в ярости (если вожак цел). Друзей обидел — дружбы нет.
			friends.erase(int(m.nest))
			_anger_pack(m.nest)
		_:
			m.angry = 8.0

## Уронить то, что нёс: плод — на землю, мясо — кусок туши.
func _drop_carry(m: Dictionary) -> void:
	if m.carry == "fruit":
		_drop_fruit(m.pos, 0.6)
	elif m.carry == "meat":
		_uid += 1
		carcasses.append({"uid": _uid, "pos": m.pos, "meat": 1, "t": 60.0, "size": 0.6})
	m.carry = ""
	if m.task == "carry":
		m.task = "home"

func _anger_pack(nest: int) -> void:
	if nests[nest].get("panic", 0.0) > 0.0 or is_friend(nest):
		return
	var fresh := false
	for o in mobs:
		if o.alive and o.kind == "pack" and o.nest == nest:
			if o.angry <= 0.0:
				fresh = true
			o.angry = 8.0
	if fresh:
		events.append({"t": "alarm", "pos": nests[nest].pos})

## Стая дружит с тобой?
func is_friend(n: int) -> bool:
	return int(friends.get(n, 0)) >= FRIEND_AT

# --- как они думают --------------------------------------------------------------------

func _think(m: Dictionary, dt: float) -> void:
	m.t -= dt
	m.bite_cd -= dt
	if m.get("chomp", 0.0) > 0.0:
		m.chomp = maxf(0.0, m.chomp - dt)
	m.sleep = false
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
	# замечают вовсе.
	var hidden := scripted or safe()
	# В тумане тебя замечают ближе.
	var seen := dist / float(st.stealth) * (1.4 if weather == "fog" else 1.0) if not hidden else INF
	var sp: Dictionary = LandSpecies.SPECIES.get(m.sp, {})
	var dir := Vector3.ZERO
	var spd: float = m.speed
	var attacking := false
	match m.kind:
		"ally":
			var r := _think_ally(m, dt, dist)
			dir = r[0]
			spd *= float(r[1])
		"pack":
			var r := _think_pack(m, dt, dist, seen, hidden)
			dir = r[0]
			spd *= float(r[1])
			attacking = r[2]
		"hermit":
			m.rest -= dt
			var sight := HERMIT_SIGHT * (1.3 if is_night() else 1.0)
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
		"giant":
			# Гигант стережёт свои места: ушёл подальше — отстаёт и идёт назад.
			var home_: Vector3 = m.home
			var me_far := (pos - home_).length() > GIANT_HOME + 12.0
			if not hidden and not me_far and (m.angry > 0.0 or seen < GIANT_SIGHT * (1.2 if is_night() else 1.0)):
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
	m.vel = (m.vel as Vector3).lerp(dir * spd, 1.0 - exp(-4.0 * dt))
	var next: Vector3 = here + m.vel * dt
	if terrain.is_water(next.x, next.z):
		m.goal = _near_land(here, 10.0)
		next = here
	if m.kind != "giant":
		next = _push_out(next, float(m.size) * 0.6)
	# В твоё гнездо никто чужой не заходит.
	if has_nest and m.kind != "ally":
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
	# Твои рядом — достаётся и им.
	if attacking and m.bite_cd <= 0.0:
		var a = _ally_near(m.pos, float(m.size) * 0.7 + REACH)
		if a != null and (hidden or dist > float(m.size) * 0.7 + REACH or (a.pos as Vector3).distance_to(m.pos) < dist):
			m.bite_cd = float({"pack": 1.3, "hermit": 1.1, "giant": 1.6}.get(m.kind, 1.2))
			a.hp -= float(m.bite)
			a.hit = 1.0
			a.foe = m.uid
			events.append({"t": "ally_hurt", "pos": a.pos, "uid": a.uid, "by": m.uid})
	# Кусает, если злой и достаёт. В прыжке не достать.
	if attacking and not hidden and jump_t <= 0.0 and dist < float(m.size) * 0.7 + REACH and m.bite_cd <= 0.0:
		m.bite_cd = float({"pack": 1.3, "hermit": 1.1, "giant": 1.6}.get(m.kind, 1.2))
		var dmg: float = float(m.bite) * (1.0 - float(st.armor))
		hp -= dmg
		events.append({"t": "hurt", "pos": pos, "dmg": dmg, "kind": m.kind, "uid": m.uid})
		_call_help(m)
		if sp.has("poison"):
			poison_t = 4.0
			poison_dps = float(sp.poison)
			events.append({"t": "poisoned", "pos": pos})
		# Шипы и хвост-булава дают сдачи, ядовитая кожа травит.
		if st.thorns > 0.0:
			m.hp -= float(m.bite) * float(st.thorns)
			m.hit = 1.0
			m.killer = "player"
			events.append({"t": "thorns", "pos": m.pos, "uid": m.uid})
		if st.poison > 0.0:
			m.poison_t = 3.0

## Стая: [куда идти, во сколько быстрее, кусает ли тебя].
func _think_pack(m: Dictionary, dt: float, dist: float, seen: float, hidden: bool) -> Array:
	var nest: Dictionary = nests[m.nest]
	var sp: Dictionary = LandSpecies.SPECIES[m.sp]
	var here: Vector3 = m.pos
	var to_me := pos - here
	to_me.y = 0.0
	var me_from_nest: float = (pos - (nest.pos as Vector3)).length()
	# В грозу все прячутся по гнёздам.
	var awake: bool = is_night() == bool(sp.get("night", false)) and weather != "storm"
	var friend := is_friend(m.nest)
	if friend:
		dist = INF  # друзья тебя не боятся и не трогают
	# Напугал рёвом — удирают от тебя.
	if m.get("scared", 0.0) > 0.0:
		m.scared -= dt
		m.angry = 0.0
		return [(here - pos).normalized() * Vector3(1, 0, 1), 1.3, false]
	if m.task == "fight":
		m.fight_t = float(m.get("fight_t", 0.0)) - dt
		var foe = _mob(int(m.get("foe", -1)))
		if foe == null or m.fight_t <= 0.0:
			m.task = "home"
		else:
			var to_foe: Vector3 = foe.pos - here
			to_foe.y = 0.0
			if to_foe.length() < float(m.size + foe.size) * 0.6 + 0.7 and m.bite_cd <= 0.0:
				m.bite_cd = 1.0
				foe.hp -= float(m.bite)
				foe.hit = 1.0
				if foe.kind != "ally":
					foe.killer = "pack" if foe.killer != "player" else "player"
				m.chomp = 0.5
			return [to_foe.normalized(), 1.2, false]
	# Без вожака — разбегаются от тебя, гнездо не стерегут.
	if nest.panic > 0.0:
		m.angry = 0.0
		if m.t <= 0.0 or here.distance_to(m.goal) < 1.2:
			m.t = rng.randf_range(2.0, 5.0)
			m.goal = _near_land(nest.pos, NEST_LEASH)
		var d := _toward(here, m.goal)
		if dist < 9.0:
			return [(d - to_me.normalized() * 2.0).normalized(), 1.3, false]
		return [d, 1.0, false]
	if me_from_nest < NEST_GUARD * float(st.stealth) and not hidden and not friend:
		_anger_pack(m.nest)
	# Злые: гонятся за тобой, пока ты у их земли (охотники вдали — пока хватает сил).
	if m.angry > 0.0 and not hidden and (me_from_nest < NEST_LEASH or (m.task == "hunt" and m.stamina > 0.0)):
		m.angry -= dt
		if m.task != "home":
			m.stamina -= dt / 7.0
		# Злая стая чуть медленнее тебя: стащил яйцо — беги, успеешь.
		return [to_me.normalized(), minf(1.15, 0.9 * SPEED / sqrt(float(m.size)) / float(m.speed)), true]
	m.angry = minf(m.angry, 0.0)
	# Хищник на охоте замечает тебя вблизи (ночник ночью — издалека) и бросается.
	if sp.diet == "meat" and m.task == "hunt" and awake and not friend and seen < (10.0 if sp.get("night", false) else 5.0):
		m.angry = 5.0
		m.stamina = 1.0
	match m.task:
		"forage":
			var tp = _target_pos(m.target)
			if tp == null or not awake:
				m.task = "home"
				return [Vector3.ZERO, 1.0, false]
			# Сборщики удирают от тебя и от хищников.
			var fear := _fear(here, dist, sp)
			if fear != Vector3.ZERO:
				return [fear, 1.4, false]
			var reach_: float = 1.6
			if m.target.t == "tree":
				reach_ += trunk(trees[m.target.i]) + float(m.size) * 0.5
			if Vector2(tp.x - here.x, tp.z - here.z).length() < reach_:
				if _take(m.target):
					m.carry = "fruit"
					m.task = "carry"
					m.chomp = 0.5
				else:
					m.task = "home"
			return [_toward(here, tp), 1.0, false]
		"carry":
			var fear := _fear(here, dist, sp)
			var to_nest := _toward(here, nest.pos)
			if here.distance_to(nest.pos) < 2.2:
				nest.food = mini(int(nest.food) + 1, FOOD_MAX)
				m.carry = ""
				m.task = "home"
				m.t = rng.randf_range(4.0, 10.0)
				if dist < 30.0:
					events.append({"t": "stored", "pos": nest.pos})
			if fear != Vector3.ZERO:
				return [(to_nest + fear).normalized(), 1.3, false]
			return [to_nest, 1.0, false]
		"hunt":
			var prey = _mob(m.prey)
			if prey == null or not awake or (prey.pos as Vector3).distance_to(nest.pos) > HUNT_R * 1.3:
				m.task = "home"
				m.prey = -1
				return [Vector3.ZERO, 1.0, false]
			var to_prey: Vector3 = prey.pos - here
			to_prey.y = 0.0
			if to_prey.length() < float(m.size + prey.size) * 0.6 + 0.6 and m.bite_cd <= 0.0:
				m.bite_cd = 0.9
				prey.hp -= float(m.bite)
				prey.hit = 1.0
				prey.killer = "pack"
				m.chomp = 0.5
				# Сборщика укусили — бросает всё и бежит домой, а свои рядом бросаются
				# на охотника.
				_drop_carry(prey)
				if prey.task == "forage":
					prey.task = "carry"
				for o in mobs:
					if o.alive and o.kind == "pack" and o.nest == prey.nest and o != prey and (o.pos as Vector3).distance_to(prey.pos) < 14.0:
						o.task = "fight"
						o.foe = m.uid
						o.fight_t = 8.0
				if dist < 30.0:
					events.append({"t": "hunt", "pos": prey.pos, "uid": m.uid})
			return [to_prey.normalized(), 1.25, false]
		"eat":
			var cc = _carcass(int(m.target.get("uid", -1)))
			if cc == null:
				m.task = "home"
				return [Vector3.ZERO, 1.0, false]
			if here.distance_to(cc.pos) > 1.8:
				return [_toward(here, cc.pos), 1.0, false]
			m.rest -= dt
			if m.rest <= 0.0:
				cc.meat -= 1
				m.carry = "meat"
				m.task = "carry"
			return [Vector3.ZERO, 1.0, false]
	# Дома: бродят у гнезда (спящие — лежат в нём), по очереди уходят за едой.
	if not awake:
		if here.distance_to(nest.pos) > 3.5:
			return [_toward(here, nest.pos), 0.8, false]
		m.sleep = weather != "storm" or is_night()
		return [Vector3.ZERO, 1.0, false]
	if m.t <= 0.0 or here.distance_to(m.goal) < 1.2:
		m.t = rng.randf_range(3.0, 7.0)
		m.goal = _near_land(nest.pos, NEST_ROAM)
		if not m.leader and _trips(m.nest) < TRIPS and rng.randf() < 0.6:
			if sp.diet == "plant":
				var f := _food_near(nest.pos, FORAGE_R, bool(sp.get("tree", false)))
				if not f.is_empty():
					m.task = "forage"
					m.target = f
			else:
				var prey = _prey_near(nest.pos, HUNT_R, m.nest)
				if prey != null:
					m.task = "hunt"
					m.prey = prey.uid
					m.stamina = 1.0
	var d := _toward(here, m.goal)
	if sp.get("skittish", false) and dist < 6.0:
		d = (d - to_me.normalized() * 1.5).normalized()
	if st.scare and dist < 9.0:
		d = (d - to_me.normalized() * 1.5).normalized()
	return [d, 1.0, false]

## Свой: растёт (если в гнезде есть еда), дерётся с тем, кто нападает на тебя или на
## своих, носит еду в гнездо, а в остальное время ходит за тобой. Малыши и пара, пока идёт
## к гнезду, — у гнезда. [куда, во сколько быстрее]
func _think_ally(m: Dictionary, dt: float, dist: float) -> Array:
	var here: Vector3 = m.pos
	var nest_at := home
	if m.age < 1.0 and stash > 0:
		m.age = minf(1.0, float(m.age) + dt / GROW_TIME)
		m.fed = float(m.get("fed", 0.0)) + dt
		if m.fed >= 60.0:
			m.fed = 0.0
			stash -= 1
		_ally_stats(m)
	# Пара только пришла — идёт к гнезду.
	if m.get("coming", false):
		if Vector2(here.x - nest_at.x, here.z - nest_at.z).length() < NEST_R:
			m.coming = false
			events.append({"t": "mate", "pos": here})
		return [_toward(here, nest_at), 0.8]
	# Драка: тот, кто кусал тебя или своих, или злой рядом.
	var foe = _mob(int(m.foe))
	if foe == null or foe.kind == "ally" or (foe.pos as Vector3).distance_to(pos) > 30.0:
		m.foe = -1
		foe = null
		if m.age >= 0.5:
			var best_d := 12.0
			for o in mobs:
				if not o.alive or o.kind == "ally" or (o.kind == "pack" and is_friend(o.nest)):
					continue
				var d: float = (o.pos as Vector3).distance_to(pos)
				if o.angry > 0.0 and d < best_d:
					best_d = d
					foe = o
			if foe != null:
				m.foe = foe.uid
	if foe != null:
		var to_foe: Vector3 = foe.pos - here
		to_foe.y = 0.0
		if to_foe.length() < float(m.size + foe.size) * 0.6 + 0.7 and m.bite_cd <= 0.0:
			m.bite_cd = 0.8
			foe.hp -= float(m.bite)
			foe.hit = 1.0
			foe.killer = "player"
			m.chomp = 0.5
			if foe.kind == "pack":
				_anger_pack(foe.nest)
			elif foe.kind != "giant":
				foe.angry = maxf(foe.angry, 4.0)
		return [to_foe.normalized(), 1.25]
	# Несёт еду домой.
	if m.carry != "":
		if Vector2(here.x - nest_at.x, here.z - nest_at.z).length() < NEST_R:
			stash = mini(stash + 1, STASH_MAX)
			m.carry = ""
			m.task = "home"
			events.append({"t": "ally_store", "pos": here})
		return [_toward(here, nest_at), 1.1]
	if m.task == "forage":
		var tp = _target_pos(m.target)
		if tp == null:
			m.task = "home"
		else:
			if Vector2(tp.x - here.x, tp.z - here.z).length() < 1.6:
				if _take(m.target):
					m.carry = "fruit"
					m.chomp = 0.5
				m.task = "home"
			return [_toward(here, tp), 1.0]
	# Малыши — в гнезде; взрослые — за тобой (ты в гнезде — и они там).
	var stay: bool = m.age < 0.5 or safe()
	if stay and has_nest:
		if is_night() and here.distance_to(nest_at) < NEST_R:
			m.sleep = true
			return [Vector3.ZERO, 1.0]
		if m.t <= 0.0 or here.distance_to(m.goal) < 1.0:
			m.t = rng.randf_range(2.0, 5.0)
			m.goal = _near_land(nest_at, NEST_R * 0.7)
		return [_toward(here, m.goal) * 0.5, 1.0]
	# Сходить за едой, пока ты стоишь.
	if m.t <= 0.0:
		m.t = rng.randf_range(3.0, 6.0)
		if has_nest and stash < STASH_MAX and vel.length() < 1.0 and here.distance_to(nest_at) < 60.0 and rng.randf() < 0.5:
			var f := _food_near(here, 18.0, false)
			if not f.is_empty():
				m.task = "forage"
				m.target = f
	# Строем позади тебя.
	var slot: int = int(m.slot)
	var side := -1.0 if slot % 2 == 0 else 1.0
	var spot := pos - forward() * (2.2 + 1.4 * (slot / 2)) + Vector3(forward().z, 0, -forward().x) * side * 1.4
	var gap := Vector2(spot.x - here.x, spot.z - here.z).length()
	if gap < 0.8:
		return [Vector3.ZERO, 1.0]
	return [_toward(here, spot), clampf(gap / 3.0, 0.6, 1.4) * maxf(float(st.speed) * _spd_k, 1.0)]

## Свой рядом с точкой (ближе r) или null.
func _ally_near(at: Vector3, r: float):
	for o in mobs:
		if o.alive and o.kind == "ally" and (o.pos as Vector3).distance_to(at) < r:
			return o
	return null

## Тебя кусают — свои и друзья рядом бросаются на обидчика.
func _call_help(by: Dictionary) -> void:
	for o in mobs:
		if not o.alive or (o.pos as Vector3).distance_to(pos) > 20.0:
			continue
		if o.kind == "ally":
			o.foe = by.uid
		elif o.kind == "pack" and is_friend(o.nest) and o != by and not o.leader:
			o.task = "fight"
			o.foe = by.uid
			o.fight_t = 10.0

## Сколько можно нести: в пасти одно, с руками — три.
func carry_max() -> int:
	return 3 if evo.land_body.has("arms") else 1

## Есть что взять рядом (упавший плод, туша, куст)?
func can_pick() -> bool:
	return carry.size() < carry_max() and not _pick_target().is_empty()

func _pick_target() -> Dictionary:
	var r := 2.2 + float(st.reach)
	for d in drops:
		if (d.pos as Vector3).distance_to(pos) < r:
			return {"t": "drop", "uid": d.uid, "what": "fruit"}
	for cc in carcasses:
		if cc.meat > 0 and (cc.pos as Vector3).distance_to(pos) < r:
			return {"t": "carcass", "uid": cc.uid, "what": "meat"}
	for i in bushes.size():
		if bushes[i].fruits > 0 and (bushes[i].pos as Vector3).distance_to(pos) < r + 0.6:
			return {"t": "bush", "i": i, "what": "fruit"}
	return {}

## «Взять»: плод или кусок мяса — в пасть (или в руки), нести в гнездо или стае в подарок.
func pick() -> bool:
	if carry.size() >= carry_max():
		return false
	var tg := _pick_target()
	if tg.is_empty():
		return false
	if tg.t == "carcass":
		var cc = _carcass(int(tg.uid))
		cc.meat -= 1
	elif not _take(tg):
		return false
	carry.append(tg.what)
	_eat_cd = 1.0
	events.append({"t": "pick", "pos": pos, "what": tg.what})
	return true

## Съесть то, что несёшь.
func eat_carry() -> void:
	if carry.is_empty():
		return
	var w: String = carry.pop_back()
	if w == "fruit":
		_fruit(pos, 1.0)
	else:
		var g: float = 3.0 * float(st.meat)
		_gain(g)
		events.append({"t": "meat", "pos": pos, "dna": g})

## Своё гнездо: принёс еду — в запасы; у травоядной стаи — подарок; яйца, пара, детёныши.
func _home(dt: float) -> void:
	_lay_cd -= dt
	var hatched := 0
	for i in eggs.size():
		eggs[i] = float(eggs[i]) - dt
		if float(eggs[i]) <= 0.0:
			hatched += 1
	if hatched > 0:
		eggs = eggs.filter(func(e): return float(e) > 0.0)
		for k in hatched:
			_add_ally(0.0, false, home)
		events.append({"t": "hatch", "pos": home, "n": hatched})
	if not carry.is_empty() and has_nest and at_nest():
		var n := carry.size()
		stash = mini(stash + n, STASH_MAX)
		carry.clear()
		events.append({"t": "stored_own", "pos": home, "n": n})
	if carry.has("fruit"):
		for i in nests.size():
			var nn: Dictionary = nests[i]
			if LandSpecies.SPECIES[nn.sp].diet == "plant" and (nn.pos as Vector3).distance_to(pos) < 2.8 + float(st.reach):
				carry.erase("fruit")
				nn.food = mini(int(nn.food) + 1, FOOD_MAX)
				var was := is_friend(i)
				friends[i] = int(friends.get(i, 0)) + 1
				for o in mobs:
					if o.alive and o.kind == "pack" and o.nest == i:
						o.angry = 0.0
				events.append({"t": "friend" if is_friend(i) and not was else "gift", "pos": nn.pos, "nest": i, "n": friends[i]})
				break
	if not has_nest:
		return
	var al := allies()
	var mate = null
	for a in al:
		if a.mate:
			mate = a
	var room := MAX_ALLY - al.size() - eggs.size()
	if mate == null and stash >= MATE_FOOD and at_nest() and room > 0:
		# Запасов хватает — приходит пара.
		var m := _add_ally(1.0, true, _near_land(home, 28.0))
		m.coming = true
		events.append({"t": "mate_coming", "pos": m.pos})
	elif mate != null and not mate.get("coming", false) and at_nest() and stash >= MATE_FOOD and _lay_cd <= 0.0 and room > 0 \
			and Vector2(mate.pos.x - home.x, mate.pos.z - home.z).length() < NEST_R + 1.5:
		stash -= MATE_FOOD
		for k in mini(2, room):
			eggs.append(EGG_HATCH)
		_lay_cd = 120.0
		evo.generation += 1
		events.append({"t": "eggs", "pos": home, "gen": evo.generation})

# --- умения тела ----------------------------------------------------------------------

## Какие умения даёт тело: прыжок (длинные ноги), рёв (гребень), плевок (ядовитая кожа),
## копать (когти). Плавание (перепонки) — само.
func abilities() -> Array:
	var b: Dictionary = evo.land_body
	var out: Array = []
	if b.get("legs", "") == "legs_long":
		out.append("jump")
	if b.get("head", "") == "crest":
		out.append("roar")
	if b.get("skin", "") == "poison_skin":
		out.append("spit")
	if b.get("claws", "") != "":
		out.append("dig")
	return out

## Применить умение. Перезаряжается — нет.
func use_ability(id: String) -> bool:
	if scripted or float(cd.get(id, 0.0)) > 0.0 or not abilities().has(id) or dig_t > 0.0:
		return false
	cd[id] = ABILITY_CD[id]
	match id:
		"jump":
			jump_t = 0.45
			events.append({"t": "jump", "pos": pos})
		"roar":
			for m in mobs:
				if not m.alive or m.kind == "ally" or (m.pos as Vector3).distance_to(pos) > 14.0:
					continue
				if m.kind == "pack" and not is_friend(m.nest):
					m.scared = 6.0
					m.angry = 0.0
				elif m.kind == "hermit":
					m.rest = 3.0
					m.angry = 0.0
			events.append({"t": "roar", "pos": pos})
		"spit":
			var best = null
			var best_d := 10.0
			for m in mobs:
				if not m.alive or m.kind == "ally":
					continue
				var to: Vector3 = m.pos - pos
				to.y = 0.0
				if to.length() < best_d and forward().dot(to.normalized()) > 0.5:
					best_d = to.length()
					best = m
			var at: Vector3 = best.pos if best != null else pos + forward() * 6.0
			if best != null:
				best.poison_t = 4.0
				_hurt_mob(best, 3.0)
			events.append({"t": "spit", "pos": pos, "to": at})
		"dig":
			dig_t = 1.5
			events.append({"t": "dig_start", "pos": pos})
	return true

## Докопался: чаще ДНК из земли, иногда корень-плод или старые кости; рядом окаменелость —
## докопался и до неё.
func _dug() -> void:
	for r in relics:
		if (r.pos as Vector3).distance_to(pos) < 6.0:
			r.hp -= 15.0
			r.hit = 1.0
			if r.hp <= 0.0:
				r.alive = false
				relics.erase(r)
				relics_taken.append(r.i)
				_find("relic", r.pos)
			events.append({"t": "dig", "pos": pos, "what": "relic"})
			return
	var roll := rng.randf()
	if roll < 0.3:
		_drop_fruit(pos, 1.0)
		events.append({"t": "dig", "pos": pos, "what": "fruit"})
	else:
		var g := 10.0 if roll > 0.85 else float(rng.randi_range(3, 6))
		_gain(g)
		events.append({"t": "dig", "pos": pos, "what": "dna", "dna": g})

# --- погода ---------------------------------------------------------------------------

func _weather(dt: float) -> void:
	weather_t -= dt
	if weather_t <= 0.0:
		var r := rng.randf()
		var was := weather
		weather = "clear" if r < 0.5 else ("rain" if r < 0.75 else ("fog" if r < 0.9 else "storm"))
		weather_t = rng.randf_range(90.0, 200.0)
		if weather != was:
			events.append({"t": "weather", "w": weather, "pos": pos})
	if weather == "storm":
		_bolt_t -= dt
		if _bolt_t <= 0.0:
			_bolt_t = rng.randf_range(6.0, 14.0)
			# Молния бьёт в дерево неподалёку — с плодового падают все плоды.
			var near := trees_near(pos, 45.0)
			var at := pos + Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40))
			if not near.is_empty():
				var t: Dictionary = near[rng.randi() % near.size()]
				at = t.pos
				t.hit = 1.0
				if t.kind == "fruit":
					for k in int(t.fruits):
						_drop_fruit(t.pos, trunk(t) + rng.randf_range(0.8, 3.0))
					t.fruits = 0
					t.regrow = TREE_REGROW
			events.append({"t": "lightning", "pos": at})

## Сколько из стаи сейчас в походе.
func _trips(n: int) -> int:
	return mobs.filter(func(o): return o.alive and o.kind == "pack" and o.nest == n and o.task != "home").size()

## Сборщик боится: тебя (пугливые — издалека) и хищников на охоте. Куда бежать — или ноль.
func _fear(here: Vector3, dist: float, sp: Dictionary) -> Vector3:
	var push := Vector3.ZERO
	if not (scripted or safe()) and dist < (8.0 if sp.get("skittish", false) else 4.0) * float(st.stealth):
		var d := here - pos
		d.y = 0.0
		push += d.normalized()
	for o in mobs:
		if o.alive and o.kind == "pack" and o.task == "hunt":
			var d: Vector3 = here - o.pos
			d.y = 0.0
			if d.length() < 9.0 and d.length() > 0.01:
				push += d.normalized()
	return push.normalized() if push != Vector3.ZERO else Vector3.ZERO

## Еда рядом с гнездом: куст, упавший плод или (у длинношеих) дерево с плодами.
## {t: bush/drop/tree, i или uid} — или пусто.
func _food_near(at: Vector3, r: float, tree_ok: bool) -> Dictionary:
	var best := {}
	var best_d := r
	for i in bushes.size():
		var b: Dictionary = bushes[i]
		var d: float = (b.pos as Vector3).distance_to(at)
		if b.fruits > 0 and d < best_d:
			best_d = d
			best = {"t": "bush", "i": i}
	for dr in drops:
		var d: float = (dr.pos as Vector3).distance_to(at) * 0.8  # упавшее — охотнее
		if d < best_d:
			best_d = d
			best = {"t": "drop", "uid": dr.uid}
	if tree_ok:
		for t in trees_near(at, r):
			var d: float = (t.pos as Vector3).distance_to(at)
			if t.kind == "fruit" and t.fruits > 0 and d < best_d:
				best_d = d
				best = {"t": "tree", "i": t.i}
	return best

## Где цель сборщика (или null, если её уже нет).
func _target_pos(tg: Dictionary):
	match tg.get("t", ""):
		"bush":
			return bushes[tg.i].pos if bushes[tg.i].fruits > 0 else null
		"tree":
			return trees[tg.i].pos if trees[tg.i].fruits > 0 else null
		"drop":
			for d in drops:
				if d.uid == tg.uid:
					return d.pos
	return null

## Взять еду с цели. Удалось?
func _take(tg: Dictionary) -> bool:
	match tg.get("t", ""):
		"bush":
			var b: Dictionary = bushes[tg.i]
			if b.fruits > 0:
				b.fruits -= 1
				if b.regrow <= 0.0:
					b.regrow = REGROW
				return true
		"tree":
			var t: Dictionary = trees[tg.i]
			if t.fruits > 0:
				t.fruits -= 1
				t.hit = 0.6
				if t.regrow <= 0.0:
					t.regrow = TREE_REGROW
				return true
		"drop":
			for d in drops:
				if d.uid == tg.uid:
					drops.erase(d)
					return true
	return false

## Добыча хищной стаи: травоядный из чужой стаи, ушедший от своего гнезда.
func _prey_near(at: Vector3, r: float, own: int):
	var best = null
	var best_d := r
	for o in mobs:
		if not o.alive or o.kind != "pack" or o.nest == own or o.leader:
			continue
		if LandSpecies.SPECIES[o.sp].diet != "plant":
			continue
		var away: float = (o.pos as Vector3).distance_to(nests[o.nest].pos)
		var d: float = (o.pos as Vector3).distance_to(at)
		if away > 8.0 and d < best_d:
			best_d = d
			best = o
	return best

## Существо по номеру (живое) или null.
func _mob(uid: int):
	if uid < 0:
		return null
	for o in mobs:
		if o.uid == uid and o.alive:
			return o
	return null

func _carcass(uid: int):
	for cc in carcasses:
		if cc.uid == uid and cc.meat > 0:
			return cc
	return null

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

# --- еда, гнёзда, гибель ---------------------------------------------------------------

## Плоды, туши, яйца и запасы стай: подошёл — съел. Из гнезда — стая этого не простит.
func _eat(dt: float) -> void:
	_eat_cd -= dt
	# Несёшь в пасти — есть нечем (с руками — можно).
	if _eat_cd > 0.0 or not st.mouth or (not carry.is_empty() and carry_max() == 1):
		return
	var reach := float(st.reach)
	for d in drops:
		if (d.pos as Vector3).distance_to(pos) < EAT_DIST + 0.3 + reach:
			drops.erase(d)
			_fruit(d.pos, 1.2)
			return
	for b in bushes:
		if b.fruits > 0 and (b.pos as Vector3).distance_to(pos) < EAT_DIST + 0.6 + reach:
			b.fruits -= 1
			if b.regrow <= 0.0:
				b.regrow = REGROW
			_fruit(b.pos, 1.0)
			return
	for cc in carcasses:
		if cc.meat > 0 and (cc.pos as Vector3).distance_to(pos) < 1.8 + reach:
			cc.meat -= 1
			var g: float = 3.0 * float(st.meat)
			_gain(g)
			_eat_cd = 0.8
			events.append({"t": "meat", "pos": cc.pos, "dna": g})
			return
	for i in nests.size():
		var n: Dictionary = nests[i]
		if (n.pos as Vector3).distance_to(pos) >= 1.6 + reach:
			continue
		if n.eggs > 0:
			n.eggs -= 1
			var g: float = 5.0 * float(st.meat)
			_gain(g)
			_eat_cd = 0.8
			events.append({"t": "egg", "pos": n.pos, "dna": g})
			_anger_pack(i)
			return
		if n.food > 0:
			n.food -= 1
			var plant: bool = LandSpecies.SPECIES[n.sp].diet == "plant"
			var g: float = 2.0 * float(st.fruit if plant else st.meat)
			_gain(g)
			_eat_cd = 0.8
			events.append({"t": "stash", "pos": n.pos, "dna": g})
			_anger_pack(i)
			return

func _fruit(at: Vector3, k: float) -> void:
	eaten += 1
	var g: float = k * float(st.fruit)
	_gain(g)
	_eat_cd = 0.45
	events.append({"t": "eat", "pos": at, "dna": g})

## Гнёзда: яйца со временем появляются снова, вожак возвращается, а из запасённой еды
## стая растёт.
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
			_add_member(i)
		elif alive < MAX_PACK and n.food >= 2:
			n.food -= 2
			_add_member(i)

func _deaths() -> void:
	for m in mobs:
		if m.alive and m.hp <= 0.0:
			m.alive = false
			if m.kind == "ally":
				events.append({"t": "ally_dead", "pos": m.pos, "mate": m.mate})
				continue
			if m.killer != "player":
				# Загрызли хищники — остаётся туша, они её едят и несут домой.
				_uid += 1
				var cc := {"uid": _uid, "pos": m.pos, "meat": 3, "t": 90.0, "size": m.size}
				carcasses.append(cc)
				for o in mobs:
					if o.alive and o.kind == "pack" and o.task == "hunt" and o.prey == m.uid:
						o.prey = -1
						o.task = "eat"
						o.target = {"uid": cc.uid}
						o.rest = 4.0
				continue
			_drop_carry(m)
			var gain: float = float({"pack": 4.0, "hermit": 25.0, "giant": 60.0}[m.kind]) * float(st.meat)
			if m.leader:
				gain = 12.0 * float(st.meat)
			_gain(gain)
			events.append({"t": "kill", "pos": m.pos, "uid": m.uid, "kind": m.kind, "sp": m.sp, "dna": gain, "leader": m.leader})
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
				events.append({"t": "giant_down", "pos": m.pos, "sp": m.sp})
				_find("giant", m.pos)
	var dead := mobs.filter(func(m): return not m.alive)
	for m in dead:
		mobs.erase(m)
		# Отшельники со временем приходят новые — где-нибудь подальше. Стаи пополняются
		# сами, у гнёзд.
		if m.kind == "hermit":
			_add_hermit(_land_point(60.0, Terrain.RADIUS * 0.85), rng.randi_range(0, 99))
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
		poison_t = 0.0
		for m in mobs:
			m.angry = 0.0
