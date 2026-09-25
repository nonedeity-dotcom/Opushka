## Суша: остров, ходьба, берег, плоды, соседи.
extends RefCounted

func _land() -> Land:
	return Land.new(Evolution.create(), 5)

func test_остров(c) -> void:
	var t := Terrain.new(5)
	c.ok("середина — суша", not t.is_water(0.0, 0.0))
	c.ok("далеко — море", t.is_water(Terrain.RADIUS * 1.4, 0.0) and t.is_water(0.0, -Terrain.RADIUS * 1.4))
	c.eq("один сид — один остров", Terrain.new(5).height(37.0, -12.0), t.height(37.0, -12.0))
	var m := t.build_mesh()
	c.ok("сетка с цветом", m.get_surface_count() == 1 and not (m.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray).is_empty())

func test_ходьба(c) -> void:
	var l := _land()
	var start := l.pos
	for i in 60:
		l.step(1.0 / 30.0, Vector2(1, 0))
	c.ok("идёт (%.1f м за 2 с)" % start.distance_to(l.pos), start.distance_to(l.pos) > Land.SPEED * 1.2)
	c.ok("стоит на земле", absf(l.pos.y - l.terrain.height(l.pos.x, l.pos.z)) < 0.01)
	c.ok("смотрит, куда идёт", absf(wrapf(l.heading - PI / 2.0, -PI, PI)) < 0.3)

func test_в_море_не_уйти(c) -> void:
	var l := _land()
	for i in 30 * 90:
		l.step(1.0 / 30.0, Vector2(0.7, 0.7))
	c.ok("упёрся в берег и не утонул", l.terrain.height(l.pos.x, l.pos.z) > Terrain.WATER - 0.25)

func test_плоды(c) -> void:
	var l := _land()
	var b: Dictionary = l.bushes[0]
	l.pos = b.pos + Vector3(1.0, 0, 0)
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("съел плод", l.eaten == 1 and b.fruits == Land.FRUITS - 1 and l.events.any(func(e): return e.t == "eat"))
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("не всё разом", l.eaten, 1)
	for i in 30 * 3:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("стоишь у куста — съешь все", b.fruits, 0)
	l.pos = b.pos + Vector3(30.0, 0, 0)
	for i in 30 * int(Land.REGROW + 1.0):
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("плоды отрастают", b.fruits >= 1)

func test_соседи(c) -> void:
	var l := _land()
	var starts := {}
	for m in l.mobs:
		starts[m.uid] = m.pos
	l.pos = Vector3(0, l.terrain.height(0, 0), 0)
	for i in 30 * 60:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("бродят", l.mobs.any(func(m): return starts.has(m.uid) and (m.pos as Vector3).distance_to(starts[m.uid]) > 5.0))
	c.ok("и не лезут в море", l.mobs.all(func(m): return not l.terrain.is_water(m.pos.x, m.pos.z)))
	c.ok("есть все трое: стаи, отшельники, гиганты", ["pack", "hermit", "giant"].all(func(k): return l.mobs.any(func(m): return m.kind == k)))
	c.ok("твоего размера — только стаи", l.mobs.all(func(m): return m.kind == "pack" or m.size >= 1.8))
	c.ok("отшельники вдвое крупнее, гиганты — огромные", l.mobs.all(func(m): return m.kind != "hermit" or (m.size >= 1.8 and m.size <= 2.4)) and l.mobs.all(func(m): return m.kind != "giant" or m.size >= 3.5))
	var kinds := {}
	for m in l.mobs:
		kinds[m.sp] = true
	c.ok("разных видов много (%d)" % kinds.size(), kinds.size() >= 10)

## Поставить тебя рядом с точкой, лицом к ней.
func _face(l: Land, at: Vector3, gap: float) -> void:
	var d := Vector3(1, 0, 0)
	for a in 16:
		d = Vector3(cos(TAU * a / 16.0), 0, sin(TAU * a / 16.0))
		var p := at + d * gap
		if not l.terrain.is_water(p.x, p.z):
			break
	var p := at + d * gap
	l.pos = Vector3(p.x, l.terrain.height(p.x, p.z), p.z)
	l.heading = atan2(-d.x, -d.z)

## Убрать всех, кроме нужных, — чтобы проверять по одному.
func _only(l: Land, keep: Callable) -> void:
	l.mobs = l.mobs.filter(keep)

