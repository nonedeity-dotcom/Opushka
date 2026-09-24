## Океан: движение, еда, драка, выпадение частей, поведение клеток.
extends RefCounted


## Океан без самонаполнения: в нём только то, что поставили руками.
func _pond(evo: Evolution = null) -> Pond:
	var p := Pond.new(evo if evo else Evolution.create(), 12345)
	p.spawning = false
	return p

func _run(p: Pond, seconds: float, input := Vector2.ZERO) -> Array:
	var all: Array = []
	for i in int(seconds / 0.05):
		p.step(0.05, input)
		all.append_array(p.events)
	return all

func _plant(p: Pond, at: Vector2) -> void:
	p.food.append({"pos": at, "kind": "plant", "value": 1, "r": 7.0, "t": 0.0, "v": 0, "eaten": false})

func _meat(p: Pond, at: Vector2) -> void:
	p.food.append({"pos": at, "kind": "meat", "value": 1, "r": 5.0, "t": 0.0, "v": 0, "eaten": false})

func _evo_with(parts: Array, dna := 500.0) -> Evolution:
	var e := Evolution.create()
	e.add_dna(dna)
	e.body = []
	for p in parts:
		e.unlocked[p[0]] = p[2] if p.size() > 2 else 1
		e.body.append({"id": p[0], "a": p[1]})
	return e


func test_плывёт(c) -> void:
	var p := _pond()
	_run(p, 1.0, Vector2.RIGHT)
	c.ok("поплыл вправо", p.player.pos.x > 40.0)
	c.ok("и повернулся носом по ходу", absf(p.player.heading) < 0.2)
	var slow := _pond()
	var fast := _pond(_evo_with([["filter", 0], ["flagellum", 180]]))
	_run(slow, 1.0, Vector2.RIGHT)
	_run(fast, 1.0, Vector2.RIGHT)
	c.ok("со жгутиком быстрее", fast.player.pos.x > slow.player.pos.x + 15.0)

func test_травоядный_ест_водоросли(c) -> void:
	var p := _pond()
	_plant(p, Vector2(30, 0))
	_meat(p, Vector2(0, 60))
	var ev := _run(p, 1.0, Vector2.RIGHT)
	c.ok("съел водоросль", ev.any(func(e): return e.t == "eat" and e.kind == "plant"))
	c.ok("ДНК прибавилась", p.evo.dna_total >= 1.0)
	_run(p, 1.5, Vector2(-0.5, 1).normalized())
	c.ok("мясо травоядному не еда", p.food.any(func(f): return f.kind == "meat"))

func test_хищник_ест_мясо(c) -> void:
	var p := _pond(_evo_with([["jaws", 0], ["cilia", 180]]))
	_plant(p, Vector2(30, 0))
	_meat(p, Vector2(60, 0))
	var ev := _run(p, 1.2, Vector2.RIGHT)
	c.ok("мясо съедено", ev.any(func(e): return e.t == "eat" and e.kind == "meat"))
	c.ok("водоросль хищнику не еда", p.food.any(func(f): return f.kind == "plant"))
	c.eq("за мясо — 3 ДНК", p.evo.dna_total, 500.0 + Pond.MEAT_DNA)

func test_рот_сзади_не_ест_спереди(c) -> void:
	var p := _pond(_evo_with([["filter", 180], ["cilia", 0]]))
	_plant(p, Vector2(20, 0))
	p.player.heading = 0.0
	_run(p, 0.3)
	c.eq("перед носом, а рот на хвосте — не съел", p.food.size(), 1)

func test_укус_и_победа(c) -> void:
	var p := _pond(_evo_with([["jaws", 0], ["cilia", 180]]))
	var prey := p.spawn("zelenka", Vector2(40, 0))
	prey.heading = PI
	var ev := _run(p, 4.0, Vector2.RIGHT)
	c.ok("кусал", ev.any(func(e): return e.t == "hit" and e.kind == "bite" and e.from_player))
	c.ok("победил", ev.any(func(e): return e.t == "kill" and e.by_player))
	c.ok("осталось мясо", p.food.any(func(f): return f.kind == "meat") or ev.any(func(e): return e.t == "eat" and e.kind == "meat"))
	c.eq("счёт побед", p.evo.kills_by.get("zelenka", 0), 1)

func test_рывок_таранит(c) -> void:
	var p := _pond()
	var m := p.spawn("kroshka", Vector2(50, 0))
	p.player.heading = 0.0
	p.step(0.05, Vector2.RIGHT, true)
	var ev := _run(p, 0.5, Vector2.RIGHT)
	c.ok("таран бьёт", ev.any(func(e): return e.t == "hit" and e.kind == "ram"))
	c.ok("второй раз сразу — нельзя", not p.do_dash(p.player))

func test_шипы_колют_обидчика(c) -> void:
	var p := _pond()
	var k := p.spawn("kolyuchka", Vector2(40, 0))
	k.heading = PI  # шип смотрит на тебя
	k.ai_t = 99.0
	var hp0 := p.player.hp
	_run(p, 0.6, Vector2.RIGHT)
	c.ok("наткнулся на шип — больно", p.player.hp < hp0)
	var side := _pond()
	var k2 := side.spawn("kolyuchka", Vector2(40, 0))
	k2.heading = -PI / 2  # к тебе боком
	k2.ai_t = 99.0
	var hp1 := side.player.hp
	_run(side, 0.6, Vector2.RIGHT)
	c.eq("сбоку — не колет", side.player.hp, hp1)

