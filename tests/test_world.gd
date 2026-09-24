## Воды, течения, стаи, паразиты, логова, свита, умения, арена, песочница, достижения.
extends RefCounted


func _pond(evo: Evolution = null) -> Pond:
	var p := Pond.new(evo if evo else _with_sac(Evolution.create()), 777)
	p.spawning = false
	p.nature = false
	return p

## Толчковый пузырь — чтобы был рывок.
func _with_sac(e: Evolution) -> Evolution:
	e.body.append({"id": "sac", "a": 150, "d": 1.0})
	return e

func _run(p: Pond, seconds: float, input := Vector2.ZERO) -> Array:
	var all: Array = []
	for i in int(seconds / 0.05):
		p.step(0.05, input)
		all.append_array(p.events)
	return all

func _evo_with(parts: Array, dna := 500.0) -> Evolution:
	var e := Evolution.create()
	e.add_dna(dna)
	e.body = []
	for p in parts:
		e.unlocked[p[0]] = p[2] if p.size() > 2 else 1
		e.body.append({"id": p[0], "a": p[1], "d": p[3] if p.size() > 3 else 1.0})
	return _with_sac(e)


func test_воды(c) -> void:
	var p := Pond.new(Evolution.create(), 4242)
	var found := {}
	for y in range(-40, 40):
		for x in range(-40, 40):
			found[p.biome_at(Vector2(x, y) * 400.0)] = true
	c.eq("в океане есть все четыре воды", found.size(), 4)
	var hot := Vector2.INF
	for i in 4000:
		var q := Vector2(i % 80 - 40, i / 80 - 25) * 400.0
		if p.biome_at(q) == "hot":
			hot = q
			break
	var pool: Array = p._species_pool("hot").map(func(x): return x[0])
	c.ok("в горячей воде — горячие жители, а холодных нет", pool.has("puzyrnik") and not pool.has("ledyanka"))

func test_горячая_вода_жжёт(c) -> void:
	var p := Pond.new(Evolution.create(), 4242)
	p.spawning = false
	for i in 6000:
		var q := Vector2(i % 80 - 40, i / 80 - 40) * 400.0
		if p.biome_at(q) == "hot":
			p.player.pos = q
			break
	var hp0 := p.player.hp
	var ev := _run(p, 2.0)
	c.ok("узнал, где он", ev.any(func(e): return e.t == "biome" and e.biome == "hot"))
	c.ok("без термооболочки жжёт", p.player.hp < hp0)
	c.ok("и вода отмечена", p.evo.biomes_seen.has("hot"))

func test_течения(c) -> void:
	var p := Pond.new(Evolution.create(), 4242)
	var strong := 0
	for i in 20000:
		if p.current_at(Vector2(i % 200, i / 200) * 37.0).length() > 30.0:
			strong += 1
	c.ok("течения есть, но не везде (%d из 20000)" % strong, strong > 200 and strong < 12000)

func test_стая(c) -> void:
	var p := _pond(_evo_with([["filter", 0]], 0.0))
	p._spawn_mob(false, Vector2(600, 0))
	var school := p.mobs.filter(func(m): return m.species == p.mobs[0].species)
	if p.mobs[0].school:
		c.ok("стайка появляется сразу, по двое-трое", school.size() >= 2 and school.size() <= 3)
	var q := _pond()
	for i in 6:
		q.spawn("malki", Vector2(600 + i * 70, 0))
	_run(q, 6.0)
	var xs: Array = q.mobs.map(func(m): return m.pos)
	var spread := 0.0
	for a in xs:
		for b in xs:
			spread = maxf(spread, a.distance_to(b))
	c.ok("мальки сбиваются в кучу", spread < 350.0)

func test_паразит(c) -> void:
	var p := _pond()
	var m := p.spawn("piyavka", Vector2(40, 0))
	var ev := _run(p, 1.5)
	c.ok("прицепился", m.host == p.player and ev.any(func(e): return e.t == "parasite"))
	var hp0 := p.player.hp
	_run(p, 1.0)
	c.ok("пьёт здоровье", p.player.hp < hp0)
	p.player.dash_cd = 0.0
	p.step(0.05, Vector2.RIGHT, true)
	c.ok("рывок стряхнул", m.host == null and p.evo.stats.get("shaken", 0) == 1)