func test_гнездо_стерегут(c) -> void:
	var l := _land()
	var nest: Dictionary = l.nests[0]
	_only(l, func(m): return m.kind == "pack" and m.nest == 0)
	c.ok("у гнезда стая (%d)" % l.mobs.size(), l.mobs.size() >= 3)
	c.ok("пока далеко — спокойны", l.mobs.all(func(m): return m.angry <= 0.0))
	_face(l, nest.pos, 1.0)
	var dna := l.dna
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("стащил яйцо — +ДНК", l.dna >= dna + 5.0 * l.st.meat - 0.01 and nest.eggs == Land.EGGS - 1 and l.events.any(func(e): return e.t == "egg"))
	c.ok("стая злится", l.mobs.all(func(m): return m.angry > 0.0))
	var dmg := 0.0
	for i in 30 * 6:
		l.step(1.0 / 30.0, Vector2.ZERO)
		for e in l.events:
			if e.t == "hurt" and e.kind == "pack":
				dmg += e.dmg
	c.ok("и кусает (%.0f за 6 с)" % dmg, dmg > 5.0)

func test_стая_не_гонится_далеко(c) -> void:
	var l := _land()
	var nest: Dictionary = l.nests[0]
	_only(l, func(m): return m.kind == "pack" and m.nest == 0)
	l._anger_pack(0)
	l.pos = l._land_point(0.0, Terrain.RADIUS * 0.8)
	var tries := 0
	while (l.pos - (nest.pos as Vector3)).length() < Land.NEST_LEASH + 20.0 and tries < 200:
		l.pos = l._land_point(0.0, Terrain.RADIUS * 0.8)
		tries += 1
	for i in 30 * 20:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("вернулись к гнезду", l.mobs.all(func(m): return (m.pos as Vector3).distance_to(nest.pos) < Land.NEST_LEASH))

func test_отшельник(c) -> void:
	var l := _land()
	_only(l, func(m): return m.kind == "hermit")
	var h: Dictionary = l.mobs[0]
	l.mobs = [h]
	c.ok("крупнее и крепче других", h.size >= 1.8 and h.max_hp > 60.0)
	_face(l, h.pos, 8.0)
	var dmg := 0.0
	for i in 30 * 4:
		l.step(1.0 / 30.0, Vector2.ZERO)
		for e in l.events:
			if e.t == "hurt" and e.kind == "hermit":
				dmg = maxf(dmg, e.dmg)
	c.ok("бросается и кусает больно (%.0f за раз)" % dmg, dmg >= 9.0)
	# Убежать: отшельник выдыхается.
	var gap := 0.0
	var away := Vector2(l.pos.x - h.pos.x, l.pos.z - h.pos.z).normalized()
	for i in 30 * 14:
		l.hp = l.max_hp
		l.step(1.0 / 30.0, away)
		gap = maxf(gap, (h.pos as Vector3).distance_to(l.pos))
	c.ok("выдыхается — можно убежать (%.0f м)" % gap, h.rest > 0.0 or gap > Land.HERMIT_SIGHT)

func test_убить_отшельника(c) -> void:
	var l := _land()
	_only(l, func(m): return m.kind == "hermit")
	var h: Dictionary = l.mobs[0]
	l.mobs = [h]
	h.hp = 1.0
	_face(l, h.pos, float(h.size) * 0.7 + 0.8)
	var dna := l.dna
	l.step(1.0 / 30.0, Vector2.ZERO, true)
	c.ok("укус добил", l.events.any(func(e): return e.t == "kill" and e.kind == "hermit"))
	c.eq("много ДНК", l.dna - dna, 25.0 * l.st.meat)
	c.ok("на его место придёт другой", l.mobs.size() == 1 and l.mobs[0].uid != h.uid and l.mobs[0].kind == "hermit")

func test_кости(c) -> void:
	var l := _land()
	l.mobs = []
	var b: Dictionary = l.bones.filter(func(x): return not x.big)[0]
	_face(l, b.pos, float(b.size) * 0.9 + 0.9)
	var dna := l.dna
	var bites := 0
	for i in 30 * 10:
		l.step(1.0 / 30.0, Vector2.ZERO, true)
		if l.events.any(func(e): return e.t == "bone_hit"):
			bites += 1
		if not b.alive:
			break
	c.ok("разбил за %d укусов" % bites, not b.alive and bites >= 2)
	c.eq("ДНК из маленькой кучки", l.dna - dna, 4.0)
	var big: Dictionary = l.bones.filter(func(x): return x.big and x.alive)[0]
	_face(l, big.pos, float(big.size) * 0.9 + 3.0)
	var toward := Vector2(big.pos.x - l.pos.x, big.pos.z - l.pos.z).normalized()
	for i in 30 * 3:
		l.step(1.0 / 30.0, toward)
	var d := Vector2(l.pos.x - big.pos.x, l.pos.z - big.pos.z).length()
	c.ok("упёрся в скелет (%.1f м)" % d, d >= float(big.size) * 0.9 + 0.7)
	for i in 30 * 91:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("кости со временем снова лежат", l.bones.filter(func(x): return x.alive).size(), Land.BONES)

