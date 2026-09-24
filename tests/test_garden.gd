## Огород, курятник и звери.
extends RefCounted


## Деревня с грядкой прямо под ногами (клетка ниже старта всегда свободна).
func _with_bed(bag: Dictionary) -> Village:
	var v := Village.create(42)
	v.bag = bag.duplicate()
	v.bag.bed = 1
	v.face(Vector2.DOWN)
	v.place("bed")
	return v

func test_грядка_от_семени_до_урожая(c) -> void:
	var v := _with_bed({"carrot_seed": 2, "can": 1})
	var bed := v.target()
	c.eq("грядка стоит", v.built.get(Village.key(bed), ""), "bed")
	c.ok("по грядке можно ходить", not v.blocks(bed))
	c.eq("кнопка — посадить", v.action_label(), "Посадить")
	var planted := v.act()
	c.eq("посажена морковь", v.bed(bed).crop, "carrot")
	c.eq("семя потрачено", v.bag.carrot_seed, 1)
	c.eq("звук посадки", planted.sound, "plant")
	c.eq("теперь — полить", v.action_label(), "Полить")
	c.eq("пустая лейка — нельзя", v.act().sound, "nope")
	v.water = Content.CAN_SIZE
	var poured := v.act()
	c.eq("полито", poured.sound, "pour")
	c.eq("вода убыла", v.water, Content.CAN_SIZE - 1)
	c.eq("пока растёт — кнопка «Растёт»", v.action_label(), "Растёт")
	c.eq("только что посажена — росток", v.bed(bed).stage, 0)
	v.time += 180
	c.eq("полпути — подросла", v.bed(bed).stage, 2)
	v.time += 200
	c.ok("выросла", v.bed(bed).ripe)
	c.eq("кнопка — собрать", v.action_label(), "Собрать урожай")
	var got := v.act()
	c.eq("урожай: морковь и семена", [v.bag.get("carrot", 0), v.bag.carrot_seed], [3, 3])
	c.eq("звук урожая", got.sound, "harvest")
	c.eq("грядка снова пустая", v.bed(bed).crop, "")
	c.ok("задачи огорода отмечены", ["bed", "plant", "water", "harvest"].all(func(g): return v.goals_done.has(g)))

func test_без_полива_не_растёт(c) -> void:
	var v := _with_bed({"sunflower_seed": 1, "can": 1})
	var bed := v.target()
	v.act()
	v.time += 3000
	c.eq("сухая грядка стоит", v.bed(bed).grown, 0.0)
	v.water = 1
	v.act()
	v.time += 5000
	c.eq("полив действует полдня, не больше", v.bed(bed).grown, float(Content.WET_MINUTES))
	c.ok("подсолнуху этого хватило", v.bed(bed).ripe)

func test_растёт_во_сне(c) -> void:
	var v := _with_bed({"carrot_seed": 1, "can": 1, "campfire": 1})
	var bed := v.target()
	v.act()
	v.water = 1
	v.time = 20 * 60
	v.act()
	v.face(Vector2.RIGHT)
	v.place("campfire")
	v.time = 22 * 60
	var slept := v.act()
	c.ok("поспал", slept.get("slept", false))
	c.ok("за ночь морковь выросла", v.bed(bed).ripe)

func test_вода_в_лейку(c) -> void:
	var v := Village.create(42)
	var w := v.world()
	# Встать слева от любой воды, у которой слева свободно.
	var stand := Vector2i(-1, -1)
	for i in WorldGen.SIZE * WorldGen.SIZE:
		var cell := Vector2i(i % WorldGen.SIZE, i / WorldGen.SIZE)
		if w.ground[i] == WorldGen.Ground.WATER and not v.blocks(cell + Vector2i(-1, 0)):
			stand = cell + Vector2i(-1, 0)
			break
	v.pos = Vector2(stand) + Vector2(0.5, 0.5)
	v.face(Vector2.RIGHT)
	c.eq("без лейки — просто вода", v.action_label(), "Вода")
	v.bag.can = 1
	c.eq("с пустой лейкой — набрать", v.action_label(), "Набрать воды")
	v.act()
	c.eq("лейка полная", v.water, Content.CAN_SIZE)
	c.eq("полную — не набрать", v.action_label(), "Вода")

func test_курятник(c) -> void:
	var v := Village.create(42)
	v.bag = {"coop": 1, "sunflower_seed": 3}
	v.face(Vector2.DOWN)
	var put := v.place("coop")
	c.ok("курятник стоит и сказано про кур", put.message.contains("курицы"))
	c.eq("кнопка — насыпать", v.action_label(), "Насыпать семечек")
	v.act()
	c.eq("семечки ушли", v.bag.sunflower_seed, 3 - Content.COOP_FEED)
	c.eq("второй раз за день — куры сыты", v.act().message, "Куры сыты. Яйца будут завтра утром")
	c.eq("в тот же день яиц нет", v.coop_eggs(v.target()), 0)
	v.time += Content.DAY
	c.eq("наутро — яйца", v.coop_eggs(v.target()), Content.COOP_EGGS)
	c.eq("кнопка — собрать", v.action_label(), "Собрать яйца")
	v.act()
	c.eq("яйца в сумке", v.bag.egg, Content.COOP_EGGS)
	c.eq("курятник пуст", v.coop_eggs(v.target()), 0)
	c.ok("задача «яйца»", v.goals_done.has("eggs"))
	v.time += Content.DAY * 3
	c.eq("не кормили — не несутся", v.coop_eggs(v.target()), 0)
	c.eq("еда по кнопке — яйцо, а не семечки", v.snack(), "egg")