func test_невидимка_и_маскировка(c) -> void:
	var p := _pond()
	var ghost := p.spawn("prizrak", Vector2(3000, 0))
	c.ok("призрак — невидимка", ghost.invisible)
	var hid := _pond(_evo_with([["filter", 0], ["camo", 180]], 0.0))
	hid._safe_t = 0.0
	var h := hid.spawn("kusaka", Vector2(130, 0))
	var bare := _pond(_evo_with([["filter", 0]], 0.0))
	bare._safe_t = 0.0
	var h2 := bare.spawn("kusaka", Vector2(130, 0))
	_run(hid, 0.5)
	_run(bare, 0.5)
	c.ok("маскировку хищник не замечает, а без неё — гонится", h.ai_state != "chase" and h2.ai_state == "chase")

func test_логово(c) -> void:
	var p := Pond.new(_evo_with([["jaws", 0]], 600.0), 4242)
	p.spawning = false
	var lair := Vector2.INF
	for y in range(-12, 12):
		for x in range(-12, 12):
			lair = p.lair_at(Vector2i(x, y))
			if lair != Vector2.INF:
				break
		if lair != Vector2.INF:
			break
	c.ok("логова в океане есть", lair != Vector2.INF)
	p.player.pos = lair + Vector2(1400, 0)
	p._lairs_around()
	var boss: Creature = p.mobs.filter(func(m): return Content.SPECIES[m.species].behavior == "lair")[0]
	c.ok("хозяин сидит в логове", boss.pos.distance_to(lair) < 1.0)
	_run(p, 1.0)
	c.ok("пока ты далеко — дома", boss.pos.distance_to(lair) < boss.radius)
	boss.hp = boss.max_hp * 0.55
	var ev := _run(p, 0.2)
	c.ok("на середине — вторая стадия и подмога", ev.any(func(e): return e.t == "boss_phase" and e.phase == 2) and p.mobs.size() >= 3)
	boss.player_hit_t = 0.0
	boss.alive = false
	p._deaths()
	var drops: Array = p.events.filter(func(e): return e.t == "drop").map(func(e): return e.part)
	var reward: String = Content.SPECIES[boss.species].drops[0][0]
	c.ok("награда выпадает всегда", drops.has(reward))
	c.ok("логово засчитано", p.evo.lairs_beaten.has(boss.species))

func test_хозяин_логова_проходим(c) -> void:
	# Бьёт слабее своего размера, устаёт, сам не лечится, пока ты рядом.
	var p := _pond(_evo_with([["jaws", 0, 3], ["spike", 90, 2], ["spike", -90, 2], ["cilia", 180, 3], ["membrane", 135, 2], ["membrane", -135, 2]], 700.0))
	p.player.sync_player(p.evo)
	p.player.hp = p.player.max_hp
	var b := p.spawn("koroleva", Vector2(300, 0))
	b.lair = b.pos
	var t := 0.0
	var deaths := 0
	while t < 90.0 and b.alive:
		var to := b.pos - p.player.pos
		p.step(0.05, to.normalized(), p.player.dash_cd <= 0.0 and to.length() < b.radius + 90.0)
		deaths += p.events.filter(func(e): return e.t == "death").size()
		t += 0.05
	c.ok("в лоб на 6-м размере побеждается за полторы минуты (%d с, гибелей %d)" % [t, deaths], not b.alive and deaths <= 2)
	b = p.spawn("strazh", p.player.pos + Vector2(400, 0))
	b.lair = b.pos
	b.hp = b.max_hp * 0.5
	b.calm_t = 0.0
	p._timers(b, 3.0)
	c.eq("хозяин сам не лечится", b.hp, b.max_hp * 0.5)

