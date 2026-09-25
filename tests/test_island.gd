## Остров: своя стая, пара и поколения, запасы, дружба, умения тела, погода, атлас.
extends RefCounted

## Тело на суше с нужными частями (всё найдено).
func _land(body := {}) -> Land:
	var e := Evolution.create()
	e.dna_total = 500.0
	e.land_start()
	for id in LandParts.PARTS:
		e.land_found[id] = true
	for slot in body:
		e.land_put(body[slot])
	e.land_ready = true
	var l := Land.new(e, 5)
	l.set_nest(l._land_point(0.0, 60.0))
	return l

## Никого вокруг и ничего съедобного — проверять по одному.
func _empty(l: Land) -> void:
	l.mobs = []
	l.bushes = []
	l.drops = []
	l.carcasses = []

func _steps(l: Land, sec: float, input := Vector2.ZERO) -> Array:
	var all: Array = []
	for i in int(sec * 30.0):
		l.step(1.0 / 30.0, input)
		all += l.events
	return all

func test_ношу_в_гнездо(c) -> void:
	var l := _land()
	_empty(l)
	l.pos = l._near_land(l.home, 30.0)
	l._drop_fruit(l.pos, 0.5)
	c.ok("рядом плод — можно взять", l.can_pick())
	c.ok("взял в пасть", l.pick() and l.carry == ["fruit"] and l.drops.is_empty())
	l._drop_fruit(l.pos, 0.5)
	var dna := l.dna
	_steps(l, 1.0)
	c.ok("пасть занята — не ешь и больше не взять", l.dna == dna and not l.can_pick())
	l.pos = l.home
	var ev := _steps(l, 0.2)
	c.ok("в гнезде — в запасы", l.stash == 1 and l.carry.is_empty() and ev.any(func(e): return e.t == "stored_own"))
	l.eat_carry()
	var arms := _land({"arms": "arms"})
	_empty(arms)
	for i in 3:
		arms._drop_fruit(arms.pos, 0.5)
	arms.pick()
	arms.pick()
	c.ok("с руками — три в ноше", arms.pick() and arms.carry.size() == 3 and arms.carry_max() == 3)
	# Лечение в гнезде: с запасами — втрое быстрее.
	var h := _land()
	_empty(h)
	h.pos = h.home
	h.hp = 1.0
	_steps(h, 2.0)
	var plain := h.hp - 1.0
	h.hp = 1.0
	h.stash = 3
	_steps(h, 2.0)
	c.ok("с запасами лечишься быстрее (%.1f > %.1f)" % [h.hp - 1.0, plain], h.hp - 1.0 > plain * 2.0)

func test_пара_яйца_детёныши(c) -> void:
	var l := _land()
	_empty(l)
	var gen := l.evo.generation
	l.pos = l.home
	l.stash = 10
	var ev := _steps(l, 0.1)
	c.ok("запасов хватает — идёт пара", ev.any(func(e): return e.t == "mate_coming") and l.allies().size() == 1)
	var mate: Dictionary = l.allies()[0]
	ev = _steps(l, 30.0)
	c.ok("пара дошла до гнезда", ev.any(func(e): return e.t == "mate") and not mate.get("coming", false))
	c.ok("вместе в гнезде — два яйца, новое поколение", l.eggs.size() == 2 and l.evo.generation == gen + 1 and l.stash == 10 - Land.MATE_FOOD)
	ev = _steps(l, Land.EGG_HATCH + 1.0)
	c.ok("вылупились детёныши", ev.any(func(e): return e.t == "hatch") and l.allies().size() == 3 and l.eggs.is_empty())
	var baby: Dictionary = l.allies().filter(func(m): return not m.mate)[0]
	c.ok("детёныш маленький", baby.size < 0.7)
	var age0: float = baby.age
	_steps(l, 20.0)
	c.ok("растёт, пока есть еда", baby.age > age0)
	l.stash = 0
	var age1: float = baby.age
	_steps(l, 10.0)
	c.ok("без еды не растёт", baby.age == age1)
	# Малыши сидят в гнезде, взрослые идут за тобой.
	baby.age = 0.2
	var adult: Dictionary = l.allies().filter(func(m): return not m.mate)[1]
	adult.age = 1.0
	l._ally_stats(adult)
	var far := l._near_land(l.home, 25.0)
	var dir := Vector2(far.x - l.pos.x, far.z - l.pos.z).normalized()
	_steps(l, 4.0, dir)
	c.ok("малыш остался в гнезде", (baby.pos as Vector3).distance_to(l.home) < Land.NEST_R + 1.0)
	c.ok("взрослый идёт за тобой (%.1f м)" % (adult.pos as Vector3).distance_to(l.pos), (adult.pos as Vector3).distance_to(l.pos) < 8.0)
	# Сохраняется и читается.
	l.evo.land_save = l.snapshot()
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(l.evo.to_dict())))
	var l2 := Land.new(back, 5)
	c.ok("своя стая и запасы сохраняются", l2.allies().size() == 3 and l2.allies().filter(func(m): return m.mate).size() == 1 and l2.stash == l.stash)

