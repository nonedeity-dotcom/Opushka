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
	c.ok("есть все трое: бродяги, стаи, отшельники", ["wander", "pack", "hermit"].all(func(k): return l.mobs.any(func(m): return m.kind == k)))

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
	c.ok("стащил яйцо — +ДНК", l.dna >= dna + 5.0 and nest.eggs == Land.EGGS - 1 and l.events.any(func(e): return e.t == "egg"))
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
	c.eq("много ДНК", l.dna - dna, 25.0)
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