func test_свита(c) -> void:
	var e := _evo_with([["jaws", 0], ["cilia", 180]], 300.0)
	e.brood = 2
	var p := Pond.new(e, 99)
	p.spawning = false
	p.nature = false
	p.fill()
	p.mobs.clear()
	c.eq("двое потомков рядом", p.allies.size(), 2)
	_run(p, 3.0, Vector2.RIGHT)
	c.ok("плывут следом", p.allies.all(func(a): return a.pos.distance_to(p.player.pos) < 200.0))
	var hp0: float = p.allies[0].hp
	p.allies[0].pos = p.player.pos + Vector2(p.player.radius, 0)
	_run(p, 1.0)
	c.eq("своих не кусаешь", p.allies[0].hp, hp0)
	var m := p.spawn("zelenka", p.player.pos + Vector2(150, 0))
	p.player.ai_target = m
	_run(p, 10.0)
	c.ok("нападают на твою цель", not m.alive or m.hp < m.max_hp)

func test_умения(c) -> void:
	var ink := _pond(_evo_with([["filter", 0], ["ink", 180]], 100.0))
	ink._safe_t = 0.0
	var h := ink.spawn("kusaka", Vector2(120, 0))
	_run(ink, 0.4)
	c.ok("хищник гонится", h.ai_state == "chase")
	c.ok("чернила", ink.use_ability())
	_run(ink, 0.5)
	c.ok("и теряет из виду", h.ai_state != "chase")
	c.ok("второй раз сразу — нельзя", not ink.use_ability())
	var sh := _pond(_evo_with([["filter", 0], ["shield_gland", 180]], 100.0))
	sh.use_ability()
	sh.player.hp = 100.0
	sh.player.max_hp = 100.0
	sh._hurt(sh.player, 10.0, null, "bite")
	c.ok("щит: удар в пять раз слабее", 100.0 - sh.player.hp < 2.5)
	var pu := _pond(_evo_with([["filter", 0], ["pulse", 180]], 100.0))
	var z := pu.spawn("zelenka", Vector2(40, 0))
	pu.use_ability()
	c.ok("импульс бьёт всех рядом", z.hp < z.max_hp)
	var su := _pond(_evo_with([["filter", 0], ["suction", 180]], 100.0))
	su.food.append({"pos": Vector2(100, 0), "kind": "plant", "value": 1, "r": 7.0, "t": 0.0, "v": 0, "eaten": false})
	su.use_ability()
	_run(su, 0.3)
	c.ok("еда плывёт к тебе", su.food.is_empty() or su.food[0].pos.x < 100.0)

func test_арена(c) -> void:
	var p := _pond(_evo_with([["jaws", 0], ["spike", 90], ["spike", -90]], 400.0))
	p.start_arena()
	var ev := _run(p, 3.0)
	c.ok("первая волна", ev.any(func(e): return e.t == "wave" and e.wave == 1) and not p.mobs.is_empty())
	for m in p.mobs:
		m.pos = p.arena_center + Vector2(5000, 0)
	_run(p, 0.1)
	c.ok("за стенку не уплыть", p.mobs.all(func(m): return m.pos.distance_to(p.arena_center) <= p.arena_radius))
	p.player.hp = 0.1
	p._hurt(p.player, 50.0, null, "bite")
	p._deaths()
	c.ok("гибель на арене — конец боя", p.arena_over and p.events.any(func(e): return e.t == "arena_over"))

func test_пара_даёт_потомка(c) -> void:
	var p := _pond(_evo_with([["jaws", 0], ["cilia", 180]], 300.0))
	p.call_mate()
	p.mate.pos = p.player.pos + Vector2(p.player.radius + p.mate.radius, 0)
	var ev := _run(p, 0.2)
	c.ok("встреча с парой", ev.any(func(e): return e.t == "mated"))
	c.eq("в свите один потомок", p.evo.brood, 1)
	c.eq("и он уже рядом", p.allies.size(), 1)
	p.evo.body.append({"id": "spike", "a": 90, "d": 1.0})
	p.evo.unlocked["spike"] = 1
	p.player.sync_player(p.evo)
	p.resync_allies()
	c.ok("потомок похож на родителя после правки", p.allies[0].parts.any(func(q): return q.id == "spike"))

func test_арена_без_роста(c) -> void:
	var p := _pond(_evo_with([["jaws", 0], ["spike", 90], ["spike", -90]], 400.0))
	p.start_arena()
	var dna := p.evo.dna_total
	var m := p.spawn("zelenka", p.player.pos + Vector2(60, 0))
	m.hp = 0.0
	m.alive = false
	m.player_hit_t = 0.0
	p._deaths()
	c.eq("на арене ДНК не растёт", p.evo.dna_total, dna)
	c.ok("и части не выпадают", p.capsules.is_empty())