func test_панцирь_держит_удар(c) -> void:
	var bare := _pond(_evo_with([["filter", 0]], 0.0))
	var shelled := _pond(_evo_with([["filter", 0], ["shell", 0]], 40.0))
	for p in [bare, shelled]:
		var m: Creature = p.spawn("kusaka", Vector2(30, 0))
		m.heading = PI
		m.ai_t = 99.0
		p.player.heading = 0.0
		p.player.hp = 100.0
		p.player.max_hp = 100.0
		m.desire = Vector2.LEFT
		_run(p, 1.2)
	c.ok("с панцирем спереди урона меньше", 100.0 - shelled.player.hp < (100.0 - bare.player.hp) * 0.7)

func test_яд(c) -> void:
	var p := _pond()
	var y := p.spawn("yadovik", Vector2(55, 0))
	y.heading = PI
	y.ai_t = 99.0
	var hp0 := p.player.hp
	var ev := _run(p, 0.8, Vector2.RIGHT)
	c.ok("отравлен", ev.any(func(e): return e.t == "poison" and e.to_player))
	_run(p, 2.0, Vector2.LEFT)
	c.ok("яд ест и после касания", p.player.hp < hp0 - 1.0)

func test_шанс_выпадения(c) -> void:
	var drops := 0
	var tries := 400
	var p := _pond()
	for i in tries:
		var m := p.spawn("kolyuchka", Vector2(5000, 0))
		m.player_hit_t = 0.0
		m.alive = false
		p._deaths()
		drops += p.events.filter(func(e): return e.t == "drop").size()
		p.events.clear()
	var share := float(drops) / tries
	c.ok("шип выпадает примерно в 30%% случаев (вышло %.0f%%)" % (share * 100.0), share > 0.22 and share < 0.38)
	var q := _pond()
	var m := q.spawn("kolyuchka", Vector2(5000, 0))
	m.alive = false
	q._deaths()
	c.ok("чужая победа — без находок", not q.events.any(func(e): return e.t == "drop") and q.capsules.is_empty())

func test_подобрать_часть(c) -> void:
	var p := _pond()
	p.capsules.append({"pos": Vector2(30, 0), "part": "spike", "t": 0.0})
	var ev := _run(p, 0.5, Vector2.RIGHT)
	c.ok("подобрал", ev.any(func(e): return e.t == "pickup" and e.part == "spike" and e.new))
	c.ok("шип открыт", p.evo.unlocked.has("spike"))
	c.ok("задача «новая часть»", p.evo.goals_done.has("part"))

func test_рост_на_ходу(c) -> void:
	var e := Evolution.create()
	e.add_dna(Content.LEVELS[1].dna - 0.5)
	var p := _pond(e)
	var r0 := p.player.radius
	_plant(p, Vector2(30, 0))
	var ev := _run(p, 1.0, Vector2.RIGHT)
	c.ok("вырос", ev.any(func(x): return x.t == "levelup" and x.level == 2))
	c.ok("клетка стала больше", p.player.radius > r0)

func test_гибель(c) -> void:
	var p := _pond()
	var at := p.player.pos
	p.player.hp = 0.1
	p._hurt(p.player, 5.0, null, "bite")
	p._deaths()
	c.ok("событие гибели", p.events.any(func(e): return e.t == "death"))
	c.ok("новая клетка жива и цела", p.player.alive and p.player.hp == p.player.max_hp)
	c.ok("появилась поодаль", p.player.pos.distance_to(at) > 500.0)
	c.eq("счёт гибелей", p.evo.stats.deaths, 1)

func test_травоядные_убегают(c) -> void:
	var p := _pond(_evo_with([["filter", 0]], 30.0))
	var g := p.spawn("zelenka", Vector2(90, 0))
	_run(p, 0.3)
	c.eq("заметил тебя и бежит", g.ai_state, "flee")
	_run(p, 0.7)
	c.ok("и отплыл", g.pos.x > 110.0)

func test_хищник_охотится(c) -> void:
	var p := _pond()
	p._safe_t = 0.0
	var h := p.spawn("kusaka", Vector2(120, 0))
	_run(p, 0.5)
	c.eq("гонится за тобой (ты меньше)", h.ai_state, "chase")
	c.ok("и приблизился", h.pos.x < 110.0)
	var big := _pond(_evo_with([["filter", 0]], 400.0))
	var h2 := big.spawn("kusaka", Vector2(150, 0))
	_run(big, 0.5)
	c.ok("ты сильно больше — не гонится", h2.ai_state != "chase")

func test_свои_не_дерутся(c) -> void:
	var p := _pond()
	var a := p.spawn("kolyuchka", Vector2(400, 0))
	var b := p.spawn("kolyuchka", Vector2(420, 0))
	a.heading = 0.0
	b.heading = PI
	_run(p, 1.0)
	c.ok("две колючки не колют друг друга", a.hp == a.max_hp and b.hp == b.max_hp)

func test_океан_наполняется(c) -> void:
	var p := Pond.new(Evolution.create(), 777)
	p.fill()
	_run(p, 3.0)
	c.ok("водоросли есть", p.food.filter(func(f): return f.kind == "plant").size() > 60)
	c.ok("клетки есть", p.mobs.size() >= 5)
	c.ok("в начале хищников нет", not p.mobs.any(func(m): return p._hunts(m)))
	var lvl := p.evo.level()
	c.ok("только виды своего размера", p.mobs.all(func(m): return lvl >= Content.SPECIES[m.species].levels[0] and lvl <= Content.SPECIES[m.species].levels[1]))