func test_смерть(c) -> void:
	var l := _land()
	l.mobs = []
	l.bushes = []
	l.dna = 50.0
	l.pos = l.home + Vector3(3, 0, 0)
	l.hp = 0.0
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("событие", l.events.any(func(e): return e.t == "death"))
	c.ok("снова у начала и целый", l.pos.distance_to(l.home) < 0.01 and l.hp == l.max_hp)
	c.eq("теряешь пятую часть ДНК", l.dna, 40.0)

func test_яйцо_и_бегом(c) -> void:
	# Стащил яйцо и сразу убегаешь — стая отстаёт, а у края своей земли бросает погоню.
	var l := _land()
	var ok := 0
	for n in l.nests.size():
		var l2 := Land.new(Evolution.create(), 5)
		var nest: Dictionary = l2.nests[n]
		_face(l2, nest.pos, 1.0)
		var away := Vector2(l2.pos.x - nest.pos.x, l2.pos.z - nest.pos.z).normalized()
		for i in 30 * 8:
			l2.step(1.0 / 30.0, away)
		if l2.deaths == 0:
			ok += 1
	c.ok("выжил у %d гнёзд из %d" % [ok, l.nests.size()], ok >= l.nests.size() - 1)

# --- остров: сила, гнездо, сохранение, находки, живой мир ------------------------------

func test_сила(c) -> void:
	var e := Evolution.create()
	var l := Land.new(e, 5)
	l.mobs = []
	c.eq("в начале — сила 1", e.land_level(), 1)
	var hp1 := l.max_hp
	var bite1 := l.bite
	l._gain(float(LandParts.LEVELS[1]))
	c.ok("набрал ДНК — сила 2", e.land_level() == 2 and l.events.any(func(x): return x.t == "level" and x.level == 2))
	c.ok("здоровья и укуса больше, размер тот же", l.max_hp > hp1 * 1.1 and l.bite > bite1 * 1.1 and l.hp == l.max_hp)
	l._gain(5000.0)
	c.eq("больше десятой силы не бывает", e.land_level(), LandParts.LEVELS.size())
	c.eq("на последней — путь пройден", LandParts.level_progress(e.land_xp), [0.0, 1.0])
	var xp := e.land_xp
	l.hp = 0.0
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.eq("одолели — сила не теряется", e.land_xp, xp)

func test_своё_гнездо(c) -> void:
	var l := _land()
	var h: Dictionary = l.mobs.filter(func(m): return m.kind == "hermit")[0]
	l.mobs = [h]
	l.set_nest(h.pos + Vector3(8.0, 0, 0))
	if l.terrain.is_water(l.home.x, l.home.z):
		l.set_nest(l._land_point(0.0, 40.0))
	l.pos = l.home
	c.ok("в гнезде — можно менять тело", l.at_nest() and l.safe())
	h.pos = l.home + Vector3(7.0, 0, 0)
	h.angry = 5.0
	l.hp = l.max_hp * 0.3
	var hp0 := l.hp
	var closest := INF
	for i in 30 * 5:
		l.step(1.0 / 30.0, Vector2.ZERO)
		closest = minf(closest, Vector2(h.pos.x - l.home.x, h.pos.z - l.home.z).length())
	c.ok("в гнездо никто не заходит (ближе всего %.1f м)" % closest, closest >= Land.NEST_R)
	c.ok("в гнезде не кусают и лечат (%.0f → %.0f)" % [hp0, l.hp], l.hp >= hp0 + Land.NEST_HEAL * 4.0)
	l.pos = l._land_point(60.0, 100.0)
	c.ok("вдали — тело не поменять", not l.at_nest())
	l.hp = 0.0
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("одолели — снова в гнезде", l.pos.distance_to(l.home) < 0.01)