func test_огород_в_сохранении(c) -> void:
	var v := _with_bed({"carrot_seed": 1, "can": 1, "coop": 1})
	v.act()
	v.water = 3
	v.act()
	v.pets = 2
	v.face(Vector2.RIGHT)
	v.place("coop")
	var copy := Village.from_dict(JSON.parse_string(JSON.stringify(v.to_dict())))
	c.eq("грядки, лейка, куры и зайцы сохраняются", copy.to_dict(), v.to_dict())
	var odd := Village.from_dict({"seed": 3, "beds": {"9:9": {"crop": "carrot"}}, "coops": {"1:1": 5}})
	c.eq("грядка без постройки выброшена", [odd.beds, odd.coops], [{}, {}])

func test_дикие_растения(c) -> void:
	for seed in [1, 42, 2026]:
		var w := WorldGen.make(seed)
		var n := Array(w.nature)
		c.ok("зерно %d: есть дикая морковь и подсолнухи" % seed, n.count("wildcarrot") >= 3 and n.count("sunflower") >= 3)
	var v := Village.create(42)
	var start: Vector2i = v.world().start
	c.eq("у поляны — дикая морковь", v.cell(start + Vector2i(5, 2)).nature, "wildcarrot")


# --- звери ----------------------------------------------------------------------------

func _run(a: Animals, v: Village, seconds: float) -> void:
	for i in int(seconds / 0.05):
		a.step(0.05, v)

func _hares(a: Animals) -> Array:
	return a.list.filter(func(x): return x.kind == "hare")

## Заяц и место в двух клетках от него, откуда до него ничто не мешает дойти.
func _hare_and_spot(a: Animals, v: Village) -> Array:
	for h in _hares(a):
		for d in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			var ok := true
			for k in [0.5, 1.0, 1.5, 2.0]:
				ok = ok and not v.blocks(v.tile_of(h.pos + d.normalized() * k))
			if ok:
				return [h, h.pos + d]
	return []

func test_звери_живут(c) -> void:
	var v := Village.create(42)
	var a := Animals.new(v)
	c.ok("зайцы есть", _hares(a).size() >= 4)
	c.eq("птицы есть", a.list.filter(func(x): return x.kind == "bird").size(), Animals.BIRDS)
	var before: Array = _hares(a).map(func(h): return h.pos)
	_run(a, v, 8.0)
	var after: Array = _hares(a).map(func(h): return h.pos)
	c.ok("зайцы бродят", before != after)
	var stuck := _hares(a).filter(func(h): return v.blocks(v.tile_of(h.pos)))
	c.eq("и не залезают в деревья", stuck.size(), 0)

func test_заяц_пугается(c) -> void:
	var v := Village.create(42)
	var a := Animals.new(v)
	var pair := _hare_and_spot(a, v)
	c.ok("нашёлся заяц", not pair.is_empty())
	var h: Animals.Animal = pair[0]
	# Подбегаем: прошлый кадр был за клетку отсюда.
	v.pos = pair[1]
	a._last_player = v.pos + (v.pos - h.pos).normalized()
	var d0 := h.pos.distance_to(v.pos)
	a.step(0.05, v)
	c.eq("побежал к нему — удирает", h.state, "flee")
	_run(a, v, 1.0)
	c.ok("и убежал дальше", h.pos.distance_to(v.pos) > d0 + 0.3)

func test_заяц_подходит_и_приручается(c) -> void:
	var v := Village.create(42)
	var a := Animals.new(v)
	v.animals = a
	var pair := _hare_and_spot(a, v)
	var h: Animals.Animal = pair[0]
	v.pos = pair[1]
	a._last_player = v.pos
	c.eq("без морковки кнопка — просто «Заяц»", v._animal_label(h), "Заяц")
	v.bag.carrot = 1
	_run(a, v, 6.0)
	c.ok("стоишь тихо с морковкой — подошёл", h.pos.distance_to(v.pos) <= 1.1)
	c.eq("кнопка — покормить", v.action_label(), "Покормить")
	# Подойти могли и соседние зайцы — кормим того, кто ближе.
	h = v.animal_near()
	var out := v.act()
	c.ok("приручён", h.tame and v.pets == 1 and v.bag.carrot == 0)
	c.eq("звук", out.sound, "pet")
	c.ok("сердечки над зайцем", out.has("hearts"))
	c.ok("задача «заяц»", v.goals_done.has("hare"))
	c.eq("ручного — погладить", v.action_label(), "Погладить")
	v.pos += Vector2(0, 4)
	a._last_player = v.pos
	_run(a, v, 3.0)
	c.ok("ручной ходит следом", h.pos.distance_to(v.pos) < 2.2)
	var again := Animals.new(Village.from_dict(JSON.parse_string(JSON.stringify(v.to_dict()))))
	c.eq("после загрузки ручной заяц снова рядом", again.list.filter(func(x): return x.tame).size(), 1)

func test_куры_у_курятника(c) -> void:
	var v := Village.create(42)
	var a := Animals.new(v)
	v.animals = a
	v.bag = {"coop": 1}
	v.face(Vector2.DOWN)
	v.place("coop")
	var hens := a.list.filter(func(x): return x.kind == "chicken")
	c.eq("две курицы", hens.size(), 2)
	_run(a, v, 20.0)
	c.ok("бродят у курятника", hens.all(func(x): return x.pos.distance_to(x.home) < 2.6))
	v.pick_up()
	c.eq("курятник убрали — куры ушли", a.list.filter(func(x): return x.kind == "chicken").size(), 0)