func test_свои_дерутся(c) -> void:
	var l := _land()
	_empty(l)
	l.pos = l._near_land(l.home, 40.0)
	var a := l._add_ally(1.0, false, l.pos)
	var src := _land()
	var h: Dictionary = src.mobs.filter(func(m): return m.kind == "hermit")[0]
	l.mobs.append(h)
	h.pos = l._near_land(l.pos, 5.0)
	h.angry = 5.0
	var hp0: float = h.hp
	_steps(l, 4.0)
	c.ok("свой бросился на злого и кусает (%.0f → %.0f)" % [hp0, h.hp], h.hp < hp0)

func test_дружба(c) -> void:
	var l := _land()
	var n := -1
	for i in l.nests.size():
		if LandSpecies.SPECIES[l.nests[i].sp].diet == "plant":
			n = i
			break
	var nest: Dictionary = l.nests[n]
	l.mobs = l.mobs.filter(func(m): return m.nest == n)
	l.bushes = []
	for k in Land.FRIEND_AT:
		l.carry = ["fruit"]
		l.pos = nest.pos
		l.step(1.0 / 30.0, Vector2.ZERO)
		l.pos = l.home
		_steps(l, 0.5)
	c.ok("три подарка — стая друг", l.is_friend(n))
	for m in l.mobs:
		m.angry = 0.0
	l.pos = l._near_land(nest.pos, 2.0)
	_steps(l, 2.0)
	c.ok("у гнезда друзей — никто не злится", l.mobs.all(func(m): return m.angry <= 0.0))
	# Помогают против обидчика.
	var src := _land()
	var h: Dictionary = src.mobs.filter(func(m): return m.kind == "hermit")[0]
	h.pos = l._near_land(l.pos, 3.0)
	h.angry = 5.0
	l.mobs.append(h)
	_steps(l, 3.0)
	c.ok("напал отшельник — друзья бросаются на него", l.mobs.any(func(m): return m.kind == "pack" and m.task == "fight" and m.foe == h.uid))

func test_умения(c) -> void:
	var l := _land({"legs": "legs_long", "head": "crest", "skin": "poison_skin", "claws": "claws", "feet": "webbed"})
	c.eq("умения от тела", l.abilities(), ["jump", "roar", "spit", "dig"])
	_empty(l)
	c.ok("прыжок", l.use_ability("jump") and l.jump_t > 0.0)
	c.ok("перезаряжается", not l.use_ability("jump"))
	var src := _land()
	var pk: Dictionary = src.mobs.filter(func(m): return m.kind == "pack" and not m.leader)[0]
	pk.pos = l._near_land(l.pos, 4.0)
	pk.angry = 5.0
	l.mobs = [pk]
	c.ok("рёв — стая удирает", l.use_ability("roar") and pk.scared > 0.0 and pk.angry == 0.0)
	pk.pos = l.pos + l.forward() * 4.0
	var hp0: float = pk.hp
	c.ok("плевок — яд", l.use_ability("spit") and pk.poison_t > 0.0 and pk.hp < hp0)
	l.mobs = []
	var dna := l.dna
	var drops := l.drops.size()
	c.ok("копать", l.use_ability("dig") and l.dig_t > 0.0)
	var ev := _steps(l, 2.0, Vector2(1, 0))
	c.ok("докопался: ДНК, плод или окаменелость", ev.any(func(e): return e.t == "dig") and (l.dna > dna or l.drops.size() > drops))
	var plain := _land()
	c.eq("без этих частей — никаких умений", plain.abilities(), [])