func test_остров_сохраняется(c) -> void:
	var e := Evolution.create()
	var l := Land.new(e, 9)
	var nest := l._land_point(10.0, 60.0)
	l.set_nest(nest)
	l.pos = l._land_point(10.0, 60.0)
	l.day = 0.7
	l.hp = l.max_hp * 0.5
	var r: Dictionary = l.relics[3]
	l.relics.erase(r)
	l.relics_taken.append(r.i)
	l.giants_beaten.append(1)
	e.land_save = l.snapshot()
	var back := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	var l2 := Land.new(back, 9)
	c.ok("там же, где был", Vector2(l2.pos.x - l.pos.x, l2.pos.z - l.pos.z).length() < 0.01)
	c.ok("гнездо на месте", l2.has_nest and Vector2(l2.home.x - nest.x, l2.home.z - nest.z).length() < 0.01)
	c.ok("та же ночь и то же здоровье", absf(l2.day - 0.7) < 0.001 and absf(l2.hp / l2.max_hp - 0.5) < 0.01)
	c.eq("разбитая окаменелость не вернулась", l2.relics.size(), Land.RELICS - 1)
	c.ok("остальные — на тех же местах", l2.relics.all(func(x): return l.relics.any(func(y): return y.i == x.i and (y.pos as Vector3).distance_to(x.pos) < 0.01)))
	c.ok("побеждённого гиганта нет", l2.mobs.filter(func(m): return m.kind == "giant").size() == Land.GIANTS - 1 and not l2.mobs.any(func(m): return m.kind == "giant" and m.gi == 1))
	c.eq("кривое сохранение — пусто", Land.fix_save({"pos": "где-то", "relics": [1, "x", 1]}), {"relics": [1]})

func test_находки(c) -> void:
	var e := Evolution.create()
	e.dna_total = 500.0
	e.land_start()
	c.ok("клыков сразу нет — не поставить", not e.land_has("fangs") and not e.land_put("fangs").ok)
	c.ok("основа есть сразу", e.land_has("legs4") and e.land_put("legs4").ok)
	var l := Land.new(e, 5)
	l.mobs = []
	var r: Dictionary = l.relics[0]
	_face(l, r.pos, 1.9)
	var before := e.land_found.size()
	var id := ""
	for i in 30 * 20:
		l.step(1.0 / 30.0, Vector2.ZERO, true)
		for x in l.events:
			if x.t == "find":
				id = x.id
		if not r.alive:
			break
	c.ok("разбил окаменелость — находка: %s" % id, not r.alive and id != "" and e.land_has(id) and e.land_found.size() == before + 1)
	c.ok("и её можно поставить", e.land_put(id).ok)
	c.ok("окаменелость помнится разбитой", l.relics_taken.has(r.i) and not l.relics.has(r))
	var best := l._find("giant", l.pos)
	var left: Array = LandParts.PARTS.keys().filter(func(x): return not e.land_has(x) or x == best)
	c.ok("гигант даёт самую дорогую из ненайденных (%s)" % best, left.all(func(x): return int(LandParts.PARTS[x].cost) <= int(LandParts.PARTS[best].cost)))
	for x in LandParts.PARTS:
		e.land_found[x] = true
	var dna := l.dna
	l._find("relic", l.pos)
	c.eq("всё найдено — ДНК", l.dna - dna, 20.0)

## Хищная стая и травоядная: номера гнёзд.
func _pair_nests(l: Land) -> Array:
	var meat := -1
	var plant := -1
	for i in l.nests.size():
		var diet: String = LandSpecies.SPECIES[l.nests[i].sp].diet
		if diet == "meat" and not LandSpecies.SPECIES[l.nests[i].sp].get("night", false) and meat < 0:
			meat = i
		elif diet == "plant" and plant < 0:
			plant = i
	return [meat, plant]

## Встать подальше от всех (чтобы никто тебя не замечал).
func _away(l: Land) -> void:
	l.pos = l._land_point(0.0, 200.0)
	for tries in 200:
		if l.mobs.all(func(m): return (m.pos as Vector3).distance_to(l.pos) > 40.0):
			return
		l.pos = l._land_point(0.0, 200.0)

