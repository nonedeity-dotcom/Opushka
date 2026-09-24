## Твой вид: рост, ДНК, редактор тела, находки, задачи, сохранение.
extends RefCounted


func test_старт(c) -> void:
	var e := Evolution.create()
	c.eq("первый размер", e.level(), 1)
	c.eq("фильтр и реснички", e.body.map(func(p): return p.id), ["filter", "cilia"])
	c.eq("травоядный", e.diet(), "plant")
	c.eq("свободной ДНК — остаток стартовой", e.dna_free(), Content.START_DNA - _cost("filter") - _cost("cilia"))
	c.eq("мест на теле", e.slots(), 4)

func _cost(id: String) -> int:
	return Content.PARTS[id].cost

func test_рост(c) -> void:
	var e := Evolution.create()
	var two: float = Content.LEVELS[1].dna
	var three: float = Content.LEVELS[2].dna
	c.ok("чуть меньше порога — ещё не вырос", not e.add_dna(two - 1))
	c.ok("порог — вырос", e.add_dna(1))
	c.eq("второй размер", e.level(), 2)
	c.ok("и клетка больше", e.radius() > Content.radius_for(1))
	c.eq("в начале размера полоска пустая", e.growth(), 0.0)
	e.add_dna((three - two) / 2.0)
	c.eq("полпути до третьего", e.growth(), 0.5)
	e.add_dna(10000)
	c.eq("выше десятого не растёт", e.level(), Content.LEVELS.size())
	c.eq("полоска полная", e.growth(), 1.0)

func test_редактор(c) -> void:
	var e := Evolution.create()
	c.eq("неоткрытую часть не поставить", e.place("spike", 90).ok, false)
	e.unlocked.spike = 1
	c.ok("не хватает ДНК", e.place("spike", 90).message.contains("Не хватает ДНК"))
	var dna: float = Content.LEVELS[1].dna
	e.add_dna(dna)
	var base := int(dna) + Content.START_DNA - _cost("filter") - _cost("cilia")
	var put := e.place("spike", 90)
	c.ok("шип поставлен", put.ok and e.body.size() == 3)
	c.eq("ДНК потрачена", e.dna_free(), base - _cost("spike"))
	c.ok("рядом тесно", e.can_place("spike", 105).reason.begins_with("Тесно"))
	c.ok("второй размер — пять мест", e.place("spike", -90).ok)
	e.body.append({"id": "spike", "a": 180, "d": 1.0})
	c.ok("шестой части места нет", e.can_place("spike", 45).reason.begins_with("Нет места"))
	e.body.pop_back()
	var off := e.remove(3)
	c.ok("убрал — ДНК вернулась", off.ok and e.dna_free() == base - _cost("spike"))
	e.remove(2)
	c.eq("углы по сетке", e.place("spike", 97).ok and e.body[-1].a == 90, true)

func test_один_рот(c) -> void:
	var e := Evolution.create()
	e.unlocked.jaws = 1
	e.add_dna(40)
	var put := e.place("jaws", 0)
	c.ok("челюсти вместо фильтра", put.ok)
	c.eq("рот один", e.body.filter(func(p): return Content.is_mouth(p.id)).size(), 1)
	c.eq("теперь хищник", e.diet(), "meat")
	c.ok("задача «кем быть»", e.check_goals().any(func(g): return g.id == "diet"))

func test_зеркало(c) -> void:
	var e := Evolution.create()
	e.unlocked.spike = 1
	e.add_dna(100)
	var put := e.place("spike", 60, true)
	c.ok("поставлено два", put.ok and e.body.filter(func(p): return p.id == "spike").size() == 2)
	c.eq("второй — зеркально", e.body[-1].a, -60)

func test_находки(c) -> void:
	var e := Evolution.create()
	var first := e.collect("spike")
	c.ok("новая часть", first.new and e.unlocked.spike == 1)
	var again := e.collect("spike")
	c.ok("первая копия — сразу второй уровень", not again.new and again.up and e.unlocked.spike == 2)
	var shard := e.collect("spike")
	c.ok("дальше копии копятся: 1 из 2", not shard.up and shard.have == 1 and shard.need == 2 and e.unlocked.spike == 2)
	c.ok("вторая — третий уровень", e.collect("spike").up and e.unlocked.spike == 3)
	var copies := 1  # та, что открыла часть
	copies += 1 + 2
	for i in 50:
		if e.unlocked.spike >= Content.PART_MAX_LEVEL:
			break
		e.collect("spike")
		copies += 1
	c.eq("до пятого — десять копий после первой", copies - 1, 1 + 2 + 3 + 4)
	var bonus := e.collect("spike")
	c.eq("на пятом — ДНК вместо уровня", bonus.dna, 10)
	c.ok("сила растёт с уровнем", Content.power(3) > Content.power(1))