func test_погода(c) -> void:
	var l := _land()
	_empty(l)
	l.weather = "storm"
	l.weather_t = 999.0
	l._bolt_t = 0.0
	var t: Dictionary = l.trees.filter(func(x): return x.kind == "fruit")[0]
	l.pos = t.pos + Vector3(3, 0, 0)
	var ev := _steps(l, 0.2)
	c.ok("гроза: молния", ev.any(func(e): return e.t == "lightning"))
	# Стаи в грозу — по гнёздам.
	var s := _land()
	var n := 0
	s.mobs = s.mobs.filter(func(m): return m.nest == n)
	s.pos = s._land_point(0.0, 250.0)
	s.weather = "storm"
	s.weather_t = 999.0
	_steps(s, 25.0)
	c.ok("в грозу стая дома", s.mobs.all(func(m): return m.task == "home" and (m.pos as Vector3).distance_to(s.nests[n].pos) < 6.0))
	# Туман: тебя замечают ближе.
	for fog in [false, true]:
		var f := _land()
		var h: Dictionary = f.mobs.filter(func(m): return m.kind == "hermit")[0]
		f.mobs = [h]
		f.weather = "fog" if fog else "clear"
		f.weather_t = 999.0
		var d := Vector3(9.0, 0, 0)
		f.pos = f._near_land(h.pos + d, 0.5)
		var ev2 := _steps(f, 3.0)
		var came := (h.pos as Vector3).distance_to(f.pos) < 6.0
		c.ok("в тумане отшельник не замечает с 9 м" if fog else "в ясную погоду — замечает", came != fog)
	# Дождь — плоды растут быстрее.
	var r := _land()
	_empty(r)
	var tt: Dictionary = r.trees.filter(func(x): return x.kind == "fruit")[0]
	tt.fruits = 0
	tt.regrow = Land.TREE_REGROW
	r.weather = "rain"
	r.weather_t = 999.0
	_steps(r, Land.TREE_REGROW / 2.0 + 1.0)
	c.ok("в дождь плоды отрастают вдвое быстрее", tt.fruits >= 1)

func test_атлас(c) -> void:
	var l := _land()
	var m: Dictionary = l.mobs.filter(func(x): return x.kind == "pack")[0]
	l.pos = l._near_land(m.pos, 5.0)
	var ev := _steps(l, 1.2)
	c.ok("подошёл — вид в атласе", l.evo.land_seen.has(m.sp) and ev.any(func(e): return e.t == "seen" and e.sp == m.sp))
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(l.evo.to_dict())))
	c.ok("атлас сохраняется", back.land_seen.has(m.sp))
	c.ok("есть описание и подсказка", LandSpecies.SPECIES.keys().all(func(s): return preload("res://scripts/land/land_atlas.gd").describe(s) != "" and preload("res://scripts/land/land_atlas.gd").hint(s) != ""))

func test_стаи_дерутся(c) -> void:
	var l := _land()
	var meat := -1
	var plant := -1
	for i in l.nests.size():
		var sp: Dictionary = LandSpecies.SPECIES[l.nests[i].sp]
		if sp.diet == "meat" and not sp.get("night", false) and meat < 0:
			meat = i
		elif sp.diet == "plant" and plant < 0:
			plant = i
	var hunter: Dictionary = l.mobs.filter(func(m): return m.nest == meat and not m.leader)[0]
	var mates: Array = l.mobs.filter(func(m): return m.nest == plant and not m.leader)
	var prey: Dictionary = mates[0]
	var buddy: Dictionary = mates[1]
	l.mobs = [hunter, prey, buddy]
	prey.pos = l._near_land(hunter.pos, 2.0)
	buddy.pos = l._near_land(prey.pos, 3.0)
	prey.task = "forage"
	prey.target = {"t": "bush", "i": 0}
	hunter.task = "hunt"
	hunter.prey = prey.uid
	l.pos = l._land_point(0.0, 250.0)
	var fought := false
	for i in 30 * 10:
		l.step(1.0 / 30.0, Vector2.ZERO)
		if buddy.task == "fight" and buddy.foe == hunter.uid:
			fought = true
			break
	c.ok("напали на своего — стая бросается на охотника", fought)