func test_хищная_стая_и_туша(c) -> void:
	var l := _land()
	l.day = 0.1
	var pn := _pair_nests(l)
	var hunter: Dictionary = l.mobs.filter(func(m): return m.nest == pn[0] and not m.leader)[0]
	var prey: Dictionary = l.mobs.filter(func(m): return m.nest == pn[1] and not m.leader)[0]
	l.mobs = [hunter, prey]
	# Сборщик ушёл далеко от своего гнезда — прямо к хищнику.
	prey.pos = l._near_land(hunter.pos, 5.0)
	prey.task = "forage"
	prey.target = {"t": "bush", "i": 0}
	hunter.task = "hunt"
	hunter.prey = prey.uid
	_away(l)
	var killed := false
	for i in 30 * 40:
		l.step(1.0 / 30.0, Vector2.ZERO)
		if not l.carcasses.is_empty():
			killed = true
			break
	c.ok("хищная стая загрызла сборщика — осталась туша", killed)
	c.ok("ДНК за чужую добычу не дают", l.dna == 0.0)
	var food0: int = l.nests[pn[0]].food
	var stored := false
	for i in 30 * 60:
		l.step(1.0 / 30.0, Vector2.ZERO)
		if int(l.nests[pn[0]].food) > food0:
			stored = true
			break
	c.ok("поела и унесла мясо в своё гнездо", stored)
	var cc: Dictionary = {"uid": 999, "pos": l.pos + Vector3(1.0, 0, 0), "meat": 3, "t": 60.0, "size": 1.0}
	l.carcasses = [cc]
	l.mobs = []
	l.bushes = []
	l.drops = []
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("доел тушу — +ДНК", l.dna > 0.0 and cc.meat == 2 and l.events.any(func(x): return x.t == "meat"))

func test_стая_носит_еду(c) -> void:
	var l := _land()
	l.day = 0.1
	var pn := _pair_nests(l)
	var n: int = pn[1]
	_only(l, func(m): return m.nest == n)
	_away(l)
	var nest: Dictionary = l.nests[n]
	var food0: int = nest.food
	var far := 0.0
	var carried := false
	for i in 30 * 90:
		l.step(1.0 / 30.0, Vector2.ZERO)
		for m in l.mobs:
			far = maxf(far, (m.pos as Vector3).distance_to(nest.pos))
			if m.carry == "fruit":
				carried = true
		if int(nest.food) > food0:
			break
	c.ok("уходят от гнезда за едой (до %.0f м)" % far, far > Land.NEST_ROAM + 3.0)
	c.ok("несут плоды в пасти", carried)
	c.ok("и складывают в гнездо", int(nest.food) > food0)
	nest.food = Land.FOOD_MAX
	var size0 := l.mobs.size()
	nest.respawn = 0.0
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("из запасов стая растёт", l.mobs.size() == size0 + 1 or size0 >= Land.MAX_PACK)
	var dna := l.dna
	nest.eggs = 0
	nest.food = 2
	_face(l, nest.pos, 1.0)
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("стащил из запасов — +ДНК и стая злится", l.dna > dna and l.events.any(func(x): return x.t == "stash") and l.mobs.all(func(m): return m.angry > 0.0))

func test_плоды_на_дереве(c) -> void:
	var l := _land()
	l.mobs = []
	var t: Dictionary = l.trees.filter(func(x): return x.kind == "fruit")[0]
	c.ok("на плодовом дереве висят плоды", t.fruits == Land.TREE_FRUITS)
	_face(l, t.pos, Land.trunk(t) + 1.2)
	l.bushes = []
	l.step(1.0 / 30.0, Vector2.ZERO, true)
	c.ok("ударил дерево — плоды упали", l.events.any(func(x): return x.t == "fruit_fall") and t.fruits < Land.TREE_FRUITS and not l.drops.is_empty())
	var d: Dictionary = l.drops[0]
	var dna := l.dna
	l.pos = d.pos
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("подобрал упавший плод — +ДНК", l.dna > dna and not l.drops.has(d))
	var oak: Dictionary = l.trees.filter(func(x): return x.kind != "fruit")[0]
	_face(l, oak.pos, Land.trunk(oak) + 1.2)
	var n := l.drops.size()
	l.bite_cd = 0.0
	l.step(1.0 / 30.0, Vector2.ZERO, true)
	c.ok("с простого дерева ничего не падает, но оно качается", oak.hit > 0.0 and l.drops.size() == n)
	var toward := Vector2(oak.pos.x - l.pos.x, oak.pos.z - l.pos.z).normalized()
	for i in 30 * 2:
		l.step(1.0 / 30.0, toward)
	c.ok("сквозь ствол не пройти", Vector2(l.pos.x - oak.pos.x, l.pos.z - oak.pos.z).length() >= Land.trunk(oak) + 0.4)
	var ter := Terrain.new(5)
	var plain := ter.build_mesh()
	var worn := ter.build_mesh([{"a": Vector2(0, 0), "b": Vector2(30, 0), "r": 4.0}])
	c.ok("тропа протоптана — земля другого цвета", plain.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != worn.surface_get_arrays(0)[Mesh.ARRAY_COLOR])