func test_песочница(c) -> void:
	var e := Evolution.create_sandbox()
	c.ok("все части открыты на пятом", Content.PARTS.keys().filter(func(k): return Content.obtainable(k)).all(func(k): return e.unlocked.get(k, 0) == 5))
	c.ok("ДНК хватает на всё", e.dna_free() > 10000)
	c.ok("мест много", e.slots() >= 12)

func test_сверхсложность(c) -> void:
	var p := _pond(Evolution.create("insane"))
	p.player.hp = 0.1
	p._hurt(p.player, 50.0, null, "bite")
	p._deaths()
	c.ok("одна жизнь: событие «вид исчез»", p.events.any(func(e): return e.t == "permadeath"))
	var he := Evolution.create("insane")
	he.add_dna(150.0)
	var se := Evolution.create("easy")
	se.add_dna(150.0)
	var hard := Pond.new(he, 5)
	hard._safe_t = 0.0
	var soft := Pond.new(se, 5)
	soft._safe_t = 0.0
	var pool: Array = hard._species_pool()
	var calm: Array = soft._species_pool()
	var share := func(pl: Array) -> float:
		var h := 0.0
		var all := 0.0
		for x in pl:
			all += x[1]
			if Content.SPECIES[x[0]].behavior == "hunter":
				h += x[1]
		return h / all
	c.ok("хищников больше, чем на лёгкой", share.call(pool) > share.call(calm))

func test_родословная_и_достижения(c) -> void:
	var e := Evolution.create()
	e.remember()
	e.generation = 2
	e.color = 4
	e.remember()
	c.eq("два поколения в родословной", e.history.size(), 2)
	c.eq("цвет запомнен", e.history[-1].color, 4)
	e.stats.kills = 1
	var got := e.check_achievements()
	c.ok("достижение «первая победа»", got.any(func(a): return a.id == "first_kill"))
	c.eq("дважды не даётся", e.check_achievements().filter(func(a): return a.id == "first_kill").size(), 0)
	var copy := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.ok("сохраняется всё", copy.achievements.has("first_kill") and copy.history.size() == 2)

func test_океан_не_пустеет(c) -> void:
	# Плывёшь без остановки в одну сторону — худший случай: встречные остаются позади.
	var p := Pond.new(Evolution.create(), 31)
	p.fill()
	p.view_radius = 480.0
	var empty := 0
	var run := 0.0
	var longest := 0.0
	for i in 120 * 20:
		p.step(0.05, Vector2(1, 0.3).normalized())
		var someone := p.mobs.any(func(m): return m.pos.distance_to(p.player.pos) < p.vision() * 2.5)
		run = 0.0 if someone else run + 0.05
		longest = maxf(longest, run)
		if i % 20 == 0 and not someone:
			empty += 1
	c.ok("за две минуты плавания рядом чаще кто-то есть (пусто %d раз из 120)" % empty, empty < 50)
	c.ok("и пусто не дольше нескольких секунд (самое долгое %.1f с)" % longest, longest < 6.0)

func test_круг_водорослей(c) -> void:
	var p := _pond(_evo_with([["filter", 0], ["cilia", 180]], 0.0))
	var col := p.add_colony(Vector2(300, 0))
	var bits := p.food.filter(func(f): return f.get("col", 0) == col.uid)
	c.eq("по краю — кусочки еды", bits.size(), Pond.COLONY_BITS)
	c.ok("кусочки лежат на краю круга", bits.all(func(f): return absf(f.pos.distance_to(col.pos) - col.r) < f.r + 1.0))
	var start: Vector2 = col.pos
	_run(p, 3.0)
	c.ok("круг не стоит на месте", col.pos.distance_to(start) > 5.0)
	var first: Dictionary = p.food.filter(func(f): return f.get("col", 0) == col.uid)[0]
	c.ok("еда едет вместе с кругом", absf(first.pos.distance_to(col.pos) - col.r) < first.r + 1.0)
	# Проплыть сквозь середину круга: сам круг не съедается.
	p.player.pos = col.pos
	p.player.heading = 0.0
	var dna := p.evo.dna_total
	var before := p.food.size()
	p.food = p.food.filter(func(f): return f.get("col", 0) != col.uid)
	_run(p, 0.5)
	c.eq("в середине круга есть нечего", p.evo.dna_total, dna)
	_run(p, Pond.COLONY_REGROW * 2.0 + 0.5)
	c.ok("съеденное отрастает", p.food.filter(func(f): return f.get("col", 0) == col.uid).size() >= 2 and before > 0)