func test_задачи(c) -> void:
	var e := Evolution.create()
	c.eq("первая — поесть", e.current_goal().id, "eat")
	e.stats.plants = 10
	c.eq("съел — отмечено", e.check_goals().map(func(g): return g.id), ["eat"])
	c.eq("второй раз не отмечается", e.check_goals(), [])

func test_сохранение(c) -> void:
	var e := Evolution.create()
	e.add_dna(123)
	e.unlocked.spike = 3
	e.shards.spike = 2
	e.place("spike", 90, true)
	e.color = 3
	e.name = "Колобок"
	e.seen.kusaka = true
	e.kills_by.kusaka = 2
	e.stats.kills = 2
	var copy := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("туда-обратно без потерь", copy.to_dict(), e.to_dict())
	c.eq("мусор — ничего", Evolution.from_dict("x"), null)
	# Старое сохранение (рывок тогда был у всех): толчковый пузырь ставится сам.
	var old := Evolution.from_dict({"dna_total": 60, "unlocked": {"filter": 1, "cilia": 1}, "body": [{"id": "filter", "a": 0}, {"id": "cilia", "a": 180}]})
	c.ok("в старом сохранении рывок не пропал", old.body.any(func(p): return p.id == "sac"))
	c.ok("а новая клетка начинает без него", not Evolution.create().body.any(func(p): return p.id == "sac"))
	var odd := Evolution.from_dict({"dna_total": 0, "unlocked": {"rocket": 1, "spike": 9}, "body": [{"id": "rocket", "a": 0}, {"id": "spike", "a": 90}, {"id": "spike", "a": -90}, {"id": "spike", "a": 180}]})
	c.eq("чужое выброшено, уровень в пределах", odd.unlocked, {"filter": 1, "cilia": 1, "sac": 1, "spike": 5})
	c.eq("слишком дорогое тело — стартовое", odd.body, Content.START_PARTS)

func test_справочник(c) -> void:
	for sid in Content.SPECIES:
		var def: Dictionary = Content.SPECIES[sid]
		var has: Array = def.parts.map(func(p): return p[0])
		c.ok("%s роняет только своё" % def.name, def.drops.all(func(d): return has.has(d[0])))
		c.ok("%s: части настоящие" % def.name, has.all(func(p): return Content.PARTS.has(p)))
	var found := {}
	for sid in Content.SPECIES:
		for d in Content.SPECIES[sid].drops:
			found[d[0]] = true
	var from_rocks := {}
	for rid in Content.ROCKS:
		for d in Content.ROCKS[rid].drops:
			from_rocks[d[0]] = true
	var missing := Content.PARTS.keys().filter(func(p): return Content.obtainable(p) and not found.has(p) and not from_rocks.has(p) and not Content.START_UNLOCKED.has(p))
	c.eq("каждую добываемую часть можно где-то добыть", missing, [])
	c.ok("каменные части — только из камней", from_rocks.keys().all(func(p): return Content.PARTS[p].get("source", "") == "rock" and not found.has(p)))
	c.ok("части «не выбить» не выпадают ни откуда", Content.PARTS.keys().filter(func(p): return not Content.obtainable(p)).all(func(p): return not found.has(p) and not from_rocks.has(p)))
	c.ok("у кого-то такие части есть", Content.SPECIES.values().any(func(d): return d.parts.any(func(p): return not Content.obtainable(p[0]))))

func test_неотбиваемые(c) -> void:
	var e := Evolution.create()
	e.unlocked.tentacle = 1
	e.add_dna(500)
	c.ok("щупальце не поставить, даже если как-то открыто", not e.can_place("tentacle", 90).ok)
	var odd := Evolution.from_dict({"dna_total": 10, "unlocked": {"horn": 3}})
	c.ok("из сохранения не протащить", not odd.unlocked.has("horn"))

func test_сложность(c) -> void:
	var e := Evolution.create("hard")
	e.add_dna(Content.LEVELS[2].dna + 40)
	var lost := e.death_loss()
	c.ok("на тяжёлой гибель отнимает часть роста", lost > 0.0 and e.level() == 3)
	var easy := Evolution.create("easy")
	easy.add_dna(100)
	c.eq("на лёгкой — ничего", easy.death_loss(), 0.0)
	var copy := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("сложность сохраняется", copy.difficulty, "hard")