func test_вожак(c) -> void:
	var l := _land()
	_only(l, func(m): return m.kind == "pack" and m.nest == 0)
	var boss: Array = l.mobs.filter(func(m): return m.leader)
	c.eq("у стаи один вожак", boss.size(), 1)
	var lead: Dictionary = boss[0]
	c.ok("вожак крупнее и крепче", l.mobs.all(func(m): return m == lead or (lead.size > m.size and lead.max_hp > m.max_hp * 1.5)))
	lead.hp = 1.0
	_face(l, lead.pos, float(lead.size) * 0.7 + 0.8)
	l.step(1.0 / 30.0, Vector2.ZERO, true)
	c.ok("вожак повержен", l.events.any(func(x): return x.t == "leader"))
	var nest: Dictionary = l.nests[0]
	_face(l, nest.pos, 1.0)
	l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("без вожака стащил яйцо — никто не злится", l.events.any(func(x): return x.t == "egg") and l.mobs.all(func(m): return m.angry <= 0.0))
	for i in 30 * int(nest.leader_t + 1.0):
		l.step(1.0 / 30.0, Vector2(0.0, 0.0))
	c.ok("со временем новый вожак", l.mobs.any(func(m): return m.leader and m.nest == 0))

func test_день_и_ночь(c) -> void:
	c.eq("утро — светло", Land.daylight(0.1), 1.0)
	c.eq("ночь — темно", Land.daylight(0.75), 0.0)
	c.ok("закат — между", Land.daylight(0.6) > 0.0 and Land.daylight(0.6) < 1.0)
	var l := _land()
	l.day = 0.72
	var pn := _pair_nests(l)
	var n: int = pn[1]
	_only(l, func(m): return m.nest == n)
	_away(l)
	for i in 30 * 20:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("ночью травоядные спят в гнезде", l.mobs.all(func(m): return (m.pos as Vector3).distance_to(l.nests[n].pos) < 5.0 and m.task == "home"))
	# Ночники: днём спят, ночью выходят на охоту.
	var night := -1
	for i in l.nests.size():
		if LandSpecies.SPECIES[l.nests[i].sp].get("night", false):
			night = i
	c.ok("есть ночная стая", night >= 0)
	for is_night in [false, true]:
		var l2 := _land()
		l2.day = 0.72 if is_night else 0.1
		var ns: Dictionary = l2.nests[night]
		var hunters: Array = l2.mobs.filter(func(m): return m.nest == night)
		var prey: Dictionary = l2.mobs.filter(func(m): return m.kind == "pack" and LandSpecies.SPECIES[m.sp].diet == "plant" and not m.leader)[0]
		prey.pos = l2._near_land(ns.pos, 20.0)
		prey.task = "forage"
		l2.mobs = hunters + [prey]
		_away(l2)
		var out := false
		for i in 30 * 20:
			l2.step(1.0 / 30.0, Vector2.ZERO)
			if hunters.any(func(m): return m.task == "hunt"):
				out = true
		c.ok("ночники охотятся ночью" if is_night else "днём ночники спят", out == is_night)

func test_гиганты(c) -> void:
	var l := _land()
	var gs: Array = l.mobs.filter(func(m): return m.kind == "giant")
	c.eq("на острове три гиганта", gs.size(), Land.GIANTS)
	c.ok("огромные и очень крепкие", gs.all(func(g): return g.size >= 3.5 and g.max_hp > 300.0))
	for i in 30 * 30:
		l.step(1.0 / 30.0, Vector2.ZERO)
	c.ok("держатся своих мест", gs.all(func(g): return (g.pos as Vector3).distance_to(g.home) < Land.GIANT_HOME + 5.0))
	var g: Dictionary = gs[0]
	l.mobs = [g]
	g.hp = 1.0
	_face(l, g.pos, float(g.size) * 0.7 + 0.8)
	l.step(1.0 / 30.0, Vector2.ZERO, true)
	c.ok("повержен — находка и не вернётся", l.events.any(func(x): return x.t == "giant_down") and l.events.any(func(x): return x.t == "find") and l.giants_beaten.has(g.gi))