func test_камни_плывут(c) -> void:
	var p := _pond()
	var rock := p.add_rock("stone", Vector2(400, 0))
	var start: Vector2 = rock.pos
	_run(p, 3.0)
	c.ok("камень медленно дрейфует", rock.pos.distance_to(start) > 5.0 and rock.pos.distance_to(start) < 100.0)

func test_мясо_по_размеру(c) -> void:
	var p := _pond()
	var small := p.spawn("kroshka", Vector2(600, 0))
	var big := p.spawn("velikan", Vector2(-600, 0))
	for m in [small, big]:
		m.alive = false
	p._deaths()
	var near_small := p.food.filter(func(f): return f.kind == "meat" and f.pos.distance_to(Vector2(600, 0)) < 200.0)
	var near_big := p.food.filter(func(f): return f.kind == "meat" and f.pos.distance_to(Vector2(-600, 0)) < 400.0)
	c.ok("с крупного — куски крупнее", near_big[0].r > near_small[0].r * 2.5)
	var sum := 0.0
	for f in near_big:
		sum += f.value
	c.ok("и сытнее вместе", sum > near_small[0].value * 5.0)

func test_рывок_только_с_пузырём(c) -> void:
	var p := Pond.new(Evolution.create(), 5)
	p.spawning = false
	c.ok("новая клетка без рывка", not p.player.can_dash and not p.do_dash(p.player))
	p.evo.add_dna(20.0)
	c.ok("пузырь можно поставить", p.evo.place("sac", 150).ok)
	p.player.sync_player(p.evo)
	c.ok("с пузырём рывок есть", p.player.can_dash and p.do_dash(p.player))

func test_существа_растут_с_тобой(c) -> void:
	var small := _pond()
	var a := small.spawn("kusaka", Vector2(300, 0))
	var e := _evo_with([["jaws", 0]], 1500.0)
	var big := _pond(e)
	var b := big.spawn("kusaka", Vector2(300, 0))
	c.ok("на большом размере кусака крупнее", b.size_r > a.size_r * 1.35)
	c.ok("и части у неё сильнее", b.parts[0].lvl > a.parts[0].lvl)
	c.ok("но ты всё равно растёшь быстрее", b.size_r / big.player.size_r < a.size_r / small.player.size_r)

func test_круги_твёрдые(c) -> void:
	var p := _pond()
	var col := p.add_colony(Vector2(200, 0))
	col.drift = Vector2.ZERO
	col.vel = Vector2.ZERO
	_run(p, 3.0, Vector2.RIGHT)
	c.ok("сквозь круг не проплыть", p.player.pos.distance_to(col.pos) >= col.r + p.player.radius - 1.0)
	var m := p.spawn("zelenka", Vector2(40, 0))
	m.ai_goal = Vector2(600, 0)
	m.ai_state = "wander"
	var obst := p.add_colony(Vector2(260, 0))
	obst.drift = Vector2.ZERO
	obst.pos = m.pos + Vector2(obst.r + m.radius + 30.0, 5.0)
	var dir := p.avoid(m, Vector2.RIGHT)
	c.ok("существа огибают круг", absf(dir.y) > 0.2)

func test_стрелок(c) -> void:
	var p := _pond(_evo_with([["filter", 0], ["cilia", 180]], 150.0))
	p._safe_t = 0.0
	var s := p.spawn("plevun", p.player.pos + Vector2(260, 0))
	var ev := _run(p, 4.0)
	c.ok("плевун стреляет издалека", ev.any(func(e): return e.t == "shot" and not e.by_player))
	c.ok("и попадает", p.player.hp < p.player.max_hp or p.player.poison_t > 0.0)
	c.ok("близко не подплывает", s.pos.distance_to(p.player.pos) > (s.radius + p.player.radius) * 1.5)
	var q := _pond(_evo_with([["filter", 0], ["needle", 0, 1], ["cilia", 180]], 300.0))
	q.player.heading = 0.0
	var z := q.spawn("zelenka", q.player.pos + Vector2(200, 0))
	z.ai_t = 99.0
	var ev2 := _run(q, 1.0)
	c.ok("твой игломёт стреляет сам", ev2.any(func(e): return e.t == "shot" and e.by_player))
	c.ok("и ранит", z.hp < z.max_hp)
	q.add_rock("boulder", q.player.pos + Vector2(100, 0))
	var hp: float = z.hp
	_run(q, 2.0)
	c.ok("за камнем не достать", z.hp >= hp - 0.01)