func test_части_внутри(c) -> void:
	var e := Evolution.create()
	e.unlocked.eye = 1
	e.add_dna(200)
	var mid := e.place("eye", 45, false, 0.05)
	c.ok("глаз ставится в середину", mid.ok and e.body[-1].d == 0.0 and e.body[-1].a == 0)
	c.ok("второй глаз вплотную к нему — тесно", e.can_place("eye", 90, 0.2).reason.begins_with("Тесно"))
	c.ok("а поодаль — можно", e.can_place("eye", 90, 0.6).ok)
	e.unlocked.spike = 1
	var rim := e.place("spike", 90, false, 0.3)
	c.ok("шип внутрь не уходит — только на край", rim.ok and e.body[-1].d == 1.0)

func test_форма(c) -> void:
	var e := Evolution.create()
	c.ok("сначала круг", e.shape.all(func(v): return is_equal_approx(v, 1.0)))
	e.reshape(0, 1.5)
	c.ok("нос вытянут", e.shape[0] > 1.45)
	c.ok("соседи — плавно", e.shape[1] > 1.0 and e.shape[1] < e.shape[0])
	c.ok("хвост не тронут", is_equal_approx(e.shape[8], 1.0))
	e.reshape(90, 0.7, true)
	c.ok("зеркально — оба бока", e.shape[4] < 0.8 and e.shape[12] < 0.8)
	e.reshape(180, 9.0)
	c.ok("не больше предела", e.shape[8] <= Content.SHAPE_MAX)
	e.set_shape("oval")
	c.ok("овал: нос длиннее боков", e.shape[0] > e.shape[4])
	var copy := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("форма сохраняется", copy.shape, e.shape)
	c.ok("форма между точками — плавная", absf(Content.shape_at(e.shape, 0.1) - e.shape[0]) < 0.05)


func test_магазин(c) -> void:
	var e := Evolution.create()
	c.ok("без ДНК не купить", not e.buy("hp").ok)
	e.add_dna(100.0)
	var free := e.dna_free()
	var hp0 := Creature.of_player(e).max_hp
	c.ok("оболочка куплена", e.buy("hp").ok)
	c.eq("ДНК ушла", e.dna_free(), free - 30)
	c.ok("клетка крепче", Creature.of_player(e).max_hp > hp0 * 1.1)
	e.add_dna(2000.0)
	e.buy("hp")
	e.buy("hp")
	c.ok("четвёртый раз — нечего", e.buy("hp").message.contains("полностью"))
	var slots := e.slots()
	e.buy("room")
	c.eq("лишнее место", e.slots(), slots + 1)
	var copy := Evolution.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	c.eq("покупки сохраняются", copy.upgrades, e.upgrades)
	var old := Evolution.from_dict({"dna_total": 60, "unlocked": {"filter": 1, "cilia": 1, "camo": 2}, "body": [{"id": "filter", "a": 0}, {"id": "camo", "a": 0, "d": 0.0}]})
	c.eq("старые хроматофоры стали покупкой", old.upgrade_level("camo"), 1)
	c.eq("и даром", old.shop_spent(), 0)
	c.ok("а с тела они ушли", not old.body.any(func(p): return p.id == "camo"))
	var bought := Evolution.from_dict({"dna_total": 300, "upgrades": {"heat": 1, "cold": 1}})
	c.eq("купленное, чего больше нет, не стоит ДНК", bought.shop_spent(), 0)

func test_форма_тела(c) -> void:
	var e := Evolution.create()
	var round_slots := e.slots()
	e.shape = e.shape.map(func(v): return Content.SHAPE_MAX)
	c.ok("большое тело — больше мест", e.slots() >= round_slots + 3)
	var big := Creature.of_player(e)
	e.shape = Content.shape_preset("round")
	var small := Creature.of_player(e)
	c.ok("и больше здоровья", big.max_hp > small.max_hp * 1.2)
	c.ok("но медленнее", big.speed < small.speed)
	e.set_shape("oval")
	var oval := Creature.of_player(e)
	e.set_shape("wide")
	var wide := Creature.of_player(e)
	c.ok("вытянутое вперёд быстрее широкого", oval.speed > wide.speed)
	# На растянутом теле части стоят свободнее.
	e.shape = Content.shape_preset("round")
	var gap_round := e.anchor(0, 1.0).distance_to(e.anchor(30, 1.0))
	e.shape = e.shape.map(func(v): return 1.5)
	c.ok("на большом теле между частями просторнее", e.anchor(0, 1.0).distance_to(e.anchor(30, 1.0)) > gap_round * 1.3)
	# Сжать тело, в котором не поместятся уже стоящие части, нельзя.
	e.add_dna(40.0)
	var cap := e.slots()
	while e.body.size() < cap:
		e.body.append({"id": "cilia", "a": 15 * e.body.size(), "d": 1.0})
	c.ok("сжать некуда — форма не меняется", not e.set_shape("round") and e.shape[0] == 1.5)