func test_делитель(c) -> void:
	var p := _pond()
	var d := p.spawn("delitel", Vector2(400, 0))
	var n := p.mobs.size()
	p._hurt(d, d.max_hp * 0.6, p.player, "bite")
	var ev := _run(p, 0.1)
	c.ok("ранен до половины — распался", ev.any(func(e): return e.t == "split") and p.mobs.size() == n + 1)
	var kids := p.mobs.filter(func(m): return m.species == "delitel")
	c.ok("дети мельче и второй раз не делятся", kids.all(func(k): return k.size_r < d.size_r and k.split_done))

func test_обманка(c) -> void:
	var p := _pond(_evo_with([["filter", 0], ["cilia", 180]], 100.0))
	var m := p.spawn("obmanka", p.player.pos + Vector2(300, 0))
	_run(p, 1.0)
	c.ok("ждёт на месте", m.pos.distance_to(p.player.pos + Vector2(300, 0)) < 20.0 and m.revealed_t <= 0.0)
	p.player.pos = m.pos - Vector2(m.radius * 2.0 + 20.0, 0)
	var ev := _run(p, 0.5)
	c.ok("подплыл — кусает", ev.any(func(e): return e.t == "ambush") and m.revealed_t > 0.0)

func test_бродячий_гигант(c) -> void:
	var e := _evo_with([["jaws", 0]], 900.0)
	var p := _pond(e)
	p.spawning = true
	p._roam_t = 0.0
	var ev := _run(p, 1.0)
	c.ok("приплыл гигант", ev.any(func(x): return x.t == "roamer"))
	var g: Creature = p.mobs.filter(func(m): return m.behavior() == "roamer")[0]
	c.ok("огромный", g.size_r > p.player.size_r * 2.0)
	var start := g.pos
	_run(p, 3.0)
	c.ok("плывёт своим путём", g.pos.distance_to(start) > 30.0)
	g.alive = false
	g.player_hit_t = 0.0
	p._deaths()
	var reward: String = Content.SPECIES[g.species].drops[0][0]
	c.ok("награда выпадает всегда", p.events.any(func(x): return x.t == "drop" and x.part == reward))

func test_прилипала(c) -> void:
	var p := _pond(_evo_with([["filter", 0], ["remora", 180], ["cilia", 90]], 300.0))
	var host := p.spawn("gigant", p.player.pos + Vector2(-p.player.radius - 5.0, 0))
	host.ai_t = 99.0
	p.player.heading = 0.0
	host.pos = p.player.pos + Vector2(-(p.player.radius + host.radius), 0)
	var dna := p.evo.dna_total
	var ev := _run(p, 2.0)
	c.ok("прилип к крупному", ev.any(func(x): return x.t == "remora_on") and p.player.rider_host == host)
	c.ok("ест с него крохи", p.evo.dna_total > dna)
	host.pos += Vector2(0, 200)
	_run(p, 0.1)
	c.ok("едет вместе с ним", p.player.pos.distance_to(host.pos) < host.radius + p.player.radius + 5.0)
	var ev2 := _run(p, 1.0, Vector2.RIGHT)
	c.ok("ход прочь — отцепился", ev2.any(func(x): return x.t == "remora_off") and p.player.rider_host == null)

func test_светлячок(c) -> void:
	var a := _pond()
	var b := _pond(_evo_with([["filter", 0], ["firefly", 0, 1, 0.0]], 100.0))
	a.view_radius = 400.0
	b.view_radius = 400.0
	c.ok("светлячок раздвигает туман", b.vision() > a.vision() * 1.25)
